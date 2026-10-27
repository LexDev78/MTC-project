// Créer le compte d'un collaborateur, pour le compte de son patron.
//
// Pourquoi une fonction edge et pas un appel depuis l'app : inscrire
// quelqu'un demande `auth.signUp`, qui **remplace la session en cours**.
// Le patron qui ajoute un vendeur se retrouverait connecté sous l'identité
// de son employé, sans avoir rien demandé. Seule la clé de service peut
// créer un compte sans toucher à la session de l'appelant.
//
// Trois gardes, dans cet ordre :
//
//  1. l'appelant est-il connecté ;
//  2. possède-t-il une boutique — un collaborateur ne recrute pas ;
//  3. le nom d'utilisateur est-il libre.
//
// Le rattachement, lui, n'est pas fait ici : la base le pose depuis
// `app_metadata` (`apply_account_provisioning`, `0128`), dans la même
// transaction que la création du compte. Le faire en deux temps laisserait,
// sur une coupure, un compte qui existe et n'appartient à aucune boutique.
//
// `app_metadata` et non `user_metadata` : le second s'écrit par n'importe
// qui à l'inscription publique — c'est ainsi qu'on entrait dans la boutique
// de son choix avant `0128`. Le premier n'est écrit que par la clé de
// service, donc par cette fonction, après ses trois gardes.

import { createClient } from "jsr:@supabase/supabase-js@2";

/// Les mêmes que la contrainte `permissions_connues` de `0093`. Les répéter
/// ici n'est pas un doublon : c'est le refus poli, avant que la base ne
/// refuse sèchement.
const PERMISSIONS = [
  "products",
  "orders",
  "promotions",
  "storefront",
  "messages",
  "reviews",
];

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

/// Un mot de passe à usage unique, engendré ici et non choisi par le
/// patron.
///
/// Le patron le dicte une fois ; le collaborateur doit le remplacer à sa
/// première connexion (`must_change_password`, `0098`). Laisser le patron
/// le choisir produit invariablement le même mot de passe pour les trois
/// vendeurs, ou celui de la boutique.
///
/// Alphabet sans `0/O`, `1/l/I` ni `5/S` : il se dicte de vive voix, parfois
/// au téléphone, parfois dans un marché bruyant.
function motDePasseTemporaire(): string {
  const alphabet = "ABCDEFGHJKMNPQRTUVWXYZ2346789";
  const octets = new Uint8Array(10);
  crypto.getRandomValues(octets);
  return Array.from(octets, (o) => alphabet[o % alphabet.length]).join("");
}

/// Même convention que l'app (`pseudo_email.dart`) : Supabase Auth veut une
/// adresse, l'app ne connaît que des noms d'utilisateur.
function pseudoEmail(usernameOrPhone: string): string {
  return `${usernameOrPhone.trim().toLowerCase()}@mtc.local`;
}

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const authorization = request.headers.get("Authorization");
  if (!authorization) {
    return jsonResponse({ error: "Connectez-vous." }, 401);
  }

  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!url || !serviceKey || !anonKey) {
    return jsonResponse({ error: "Configuration Supabase incomplète." }, 500);
  }

  const asUser = createClient(url, anonKey, {
    global: { headers: { Authorization: authorization } },
  });

  // La boutique de l'appelant, telle que la base la voit. On ne la prend
  // jamais du corps de la requête : ce serait laisser n'importe qui
  // recruter chez n'importe qui.
  const { data: shopId, error: shopError } = await asUser.rpc(
    "operating_supplier_id",
  );
  const { data: isOwner } = await asUser.rpc("is_supplier_owner");
  if (shopError || !shopId) {
    return jsonResponse({ error: "Réservé à un compte fournisseur." }, 403);
  }
  if (isOwner !== true) {
    return jsonResponse(
      { error: "Seul le propriétaire de la boutique peut ajouter un collaborateur." },
      403,
    );
  }

  let payload: {
    displayName?: string;
    usernameOrPhone?: string;
    phoneNumber?: string;
    permissions?: string[];
  };
  try {
    payload = await request.json();
  } catch {
    return jsonResponse({ error: "Corps de requête illisible." }, 400);
  }

  const displayName = payload.displayName?.trim() ?? "";
  const username = payload.usernameOrPhone?.trim() ?? "";
  const phoneNumber = payload.phoneNumber?.trim() ?? "";
  // Jamais celui du corps de la requête : le patron ne choisit pas.
  const password = motDePasseTemporaire();

  if (displayName.length < 2) {
    return jsonResponse({ error: "Indiquez le nom du collaborateur." }, 400);
  }
  if (username.length < 3 || username.includes(" ")) {
    return jsonResponse(
      { error: "Le nom d'utilisateur doit faire au moins 3 caractères, sans espace." },
      400,
    );
  }
  const permissions = (payload.permissions ?? []).filter((p) =>
    PERMISSIONS.includes(p)
  );

  const asService = createClient(url, serviceKey);
  const { data: created, error: createError } = await asService.auth.admin
    .createUser({
      email: pseudoEmail(username),
      password,
      // Pas de courriel à confirmer : l'adresse est synthétique et ne mène
      // à aucune boîte. Le patron remet le mot de passe de la main à la
      // main.
      email_confirm: true,
      // Ni rôle ni boutique ici : le compte naît client, et la base le
      // convertit en collaborateur d'après `app_metadata`. Mettre
      // `collaborator_of` ou `permissions` dans `user_metadata` fait
      // désormais échouer la création (`handle_new_user`, `0128`).
      user_metadata: {
        display_name: displayName,
        username_or_phone: username,
        phone_number: phoneNumber,
      },
      app_metadata: {
        collaborator_of: shopId,
        permissions,
        // Le patron qui recrute : seul le propriétaire passe la garde 2, et
        // sa boutique porte son identifiant.
        invited_by: shopId,
      },
    });

  if (createError) {
    // Le cas de loin le plus fréquent : le nom est déjà pris. Le dire
    // plutôt que de rendre une erreur technique que personne ne sait lire.
    const message = createError.message.toLowerCase().includes("already")
      ? `Le nom d'utilisateur « ${username} » est déjà pris.`
      : "Impossible de créer ce compte. Réessayez.";
    return jsonResponse({ error: message }, 400);
  }

  // Le mot de passe est rendu **une seule fois**, pour que le patron le
  // dicte. Il n'est stocké nulle part en clair, et aucune autre requête ne
  // permettra de le relire.
  return jsonResponse({
    user_id: created.user?.id,
    username,
    temporary_password: password,
  });
});
