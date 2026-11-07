import 'package:flutter/material.dart';

import '../shop_tokens.dart';
import 'prices.dart';
import 'shop_image.dart';

/// Ce qu'une carte produit affiche — rien de plus. Les écrans le
/// construisent depuis leurs propres entités (produit du catalogue, ligne
/// de panier, article de commande) ; les cartes, elles, n'en connaissent
/// aucune.
class ShopProductData {
  const ShopProductData({
    required this.imagePath,
    required this.brand,
    required this.title,
    required this.priceFcfa,
    this.compareAtFcfa,
    this.discountPercent,
    this.imageBucket = 'product-images',
  });

  final String? imagePath;
  final String imageBucket;

  /// Au-dessus du titre, en capitales : la boutique, chez MTC.
  final String brand;
  final String title;
  final int priceFcfa;
  final int? compareAtFcfa;
  final int? discountPercent;
}

/// La photo d'un produit avec sa pastille de remise.
class ShopProductImage extends StatelessWidget {
  const ShopProductImage(this.data, {super.key, this.cacheWidth = 400});

  final ShopProductData data;
  final int cacheWidth;

  @override
  Widget build(BuildContext context) {
    final remise = data.discountPercent;
    return Stack(
      children: [
        ShopImage(
          data.imagePath,
          bucket: data.imageBucket,
          cacheWidth: cacheWidth,
        ),
        if (remise != null && remise > 0)
          Positioned(
            right: ShopSizes.padding / 2,
            top: ShopSizes.padding / 2,
            child: DiscountBadge(remise),
          ),
      ],
    );
  }
}

/// Marque, titre, puis le prix tout en bas : le bloc commun aux deux
/// cartes et à la ligne de liste. Seules les tailles changent.
class ShopProductTexts extends StatelessWidget {
  const ShopProductTexts(
    this.data, {
    super.key,
    this.brandSize = 10,
    this.titleSize = 12,
    this.priceSize = ShopPriceSize.card,
    this.titleLines = 2,
    this.priceAtBottom = true,
  });

  final ShopProductData data;
  final double brandSize;
  final double titleSize;
  final ShopPriceSize priceSize;
  final int titleLines;

  /// Dans une carte de hauteur fixe, le prix descend en bas (le `Spacer`
  /// du kit) ; dans une ligne de liste, il suit le titre.
  final bool priceAtBottom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          data.brand.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: brandSize,
            height: 1.2,
          ),
        ),
        const SizedBox(height: ShopSizes.padding / 2),
        Text(
          data.title,
          maxLines: titleLines,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontSize: titleSize,
            fontWeight: FontWeight.w400,
            height: 1.3,
          ),
        ),
        if (priceAtBottom)
          const Spacer()
        else
          const SizedBox(height: ShopSizes.padding / 2),
        ShopPrice(
          data.priceFcfa,
          compareAtFcfa: data.compareAtFcfa,
          size: priceSize,
        ),
      ],
    );
  }
}

/// Le cadre des cartes du kit : un trait fin, arrondi, sur la toile.
class _CardFrame extends StatelessWidget {
  const _CardFrame({
    required this.onTap,
    required this.child,
    this.width,
    this.height,
  });

  final VoidCallback? onTap;
  final Widget child;
  final double? width, height;

  @override
  Widget build(BuildContext context) {
    final bord = Theme.of(context).colorScheme.outline;
    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ShopSizes.radius),
          side: BorderSide(width: 1.5, color: bord),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(ShopSizes.padding / 2),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// La carte produit verticale du kit (`ProductCard`), 140 × 220 par défaut.
///
/// Dans une grille, [width] et [height] restent nuls : la cellule décide.
class ShopProductCard extends StatelessWidget {
  const ShopProductCard({
    super.key,
    required this.data,
    required this.onTap,
    this.width = ShopSizes.productCardWidth,
    this.height = ShopSizes.productCardHeight,
  });

  final ShopProductData data;
  final VoidCallback? onTap;
  final double? width, height;

  @override
  Widget build(BuildContext context) {
    return _CardFrame(
      onTap: onTap,
      width: width,
      height: height,
      // `stretch` : sans lui, le bloc de texte prend la largeur de sa plus
      // longue ligne et se centre — une carte au nom court (« Radio FM
      // solaire ») avait son texte décalé par rapport aux autres.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(aspectRatio: 1.15, child: ShopProductImage(data)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(ShopSizes.padding / 2),
              child: ShopProductTexts(data),
            ),
          ),
        ],
      ),
    );
  }
}

/// La carte produit horizontale du kit (`SecondaryProductCard`), 256 × 114.
class ShopSecondaryProductCard extends StatelessWidget {
  const ShopSecondaryProductCard({
    super.key,
    required this.data,
    required this.onTap,
  });

  final ShopProductData data;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _CardFrame(
      onTap: onTap,
      width: ShopSizes.secondaryProductCardWidth,
      height: ShopSizes.secondaryProductCardHeight,
      child: Row(
        children: [
          AspectRatio(
            aspectRatio: 1.15,
            child: ShopProductImage(data, cacheWidth: 240),
          ),
          const SizedBox(width: ShopSizes.padding / 4),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(ShopSizes.padding / 2),
              child: ShopProductTexts(data),
            ),
          ),
        ],
      ),
    );
  }
}

/// Un article en ligne, sans cadre : panier, récapitulatif de commande,
/// annulation (« Review your order » des maquettes du kit).
///
/// [trailing] reçoit ce que l'écran ajoute à droite (quantité, suppression).
class ShopProductListItem extends StatelessWidget {
  const ShopProductListItem({
    super.key,
    required this.data,
    this.onTap,
    this.trailing,
    this.footer,
  });

  final ShopProductData data;
  final VoidCallback? onTap;
  final Widget? trailing;

  /// Sous le prix : une variante choisie, une quantité, un état.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            height: 71,
            child: ShopProductImage(data, cacheWidth: 200),
          ),
          const SizedBox(width: ShopSizes.padding / 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShopProductTexts(
                  data,
                  brandSize: 12,
                  titleSize: 16,
                  titleLines: 1,
                  priceSize: ShopPriceSize.line,
                  priceAtBottom: false,
                ),
                if (footer != null) ...[
                  const SizedBox(height: ShopSizes.padding / 2),
                  footer!,
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: ShopSizes.padding / 2),
            trailing!,
          ],
        ],
      ),
    );
  }
}
