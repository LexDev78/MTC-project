// Recherche par photo : le client envoie une image, reçoit des produits.
//
// Pourquoi une fonction edge et pas une RPC : calculer une empreinte demande
// une clé d'API facturée à l'appel. Une clé dans un binaire mobile est une
// clé publique — n'importe qui la lirait et dépenserait le budget. Elle ne
// quitte donc jamais le serveur, et l'app n'envoie qu'une photo.
//
// Quatre gardes, dans cet ordre, parce que chacune coûte moins cher que la
// suivante :
//
//  1. l'appelant est-il connecté (sinon on ne sait pas qui facturer) ;
//  2. la photo est-elle d'une taille acceptable ;
//  3. lui reste-t-il des appels aujourd'hui (`consume_ai_quota`) ;
//  4. seulement alors, l'appel au modèle.
//
// Le rapprochement, lui, se fait en base : les vecteurs du catalogue ne
// sortent pas (`product_embeddings` n'est lisible par personne, `0083`).
//
// Enfin — et c'est l'ajout de `0086` — la photo et son résultat sont
// **conservés**. C'est ce qui constituera le jeu d'entraînement d'un modèle
// maison, et c'est la seule partie du dispositif qu'on ne peut pas
// rattraper plus tard : une recherche qui passe sans être enregistrée est
// un exemple perdu. Cette conservation est pour autant au second rang : si
// elle échoue ou traîne, la recherche répond quand même.

import { createClient } from "jsr:@supabase/supabase-js@2";
import { embed, servingModel } from "../_shared/embeddings.ts";

/// Au-delà, on refuse sans appeler le modèle : une photo de téléphone
/// dépasse rarement 4 Mo une fois compressée par l'app, et accepter
/// davantage revient à payer pour une image que le modèle redimensionnera.
const MAX_IMAGE_BYTES = 4 * 1024 * 1024;

/// Le plafond quotidien par compte. Généreux pour un usage normal, bas
/// devant le coût d'un script qui boucle.
const DAILY_LIMIT = 20;

/// Temps laissé à la conservation de la photo. Au-delà, on répond sans
/// `query_id` : on perd un exemple d'entraînement, pas la recherche.
const CAPTURE_BUDGET_MS = 3_000;

