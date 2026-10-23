import 'package:mtc_app/features/auth/domain/entities/app_user.dart';
import 'package:mtc_app/features/catalog/domain/entities/product.dart';
import 'package:mtc_app/features/catalog/domain/entities/product_category.dart';
import 'package:mtc_app/features/catalog/domain/entities/product_characteristic.dart';
import 'package:mtc_app/features/catalog/domain/entities/product_characteristic_type.dart';
import 'package:mtc_app/features/catalog/domain/entities/product_variant.dart';
import 'package:mtc_app/features/catalog/domain/entities/promotion.dart';
import 'package:mtc_app/features/comments/domain/entities/product_comment.dart';
import 'package:mtc_app/features/ratings/domain/entities/product_review.dart';

/// Un jeu de données réaliste pour les rendus du côté client, sans base :
/// des produits maliens avec leurs photos embarquées, des notes, des vues,
/// les deux types de fournisseur, et de vraies promotions datées.
final DateTime maintenant = DateTime.now();

AppUser clientAwa() => AppUser.client(
  id: 'client-awa',
  displayName: 'Awa Traoré',
  usernameOrPhone: 'awa',
  phoneNumber: '+223 70 12 34 56',
  createdAt: DateTime(2026),
);

Product produit({
  required String id,
  required String nom,
  required String boutique,
  required String photo,
  required ProductCategory categorie,
  required int prix,
  SupplierType type = SupplierType.tiers,
  double note = 4.5,
  int avis = 12,
  int vues = 100,
  int stock = 20,
  List<Promotion> promotions = const [],
  String description = 'Un article de qualité, sélectionné par MTC.',
}) => Product(
  id: id,
  supplierId: 'f-$boutique',
  supplierName: boutique,
  supplierType: type,
  name: nom,
  description: description,
  category: categorie,
  priceFcfa: prix,
  stockQuantity: stock,
  imageUrls: [photo],
  city: 'Bamako',
  ratingAverage: note,
  ratingCount: avis,
  allowsSelfDelivery: true,
  allowsMtcDelivery: true,
  createdAt: DateTime(2026, 9, 1),
  weightKg: 1,
  viewCount: vues,
  promotions: promotions,
);

Promotion remise(
  String produitId,
  int pourcentage, {
  Duration? finDans,
  String? libelle,
}) => Promotion(
  id: 'promo-$produitId',
  productId: produitId,
  kind: PromotionKind.percentage,
  value: pourcentage,
  startsAt: maintenant.subtract(const Duration(days: 1)),
  endsAt: finDans == null ? null : maintenant.add(finDans),
  label: libelle,
);

List<Product> catalogueDemo() => [
  produit(
    id: 'bogolan',
    nom: 'Tissu bogolan traditionnel',
    boutique: 'Bogolan Bamako',
    photo: 'assets/images/products/textiles/fabric.jpg',
    categorie: ProductCategory.textilesBogolan,
    prix: 15000,
    note: 4.8,
    avis: 54,
    vues: 820,
    promotions: [
      remise(
        'bogolan',
        20,
        finDans: const Duration(hours: 8),
        libelle: 'Soldes de saison',
      ),
    ],
  ),
  produit(
    id: 'miel',
    nom: 'Miel pur de Kita',
    boutique: 'Coopérative de Kita',
    photo: 'assets/images/products/alimentation/honey.jpg',
    categorie: ProductCategory.alimentation,
    prix: 4500,
    note: 4.6,
    avis: 31,
    vues: 410,
  ),
  produit(
    id: 'panneau',
    nom: 'Panneau solaire 100 W',
    boutique: 'MTC Officiel',
    type: SupplierType.principal,
    photo: 'assets/images/products/electronique/solar_panel.jpg',
    categorie: ProductCategory.electronique,
    prix: 65000,
    note: 4.4,
    avis: 18,
    vues: 1200,
    promotions: [remise('panneau', 15, finDans: const Duration(hours: 30))],
  ),
  produit(
    id: 'masque',
    nom: 'Masque dogon sculpté',
    boutique: 'Atelier de Mopti',
    photo: 'assets/images/products/artisanat/mask.jpg',
    categorie: ProductCategory.artisanat,
    prix: 25000,
    note: 4.9,
    avis: 9,
    vues: 300,
    promotions: [remise('masque', 10, libelle: 'Artisanat en fête')],
  ),
  produit(
    id: 'radio',
    nom: 'Radio FM solaire',
    boutique: 'MTC Officiel',
    type: SupplierType.principal,
    photo: 'assets/images/products/electronique/radio.jpg',
    categorie: ProductCategory.electronique,
    prix: 12000,
    note: 4.1,
    avis: 22,
    vues: 650,
  ),
  produit(
    id: 'riz',
    nom: 'Riz local de l\'Office du Niger, 25 kg',
    boutique: 'Grenier du Mali',
    photo: 'assets/images/products/alimentation/rice.jpg',
    categorie: ProductCategory.alimentation,
    prix: 17500,
    note: 4.3,
    avis: 40,
    vues: 900,
  ),
  produit(
    id: 'panier',
    nom: 'Panier tressé',
    boutique: 'Atelier de Mopti',
    photo: 'assets/images/products/artisanat/basket.jpg',
    categorie: ProductCategory.artisanat,
    prix: 6000,
    note: 4.7,
    avis: 14,
    vues: 210,
  ),
  produit(
    id: 'tole',
    nom: 'Tôle ondulée, le lot de 10',
    boutique: 'Matériaux Sikasso',
    photo: 'assets/images/products/materiaux/corrugated_sheets.jpg',
    categorie: ProductCategory.materiauxConstruction,
    prix: 48000,
    note: 4.0,
    avis: 6,
    vues: 150,
  ),
];

