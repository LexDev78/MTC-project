// Appel au modèle d'empreintes, isolé ici.
//
// Un seul endroit sait **quels** modèles existent et comment ils répondent ;
// les deux fonctions edge (recherche, indexation) n'en voient qu'une
// signature. C'est la charnière de la bascule vers un modèle maison : le
// jour où l'on en servira un, ce fichier est le seul à changer côté
// serveur, et le registre en base (`ai_models`, `0085`) décide lequel
// répond — sans redéploiement.
//
// Deux fournisseurs :
//
//  * `voyage` — l'API externe de départ. Facturée à l'appel, clé côté
//    serveur uniquement.
//  * `self_hosted` — notre modèle, servi derrière HTTP (voir `ml/serve/`).
//    Même contrat, autre adresse : rien d'autre ne distingue les deux pour
//    l'appelant.
//
// La clé reste **côté serveur** dans les deux cas. Une clé d'API dans un
// binaire mobile est une clé publique, et celle-ci est facturée à l'appel.

import { createClient } from "jsr:@supabase/supabase-js@2";

const VOYAGE_ENDPOINT = "https://api.voyageai.com/v1/multimodalembeddings";

/// Au-delà, on rend la main : une recherche par photo qui fait patienter
/// vingt secondes est abandonnée avant d'aboutir, et l'appel est facturé
/// quand même.
const TIMEOUT_MS = 12_000;

/// Ce que le registre dit d'un modèle.
export interface EmbeddingModel {
  name: string;
  provider: "voyage" | "self_hosted";
  dim: number;
}

/// Le repli vaut pour le cas où la base est injoignable au moment où l'on a
/// besoin du registre : mieux vaut servir avec le modèle historique que ne
/// pas servir du tout.
export const FALLBACK_MODEL: EmbeddingModel = {
  name: "voyage-multimodal-3.5",
  provider: "voyage",
  dim: 1024,
};

export interface EmbeddingInput {
  /// Le texte à encoder (nom et description d'un produit, ou mots-clés).
  text?: string;
  /// L'image, en data URL (`data:image/jpeg;base64,...`) ou URL publique.
  image?: string;
}

/// Les deux formes de réponse qu'on sait lire : celle de Voyage
/// (`data[0].embedding`) et la nôtre (`embedding`).
interface EmbeddingsResponse {
  data?: Array<{ embedding?: unknown }>;
  embedding?: unknown;
}

/// Mis en cache pour la durée de vie de l'instance : le runtime garde
/// l'isolat chaud entre deux requêtes, donc une lecture par démarrage à
/// froid suffit. Une bascule de modèle prend effet au renouvellement des
/// instances — quelques minutes, soit l'échelle à laquelle on change de
/// modèle, pas celle d'une requête.
let cached: EmbeddingModel | null = null;

/// Lit, dans le registre, le modèle qui sert.
export async function servingModel(
  url: string,
  serviceKey: string,
): Promise<EmbeddingModel> {
  if (cached) return cached;

  const { data, error } = await createClient(url, serviceKey)
    .from("ai_models")
    .select("name, provider, dim")
    .eq("kind", "embedding")
    .eq("role", "serving")
    .maybeSingle();

  if (error || !data) {
    console.error("ai_models illisible, repli sur le modèle historique", error);
    return FALLBACK_MODEL;
  }
  cached = {
    name: data.name as string,
    provider: data.provider as EmbeddingModel["provider"],
    dim: data.dim as number,
  };
  return cached;
}

/// Calcule l'empreinte d'un contenu mixte texte + image.
///
/// Lève en cas d'échec : l'appelant décide s'il répond une erreur au client
/// (recherche) ou s'il passe au produit suivant (indexation). Les deux n'ont
/// pas la même tolérance, donc ce niveau ne tranche pas.
///
/// Vérifie la dimension annoncée par le registre. Un modèle qui changerait
/// sa sortie sans changer de nom produirait des vecteurs incomparables avec
/// ceux déjà en base, dans la même colonne et sous le même nom — l'erreur la
/// plus coûteuse possible, parce qu'elle ne se voit pas.
export async function embed(
  input: EmbeddingInput,
  model: EmbeddingModel = FALLBACK_MODEL,
): Promise<number[]> {
  const vector = model.provider === "self_hosted"
    ? await embedSelfHosted(input, model)
    : await embedVoyage(input, model);

  if (vector.length !== model.dim) {
    throw new Error(
      `Le modèle ${model.name} est déclaré à ${model.dim} dimensions, ` +
        `la réponse en porte ${vector.length}.`,
    );
  }
  return vector;
}

function buildContent(input: EmbeddingInput): Array<Record<string, string>> {
  const content: Array<Record<string, string>> = [];
  if (input.text) content.push({ type: "text", text: input.text });
  if (input.image) {
    content.push(
      input.image.startsWith("data:")
        ? { type: "image_base64", image_base64: input.image }
        : { type: "image_url", image_url: input.image },
    );
  }
  if (content.length === 0) {
    throw new Error("Rien à encoder : ni texte ni image.");
  }
  return content;
}

async function embedVoyage(
  input: EmbeddingInput,
  model: EmbeddingModel,
): Promise<number[]> {
  const apiKey = Deno.env.get("VOYAGE_API_KEY");
  if (!apiKey) {
    throw new Error(
      "VOYAGE_API_KEY n'est pas défini — voir supabase/functions/.env.example",
    );
  }

  const body = await postJson(VOYAGE_ENDPOINT, {
    model: model.name,
    inputs: [{ content: buildContent(input) }],
    input_type: "document",
  }, { Authorization: `Bearer ${apiKey}` });

  return readVector(body.data?.[0]?.embedding, "Voyage");
}

/// Notre modèle, servi par `ml/serve/` : même contrat, en plus simple —
/// `{text?, image?}` en entrée, `{embedding: number[]}` en sortie. Le
/// contrat est volontairement le nôtre et non celui de Voyage : il n'y a
/// aucune raison d'imiter la forme d'une API qu'on quitte.
async function embedSelfHosted(
  input: EmbeddingInput,
  model: EmbeddingModel,
): Promise<number[]> {
  const endpoint = Deno.env.get("SELF_HOSTED_EMBEDDINGS_URL");
  if (!endpoint) {
    throw new Error(
      "SELF_HOSTED_EMBEDDINGS_URL n'est pas défini alors que le modèle " +
        `${model.name} est déclaré auto-hébergé.`,
    );
  }
  const token = Deno.env.get("SELF_HOSTED_EMBEDDINGS_TOKEN");

  const body = await postJson(
    endpoint.replace(/\/$/, "") + "/embed",
    { model: model.name, text: input.text ?? null, image: input.image ?? null },
    token ? { Authorization: `Bearer ${token}` } : {},
  );

  return readVector(body.embedding, "le modèle auto-hébergé");
}

function readVector(value: unknown, source: string): number[] {
  if (!Array.isArray(value) || value.length === 0) {
    throw new Error(`Réponse d'empreintes inattendue de ${source}.`);
  }
  return value as number[];
}

async function postJson(
  url: string,
  payload: unknown,
  headers: Record<string, string>,
): Promise<EmbeddingsResponse> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);
  try {
    const response = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json", ...headers },
      body: JSON.stringify(payload),
      signal: controller.signal,
    });
    if (!response.ok) {
      const detail = await response.text();
      throw new Error(`Embeddings ${response.status} : ${detail.slice(0, 200)}`);
    }
    return await response.json() as EmbeddingsResponse;
  } finally {
    clearTimeout(timer);
  }
}