const EXTENSIONS: Record<string, string> = {
  "image/jpeg": "jpg",
  "image/png": "png",
  "image/webp": "webp",
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

/// `atob` plutôt qu'une dépendance : décoder du base64 est dans la
/// plateforme, et une dépendance de plus sur un chemin facturé est une
/// surface de panne de plus.
function decodeDataUrl(dataUrl: string): { bytes: Uint8Array; contentType: string } {
  const match = /^data:([^;,]+);base64,(.*)$/s.exec(dataUrl);
  if (!match) throw new Error("Image non reconnue : data URL attendue.");
  const binary = atob(match[2]);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return { bytes, contentType: match[1] };
}

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  // Le jeton de l'utilisateur est transmis tel quel au client Supabase :
  // `auth.uid()` vaut alors la personne, et c'est elle que
  // `consume_ai_quota` débite. Avec la clé de service, tous les appels
  // seraient débités au même compte — c'est-à-dire à personne.
  const authorization = request.headers.get("Authorization");
  if (!authorization) {
    return jsonResponse({ error: "Connectez-vous pour utiliser la recherche par photo." }, 401);
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

  // L'identité **vérifiée** de l'appelant. Elle sert deux fois : refuser
  // proprement un appel anonyme, et estampiller la requête conservée. Le
  // `user_id` passé à `record_visual_search_query` vient d'ici et jamais du
  // corps de la requête — sans quoi n'importe qui pourrait attribuer ses
  // recherches à un autre compte, et le jeu d'entraînement deviendrait
  // falsifiable.
  const { data: auth, error: authError } = await asUser.auth.getUser();
  if (authError || !auth?.user) {
    return jsonResponse({ error: "Session expirée. Reconnectez-vous." }, 401);
  }
  const userId = auth.user.id;

  let payload: { image?: string; limit?: number };
  try {
    payload = await request.json();
  } catch {
    return jsonResponse({ error: "Corps de requête illisible." }, 400);
  }

  const image = payload.image;
  if (!image || typeof image !== "string") {
    return jsonResponse({ error: "Aucune image reçue." }, 400);
  }
  // La base64 pèse environ 4/3 de l'original : on mesure la charge réelle.
  if (image.length * 0.75 > MAX_IMAGE_BYTES) {
    return jsonResponse({ error: "Photo trop lourde (4 Mo maximum)." }, 413);
  }

  // Le quota est consommé **avant** l'appel au modèle, et volontairement :
  // débiter après laisserait un appel échoué gratuit, donc rejouable à
  // l'infini. Mieux vaut qu'une panne du modèle coûte une unité au client
  // qu'un script gratuit coûte le budget du mois.
  const { data: remaining, error: quotaError } = await asUser.rpc(
    "consume_ai_quota",
    { p_feature: "visual_search", p_daily_limit: DAILY_LIMIT },
  );
  if (quotaError) {
    return jsonResponse({ error: "Quota indisponible." }, 500);
  }
  if (typeof remaining !== "number" || remaining < 0) {
    return jsonResponse(
      {
        error:
          `Vous avez utilisé vos ${DAILY_LIMIT} recherches par photo du jour. ` +
          "Réessayez demain.",
      },
      429,
    );
  }

  const asService = createClient(url, serviceKey);

  // Quel modèle répond aujourd'hui : lu dans le registre, pas codé ici
  // (`0085`). Basculer sur un modèle maison sera une ligne de SQL.
  const model = await servingModel(url, serviceKey);

  let vector: number[];
  try {
    vector = await embed({ image }, model);
  } catch (error) {
    console.error("visual-search embed failed", error);
    return jsonResponse(
      { error: "La reconnaissance d'image est indisponible. Réessayez." },
      502,
    );
  }

  // La comparaison passe par la clé de service : `search_products_by_embedding`
  // est fermée aux clients, pour qu'on ne puisse pas sonder l'espace
  // vectoriel point par point (`0084`).
  const { data: matches, error: searchError } = await asService.rpc(
    "search_products_by_embedding",
    {
      p_embedding: vector,
      p_model: model.name,
      p_limit: Math.min(payload.limit ?? 24, 50),
    },
  );
  if (searchError) {
    console.error("visual-search match failed", searchError);
    return jsonResponse({ error: "Recherche indisponible." }, 500);
  }

  const results = (matches ?? []).map(
    (row: { product_id: string; similarity: number }) => ({
      product_id: row.product_id,
      similarity: row.similarity,
    }),
  );

  // Conservation du couple (photo, résultats). Bornée dans le temps et
  // enveloppée : c'est un investissement pour plus tard, pas un service
  // rendu maintenant, et il ne doit rien coûter à celui qui cherche.
  const queryId = await Promise.race([
    captureQuery({ asService, userId, image, model: model.name, vector, results }),
    new Promise<null>((resolve) => setTimeout(() => resolve(null), CAPTURE_BUDGET_MS)),
  ]).catch((error) => {
    console.error("visual-search capture failed", error);
    return null;
  });

  return jsonResponse({
    remaining,
    // Renvoyé pour que l'app puisse dire, au moment où l'on ouvre un
    // résultat, lequel a été retenu. C'est l'étiquette du jeu
    // d'entraînement — la donnée la plus difficile à obtenir et la seule
    // qui ne s'invente pas.
    query_id: queryId,
    // Les identifiants seuls : l'app résout les produits par ses lectures
    // habituelles, qui appliquent déjà la RLS et les règles d'affichage.
    results,
  });
});

async function captureQuery(args: {
  // deno-lint-ignore no-explicit-any
  asService: any;
  userId: string;
  image: string;
  model: string;
  vector: number[];
  results: Array<{ product_id: string; similarity: number }>;
}): Promise<string | null> {
  const { bytes, contentType } = decodeDataUrl(args.image);
  const extension = EXTENSIONS[contentType];
  if (!extension) return null;

  // Rangée par compte, comme partout ailleurs dans ce projet : le premier
  // segment du chemin est l'identifiant du propriétaire. Le bucket est
  // privé et sans policy client (`0086`), mais la convention reste — c'est
  // elle qui rend la purge par personne possible.
  const path = `${args.userId}/${crypto.randomUUID()}.${extension}`;

  const { error: uploadError } = await args.asService.storage
    .from("visual-search-queries")
    .upload(path, bytes, { contentType, upsert: false });
  if (uploadError) {
    console.error("visual-search upload failed", uploadError);
    return null;
  }

  const { data, error } = await args.asService.rpc("record_visual_search_query", {
    p_user_id: args.userId,
    p_image_path: path,
    p_model: args.model,
    p_embedding: args.vector,
    p_candidates: args.results,
  });
  if (error) {
    console.error("visual-search record failed", error);
    return null;
  }
  return typeof data === "string" ? data : null;
}
