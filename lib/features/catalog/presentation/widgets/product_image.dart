import 'package:flutter/material.dart';

import 'package:mtc_app/core/widgets/resolved_image.dart';

import '../../domain/entities/product_category.dart';

/// Une icône par catégorie, pour les vignettes sans photo et les listes des
/// fournisseurs.
extension ProductCategoryIcon on ProductCategory {
  IconData get icon => switch (this) {
    ProductCategory.textilesBogolan => Icons.checkroom_rounded,
    ProductCategory.artisanat => Icons.brush_rounded,
    ProductCategory.electronique => Icons.devices_rounded,
    ProductCategory.alimentation => Icons.rice_bowl_rounded,
    ProductCategory.materiauxConstruction => Icons.construction_rounded,
    ProductCategory.autre => Icons.category_rounded,
  };
}

/// Une photo représentative par catégorie, livrée avec l'app, pour les
/// tuiles de catégorie — `null` pour [ProductCategory.autre], qui n'a pas
/// de photo à elle et retombe sur son icône.
extension ProductCategoryImage on ProductCategory {
  String? get imageAsset => switch (this) {
    ProductCategory.textilesBogolan =>
      'assets/images/products/textiles/fabric.jpg',
    ProductCategory.artisanat => 'assets/images/products/artisanat/mask.jpg',
    ProductCategory.electronique =>
      'assets/images/products/electronique/smartphone.jpg',
    ProductCategory.alimentation =>
      'assets/images/products/alimentation/rice.jpg',
    ProductCategory.materiauxConstruction =>
      'assets/images/products/materiaux/steel.jpg',
    ProductCategory.autre => null,
  };
}

/// La première photo d'un produit, ou l'icône teintée de sa catégorie quand
/// il n'en a pas ou qu'elle ne se charge pas ([Product.imageUrls] peut être
/// vide).
///
/// Utilisée par les écrans des fournisseurs, la discussion et les
/// commentaires ; le côté client a `ShopImage`.
class ProductImage extends StatelessWidget {
  const ProductImage({super.key, required this.imageUrl, required this.icon});

  final String? imageUrl;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (imageUrl == null) {
      return _fallback(scheme);
    }

    // Vignette jamais affichée à plus de quelques centaines de points :
    // décodée à cette taille plutôt qu'à celle de la photo d'origine, elle
    // n'alloue pas une image pleine résolution par carte et par défilement.
    return ResolvedImage(
      path: imageUrl!,
      bucket: 'product-images',
      errorBuilder: (context, error, stackTrace) => _fallback(scheme),
      cacheWidth: 400,
    );
  }

  Widget _fallback(ColorScheme scheme) {
    return Container(
      color: scheme.primaryContainer.withValues(alpha: 0.4),
      child: Icon(icon, size: 40, color: scheme.primary),
    );
  }
}
