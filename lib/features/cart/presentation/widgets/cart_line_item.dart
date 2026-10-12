import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/app/theme/app_shadows.dart';
import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';
import 'package:mtc_app/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:mtc_app/features/catalog/presentation/widgets/product_card.dart'
    show ProductImage;

import '../../domain/entities/cart_item.dart';
import '../controllers/cart_controller.dart';

class CartLineItem extends ConsumerWidget {
  const CartLineItem({super.key, required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final controller = ref.read(cartControllerProvider.notifier);
    final product = ref.watch(productDetailProvider(item.productId)).valueOrNull;
    final variant = product?.variants.firstWhereOrNull((v) => v.id == item.variantId);
    // The variant's own stock when this line has one, falling back to the
    // product's (either a plain variant-less product, or a variant that's
    // since been removed by the supplier) — `null` only while [product]
    // itself hasn't loaded yet, in which case the stepper below stays
    // unconstrained rather than blocking on a still-loading limit.
    final resolvedStock = variant?.stockQuantity ?? product?.stockQuantity;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        boxShadow: AppShadows.soft(brightness),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            child: SizedBox(
              width: 64,
              height: 64,
              child: ProductImage(
                imageUrl:
                    variant?.imageUrls.firstOrNull ??
                    product?.imageUrls.firstOrNull,
                icon: Icons.inventory_2_outlined,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productNameSnapshot,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (item.variantNameSnapshot != null)
                  Text(
                    item.variantNameSnapshot!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                const SizedBox(height: 2),
                CurrencyText(
                  item.unitPriceFcfaSnapshot,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (resolvedStock != null)
                  Text(
                    resolvedStock > 0
                        ? '$resolvedStock en stock'
                        : 'Rupture de stock',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: resolvedStock > 0
                          ? scheme.onSurfaceVariant
                          : scheme.error,
                    ),
                  ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      onTap: () =>
                          context.push(AppRoutes.productDetail(item.productId)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.edit_outlined,
                              size: 14,
                              color: scheme.primary,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              'Modifier',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
                visualDensity: VisualDensity.compact,
                onPressed: () => controller.removeItem(item.id),
              ),
              QuantityStepper(
                quantity: item.quantity,
                maxQuantity: resolvedStock,
                onChanged: (value) => controller.updateQuantity(item.id, value),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
