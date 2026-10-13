// Recherche par photo : le client envoie une image, reçoit des produits.
//
// Pourquoi une fonction edge et pas une RPC : calculer une empreinte demande
// une clé d'API facturée à l'appel. Une clé dans un binaire mobile est une
// clé publique — n'importe qui la lirait et dépenserait le budget. Elle ne
// quitte donc jamais le serveur, et l'app n'envoie qu'une photo.
//
// Trois gardes, dans cet ordre, parce que chacune coûte moins cher que la
// suivante :
//
//  1. l'appelant est-il connecté (sinon on ne sait pas qui facturer) ;
//  2. lui reste-t-il des appels aujourd'hui (`consume_ai_quota`) ;
//  3. seulement alors, l'appel au modèle.
//
// Le rapprochement, lui, se fait en base : les vecteurs du catalogue ne
// sortent pas (`product_embeddings` n'est lisible par personne, `0083`).

import { createClient } from "jsr:@supabase/supabase-js@2";
import { embed, toPgVector } from "../_shared/embeddings.ts";

/// Au-delà, on refuse sans appeler le modèle : une photo de téléphone
/// dépasse rarement 4 Mo une fois compressée par l'app, et accepter
/// davantage revient à payer pour une image que le modèle redimensionnera.
const MAX_IMAGE_BYTES = 4 * 1024 * 1024;

/// Le plafond quotidien par compte. Généreux pour un usage normal, bas
/// devant le coût d'un script qui boucle.
const DAILY_LIMIT = 20;

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
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

  let vector: number[];
  try {
    vector = await embed({ image });
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
  const asService = createClient(url, serviceKey);
  const { data: matches, error: searchError } = await asService.rpc(
    "search_products_by_embedding",
    {
      p_embedding: toPgVector(vector),
      p_limit: Math.min(payload.limit ?? 24, 50),
    },
  );
  if (searchError) {
    console.error("visual-search match failed", searchError);
    return jsonResponse({ error: "Recherche indisponible." }, 500);
  }

  return jsonResponse({
    remaining,
    // Les identifiants seuls : l'app résout les produits par ses lectures
    // habituelles, qui appliquent déjà la RLS et les règles d'affichage.
    results: (matches ?? []).map((row: { product_id: string; similarity: number }) => ({
      product_id: row.product_id,
      similarity: row.similarity,
    })),
  });
});
