import 'package:flutter/material.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/widgets/fade_slide_in.dart';

import '../../domain/entities/product.dart';
import 'product_card.dart';

class ProductGrid extends StatelessWidget {
  const ProductGrid({
    super.key,
    required this.products,
    this.shrinkWrap = false,
    this.cardOverlayBuilder,
    this.onProductOpened,
  });

  final List<Product> products;

  /// Set to true when nesting this grid inside another scrollable (e.g. a
  /// `CustomScrollView` on a supplier profile page) so it sizes itself to
  /// its content instead of trying to fill/scroll independently.
  final bool shrinkWrap;

  /// Builds the optional per-card overlay (e.g. a favorite-toggle heart).
  final Widget Function(Product product)? cardOverlayBuilder;

  /// Notifié quand un produit de la grille est ouvert. Transmis tel quel à
  /// `ProductCard.onOpened` — voir là-bas pour le pourquoi.
  final void Function(Product product)? onProductOpened;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.all(AppSpacing.md),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.54,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return FadeSlideIn(
          index: index,
          child: ProductCard(
            product: product,
            overlay: cardOverlayBuilder?.call(product),
            onOpened: onProductOpened == null
                ? null
                : () => onProductOpened!(product),
          ),
        );
      },
    );
  }
}
