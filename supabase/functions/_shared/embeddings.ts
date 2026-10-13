// Appel au fournisseur d'empreintes, isolé ici.
//
// Un seul endroit sait quel modèle est utilisé et sous quelle forme il
// répond : les deux fonctions edge (recherche et indexation) n'en voient
// qu'une signature. Changer de fournisseur ne devrait toucher que ce
// fichier — et la dimension figée dans `product_embeddings` (`0081`).
//
// La clé reste **côté serveur**. Elle n'est jamais envoyée à l'app : une
// clé d'API dans un binaire mobile est une clé publique, et celle-ci est
// facturée à l'appel.

const MODEL = "voyage-multimodal-3.5";
const ENDPOINT = "https://api.voyageai.com/v1/multimodalembeddings";

/// Au-delà, on rend la main : une recherche par photo qui fait patienter
/// vingt secondes est abandonnée avant d'aboutir, et l'appel est facturé
/// quand même.
const TIMEOUT_MS = 12_000;

export interface EmbeddingInput {
  /// Le texte à encoder (nom et description d'un produit, ou mots-clés).
  text?: string;
  /// L'image, en data URL (`data:image/jpeg;base64,...`) ou URL publique.
  image?: string;
}

export const embeddingModel = MODEL;

/// Calcule l'empreinte d'un contenu mixte texte + image.
///
/// Lève en cas d'échec : l'appelant décide s'il répond une erreur au client
/// (recherche) ou s'il passe au produit suivant (indexation). Les deux
/// n'ont pas la même tolérance, donc ce niveau ne tranche pas.
export async function embed(input: EmbeddingInput): Promise<number[]> {
  const apiKey = Deno.env.get("VOYAGE_API_KEY");
  if (!apiKey) {
    throw new Error(
      "VOYAGE_API_KEY n'est pas défini — voir supabase/functions/.env.example",
    );
  }

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

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);
  try {
    const response = await fetch(ENDPOINT, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model: MODEL,
        inputs: [{ content }],
        input_type: "document",
      }),
      signal: controller.signal,
    });

    if (!response.ok) {
      const detail = await response.text();
      throw new Error(`Embeddings ${response.status} : ${detail.slice(0, 200)}`);
    }

    const body = await response.json();
    const vector = body?.data?.[0]?.embedding;
    if (!Array.isArray(vector) || vector.length === 0) {
      throw new Error("Réponse d'embeddings inattendue.");
    }
    return vector as number[];
  } finally {
    clearTimeout(timer);
  }
}

/// pgvector attend `[0.1,0.2,...]`, pas un tableau JSON.
export function toPgVector(values: number[]): string {
  return `[${values.join(",")}]`;
}
