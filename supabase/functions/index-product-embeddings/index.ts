// Indexation du catalogue : calcule l'empreinte des produits qui n'en ont
// pas, ou dont la photo a changé.
//
// Appelée par une tâche planifiée (pg_cron en hébergé) ou à la main après
// un import, jamais par l'app : elle parle au modèle, donc elle coûte de
// l'argent, et personne d'autre que l'exploitant n'a à la déclencher.
//
// Elle traite un **lot borné** et rend la main. Un catalogue de dix mille
// produits ne s'indexe pas en une requête : la fonction serait interrompue
// au bout de son temps imparti, et on ne saurait pas où elle s'est arrêtée.
// En rendant compte de ce qu'elle a fait, un appel répété finit le travail
// et reprend naturellement là où il en est — `products_needing_embedding`
// ne rend que ce qui reste.
//
// Le paramètre `model` est ce qui rend une bascule mesurable : on indexe le
// catalogue avec un modèle **candidat** pendant que le modèle servant
// continue de répondre aux clients (`0085`). Les deux jeux de vecteurs
// cohabitent, on compare, puis on bascule — ou pas.

import { createClient } from "jsr:@supabase/supabase-js@2";
import { embed, servingModel, type EmbeddingModel } from "../_shared/embeddings.ts";
import { resolveProductImageUrl } from "../_shared/image_urls.ts";

/// Un lot assez grand pour avancer, assez petit pour tenir dans le temps
/// imparti d'une fonction edge même si le modèle est lent.
const DEFAULT_BATCH = 20;

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

  // Même garde que le webhook de notifications : un secret dédié plutôt que
  // la clé de service, qui ouvrirait toute la base à un appel qui n'a besoin
  // que d'écrire des vecteurs.
  const expected = Deno.env.get("INDEXING_SECRET");
  if (!expected) {
    return jsonResponse(
      { error: "INDEXING_SECRET n'est pas défini — voir supabase/functions/.env.example" },
      500,
    );
  }
  if (request.headers.get("x-indexing-secret") !== expected) {
    return jsonResponse({ error: "Non autorisé." }, 401);
  }

  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) {
    return jsonResponse({ error: "Configuration Supabase incomplète." }, 500);
  }
  const supabase = createClient(url, serviceKey);

  let batch = DEFAULT_BATCH;
  let requestedModel: string | null = null;
  try {
    const body = await request.json();
    if (typeof body?.limit === "number") batch = Math.min(body.limit, 100);
    if (typeof body?.model === "string") requestedModel = body.model;
  } catch {
    // Corps absent : le lot par défaut et le modèle servant conviennent.
  }

  // Un modèle nommé explicitement doit exister dans le registre, avec sa
  // dimension : c'est elle qui permet de refuser un vecteur de taille
  // inattendue avant qu'il n'entre en base.
  let model: EmbeddingModel;
  if (requestedModel) {
    const { data, error } = await supabase
      .from("ai_models")
      .select("name, provider, dim")
      .eq("name", requestedModel)
      .eq("kind", "embedding")
      .maybeSingle();
    if (error || !data) {
      return jsonResponse(
        { error: `Modèle inconnu du registre : ${requestedModel}.` },
        400,
      );
    }
    model = {
      name: data.name as string,
      provider: data.provider as EmbeddingModel["provider"],
      dim: data.dim as number,
    };
  } else {
    model = await servingModel(url, serviceKey);
  }

  const { data: pending, error } = await supabase.rpc(
    "products_needing_embedding",
    { p_limit: batch, p_model: model.name },
  );
  if (error) {
    return jsonResponse({ error: "File d'indexation illisible." }, 500);
  }

  let indexed = 0;
  const failures: Array<{ product_id: string; reason: string }> = [];

  for (const product of (pending ?? []) as Array<{
    product_id: string;
    name: string;
    description: string | null;
    image_url: string | null;
  }>) {
    if (!product.image_url) continue;
    try {
      // Texte **et** image : deux tissus se ressemblent beaucoup en photo,
      // et le nom est ce qui les sépare. C'est tout l'intérêt d'un modèle
      // multimodal — encoder l'image seule reviendrait à chercher une
      // couleur.
      // Le chemin stocké est résolu en URL publique pour le modèle, mais
      // c'est le **chemin** qui est enregistré comme source : c'est lui que
      // `products_needing_embedding` compare pour savoir si la photo a
      // changé. Y mettre l'URL ferait réindexer le catalogue entier à
      // chaque passage.
      const imageUrl = resolveProductImageUrl(product.image_url, url);
      const vector = await embed({
        text: [product.name, product.description].filter(Boolean).join(". "),
        image: imageUrl,
      }, model);
      const { error: upsertError } = await supabase.rpc(
        "upsert_product_embedding",
        {
          p_product_id: product.product_id,
          p_embedding: vector,
          p_model: model.name,
          p_source_image_url: product.image_url,
        },
      );
      if (upsertError) throw new Error(upsertError.message);
      indexed++;
    } catch (failure) {
      // Un produit qui échoue ne doit pas arrêter le lot : une photo
      // illisible ou un lien mort est un cas courant sur un catalogue
      // alimenté à la main. Il repassera au prochain appel.
      failures.push({
        product_id: product.product_id,
        reason: failure instanceof Error ? failure.message : "inconnu",
      });
    }
  }

  return jsonResponse({
    model: model.name,
    indexed,
    remaining: Math.max((pending?.length ?? 0) - indexed, 0),
    failures,
  });
});