ProductCharacteristicType _type(String id, String libelle) =>
    ProductCharacteristicType(
      id: id,
      label: libelle,
      status: CharacteristicTypeStatus.approved,
      createdAt: DateTime(2026),
    );

ProductVariantOptionRef _ref(String caracteristique, String option) =>
    ProductVariantOptionRef(
      characteristicId: caracteristique,
      optionId: option,
    );

/// Le bogolan de [catalogueDemo], avec ce qu'une vraie fiche porte : trois
/// couleurs (deux avec leur photo, une sans), trois longueurs, une variante
/// qui en regroupe deux, une épuisée, une remise en cours et une remise sur
/// quantité.
Product bogolanAVariantes() {
  const p = 'bogolan';
  const couleur = 'c-couleur';
  const longueur = 'c-longueur';
  return catalogueDemo().first.copyWith(
    imageUrls: const [
      'assets/images/products/textiles/fabric.jpg',
      'assets/images/products/textiles/fabric_2.jpg',
      'assets/images/products/artisanat/basket.jpg',
    ],
    description:
        'Tissu bogolan teint à la main à Ségou, à la boue fermentée et aux '
        'décoctions de feuilles. Chaque pièce est unique : les motifs '
        'racontent des proverbes bambara. Coton tissé localement, lavable à '
        'froid.',
    hasVariants: true,
    stockQuantity: 24,
    weightKg: 0.8,
    region: ProductRegion.mali,
    promotions: [
      remise(
        p,
        20,
        finDans: const Duration(hours: 8),
        libelle: 'Soldes de saison',
      ),
      Promotion(
        id: 'promo-gros',
        productId: p,
        kind: PromotionKind.percentage,
        value: 30,
        minQuantity: 5,
        startsAt: maintenant.subtract(const Duration(days: 1)),
        label: 'Gros volume',
      ),
    ],
    characteristics: [
      ProductCharacteristic(
        id: couleur,
        productId: p,
        type: _type('couleur', 'Couleur'),
        options: const [
          ProductCharacteristicOption(
            id: 'o-indigo',
            characteristicId: couleur,
            value: 'Indigo',
          ),
          ProductCharacteristicOption(
            id: 'o-ocre',
            characteristicId: couleur,
            value: 'Ocre',
            displayOrder: 1,
          ),
          ProductCharacteristicOption(
            id: 'o-noir',
            characteristicId: couleur,
            value: 'Noir',
            displayOrder: 2,
          ),
        ],
      ),
      ProductCharacteristic(
        id: longueur,
        productId: p,
        type: _type('longueur', 'Longueur'),
        displayOrder: 1,
        options: const [
          ProductCharacteristicOption(
            id: 'o-2m',
            characteristicId: longueur,
            value: '2 m',
          ),
          ProductCharacteristicOption(
            id: 'o-3m',
            characteristicId: longueur,
            value: '3 m',
            displayOrder: 1,
          ),
          ProductCharacteristicOption(
            id: 'o-6m',
            characteristicId: longueur,
            value: '6 m',
            displayOrder: 2,
          ),
        ],
      ),
    ],
    variants: [
      ProductVariant(
        id: 'v-indigo-2',
        productId: p,
        name: 'Indigo 2 m',
        priceFcfa: 15000,
        stockQuantity: 12,
        isDefault: true,
        imageUrls: const ['assets/images/products/textiles/fabric.jpg'],
        optionRefs: [_ref(couleur, 'o-indigo'), _ref(longueur, 'o-2m')],
      ),
      ProductVariant(
        id: 'v-indigo-6',
        productId: p,
        name: 'Indigo 6 m',
        priceFcfa: 39000,
        stockQuantity: 4,
        displayOrder: 1,
        imageUrls: const ['assets/images/products/textiles/fabric.jpg'],
        optionRefs: [_ref(couleur, 'o-indigo'), _ref(longueur, 'o-6m')],
      ),
      ProductVariant(
        id: 'v-ocre',
        productId: p,
        name: 'Ocre 2 m 3 m',
        priceFcfa: 16000,
        stockQuantity: 8,
        displayOrder: 2,
        imageUrls: const ['assets/images/products/textiles/fabric_2.jpg'],
        optionRefs: [
          _ref(couleur, 'o-ocre'),
          _ref(longueur, 'o-2m'),
          _ref(longueur, 'o-3m'),
        ],
      ),
      ProductVariant(
        id: 'v-noir',
        productId: p,
        name: 'Noir 3 m',
        priceFcfa: 18000,
        stockQuantity: 0,
        displayOrder: 3,
        optionRefs: [_ref(couleur, 'o-noir'), _ref(longueur, 'o-3m')],
      ),
    ],
  );
}

