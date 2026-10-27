import 'package:flutter/material.dart';

import '../shop_tokens.dart';
import 'product_cards.dart';
import 'skeletons.dart';

/// Le titre d'une section (« Produits populaires », « Catégories »).
///
/// Une action facultative à droite (« Tout voir »), en violet comme les
/// liens du kit.
class SectionTitle extends StatelessWidget {
  const SectionTitle(
    this.title, {
    super.key,
    this.actionLabel,
    this.onAction,
    this.trailing,
    this.padding = const EdgeInsets.all(ShopSizes.padding),
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Remplace l'action quand la droite porte autre chose (un compte à
  /// rebours, un compteur).
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final droite =
        trailing ??
        (actionLabel == null
            ? null
            : GestureDetector(
                onTap: onAction,
                child: Text(
                  actionLabel!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: ShopColors.primary),
                ),
              ));
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleSmall),
          ),
          ?droite,
        ],
      ),
    );
  }
}

/// Une rangée horizontale avec les marges du kit : 16 avant chaque
/// élément, 16 après le dernier.
class HorizontalCardRow extends StatelessWidget {
  const HorizontalCardRow({
    super.key,
    required this.height,
    required this.itemCount,
    required this.itemBuilder,
  });

  final double height;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: itemCount,
        itemBuilder: (context, index) => Padding(
          padding: EdgeInsets.only(
            left: ShopSizes.padding,
            right: index == itemCount - 1 ? ShopSizes.padding : 0,
          ),
          child: itemBuilder(context, index),
        ),
      ),
    );
  }
}

/// Un titre de section et sa rangée de cartes — l'unité de l'accueil du
/// kit (« Popular products », « Flash sale », « Best sellers »), qu'il
/// recopiait trois fois.
///
/// [products] à `null` : chargement, silhouettes à la place des cartes.
class ProductCarouselSection extends StatelessWidget {
  const ProductCarouselSection({
    super.key,
    required this.title,
    required this.products,
    required this.onTap,
    this.secondary = false,
    this.trailing,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final List<ShopProductData>? products;
  final void Function(int index) onTap;

  /// Cartes horizontales (« Les plus populaires ») plutôt que verticales.
  final bool secondary;
  final Widget? trailing;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final liste = products;
    final hauteur = secondary
        ? ShopSizes.secondaryProductCardHeight
        : ShopSizes.productCardHeight;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: ShopSizes.padding / 2),
        SectionTitle(
          title,
          trailing: trailing,
          actionLabel: actionLabel,
          onAction: onAction,
        ),
        if (liste == null)
          HorizontalCardRow(
            height: hauteur,
            itemCount: 4,
            itemBuilder: (_, _) => secondary
                ? const SecondaryProductCardSkeleton()
                : const ProductCardSkeleton(),
          )
        else
          HorizontalCardRow(
            height: hauteur,
            itemCount: liste.length,
            itemBuilder: (context, index) => secondary
                ? ShopSecondaryProductCard(
                    data: liste[index],
                    onTap: () => onTap(index),
                  )
                : ShopProductCard(
                    data: liste[index],
                    onTap: () => onTap(index),
                  ),
          ),
      ],
    );
  }
}
