import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/app/theme/app_shadows.dart';
import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';

import '../../domain/entities/product.dart';
import '../../domain/entities/product_category.dart';

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

class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product, this.overlay});

  final Product product;

  /// Optional widget pinned to the image's top-right corner — e.g. a
  /// favorite-toggle heart. Kept as an injected slot (rather than importing
  /// the favorites feature directly) so this shared widget stays
  /// feature-agnostic; the composing screen decides what to overlay.
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final brightness = Theme.of(context).brightness;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        boxShadow: AppShadows.soft(brightness),
      ),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(AppRoutes.productDetail(product.id)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Expanded (not a fixed AspectRatio) so the photo absorbs
              // whatever height the grid cell has left over after the text
              // block below — otherwise a short name/no-variant card leaves
              // dead space at the bottom instead of a taller image.
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ProductImage(
                      imageUrl: product.imageUrls.isEmpty
                          ? null
                          : product.imageUrls.first,
                      icon: product.category.icon,
                    ),
                    if (overlay != null)
                      Positioned(top: 0, right: 0, child: overlay!),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          product.ratingAverage.toStringAsFixed(1),
                          style: textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            product.supplierName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    CurrencyText(
                      product.priceFcfa,
                      style: textTheme.titleSmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows the product's first photo, falling back to a tinted category icon
/// when no asset is available or the asset fails to load (kept resilient
/// since [Product.imageUrls] is allowed to be empty in the data model).
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

    return Image.asset(
      imageUrl!,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _fallback(scheme),
    );
  }

  Widget _fallback(ColorScheme scheme) {
    return Container(
      color: scheme.primaryContainer.withValues(alpha: 0.4),
      child: Icon(icon, size: 40, color: scheme.primary),
    );
  }
}