/// Les avis du bogolan : notes variées, photos de l'acheteur, réponse du
/// vendeur et commentaires sous un avis.
List<ProductReview> avisDemo() => [
  ProductReview(
    id: 'avis-1',
    stars: 5,
    title: 'Plus beau qu\'en photo',
    comment:
        'Les couleurs sont encore plus belles qu\'en photo, et le tissu est '
        'épais. Livré en deux jours à Bamako.',
    createdAt: maintenant.subtract(const Duration(hours: 2)),
    authorName: 'Awa Traoré',
    imagePaths: const [
      'assets/images/products/textiles/fabric_2.jpg',
      'assets/images/products/textiles/fabric.jpg',
    ],
    supplierReply: 'Merci Awa ! Au plaisir de vous revoir à la boutique.',
    comments: [
      ReviewComment(
        id: 'com-1',
        body: 'Il déteint au lavage ?',
        createdAt: maintenant.subtract(const Duration(hours: 1)),
        authorName: 'Moussa Keïta',
      ),
      ReviewComment(
        id: 'com-2',
        body: 'Non, si vous le lavez à froid la première fois.',
        createdAt: maintenant.subtract(const Duration(minutes: 20)),
        authorName: 'Bogolan Bamako',
        authorIsSupplier: true,
      ),
    ],
  ),
  ProductReview(
    id: 'avis-2',
    stars: 4,
    comment: 'Très joli motif. La longueur de 2 m est juste pour un boubou.',
    createdAt: maintenant.subtract(const Duration(days: 3)),
    authorName: 'Fatoumata Diarra Coulibaly',
  ),
  ProductReview(
    id: 'avis-3',
    stars: 3,
    comment: 'Correct, mais la teinte ocre est plus claire que sur la photo.',
    createdAt: maintenant.subtract(const Duration(days: 12)),
    authorName: 'Ibrahim Sangaré',
  ),
];

/// Les questions publiques posées sur le bogolan.
List<ProductComment> commentairesDemo() => [
  for (var i = 0; i < 3; i++)
    ProductComment(
      id: 'q-$i',
      productId: 'bogolan',
      supplierId: 'f-Bogolan Bamako',
      authorId: 'client-$i',
      authorName: 'Client $i',
      createdAt: maintenant.subtract(Duration(days: i + 1)),
      text: 'Question $i',
    ),
];
