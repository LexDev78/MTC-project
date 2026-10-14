// Du chemin stocké à une URL que le modèle peut aller chercher.
//
// `products.image_urls` ne contient **pas** d'URL, malgré son nom : les
// entités ne stockent qu'un chemin d'objet Storage (`<supplierId>/<fichier>`)
// ou un chemin d'asset embarqué (`assets/...`), et la résolution se fait à
// l'affichage — c'est ce qui évite de persister une URL signée périmée
// (`resolved_image.dart`).
//
// Conséquence pour l'indexation, découverte en écrivant la chaîne
// d'entraînement : passer `image_urls[1]` tel quel au modèle lui donne un
// chemin, pas une image. Aucun produit réel ne s'indexait.
//
// Deux cas, et le second n'a pas de solution :
//
//  * chemin d'objet → URL publique du bucket `product-images`, qui est
//    public en lecture (`0001`) ;
//  * `assets/...` → le fichier n'existe que dans le binaire de
//    l'application. Aucun serveur ne peut le lire. Ce sont les photos du
//    jeu de démonstration : elles ne s'indexeront jamais, et il vaut mieux
//    le dire que d'envoyer un chemin au modèle et payer l'appel pour une
//    erreur.

export const PRODUCT_IMAGE_BUCKET = "product-images";

export class UnreachableImage extends Error {}

export function resolveProductImageUrl(path: string, supabaseUrl: string): string {
  if (path.startsWith("assets/")) {
    throw new UnreachableImage(
      "Photo embarquée dans l'application (jeu de démonstration) : " +
        "inaccessible depuis le serveur.",
    );
  }
  if (path.startsWith("http://") || path.startsWith("https://")) {
    return path;
  }
  return `${supabaseUrl.replace(/\/$/, "")}/storage/v1/object/public/` +
    `${PRODUCT_IMAGE_BUCKET}/${path.split("/").map(encodeURIComponent).join("/")}`;
}
