import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/app/theme/app_shadows.dart';
import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/cart/domain/entities/cart_item.dart';
import 'package:mtc_app/features/cart/presentation/controllers/cart_controller.dart';
import 'package:mtc_app/features/catalog/domain/entities/product.dart';
import 'package:mtc_app/features/catalog/presentation/widgets/product_card.dart'
    show ProductImage;
import 'package:mtc_app/features/orders/presentation/providers/checkout_providers.dart';

import '../providers/favorite_providers.dart';
import 'favorite_toggle_button.dart';

class FavoriteLineItem extends ConsumerWidget {
  const FavoriteLineItem({
    super.key,
    required this.product,
    this.selectionMode = false,
    this.isSelected = false,
    this.onSelectToggle,
  });

  final Product product;
  final bool selectionMode;
  final bool isSelected;
  final VoidCallback? onSelectToggle;

  Future<void> _addToCart(
    BuildContext context,
    WidgetRef ref,
    int quantity,
  ) async {
    await ref
        .read(cartControllerProvider.notifier)
        .addProduct(product, quantity: quantity);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajouté au panier')),
      );
    }
  }

  void _buyNow(BuildContext context, WidgetRef ref, int quantity) {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;
    // Stages a buy-now override instead of adding to the shared cart — see
    // `buyNowItemProvider`'s doc comment — so checkout purchases just this
    // product, not whatever else is already in the cart.
    ref.read(buyNowItemProvider.notifier).state = CartItem(
      id: 'buy-now-${product.id}',
      userId: user.id,
      productId: product.id,
      supplierId: product.supplierId,
      productNameSnapshot: product.name,
      unitPriceFcfaSnapshot: product.priceFcfa,
      quantity: quantity,
      addedAt: DateTime.now(),
    );
    unawaited(context.push(AppRoutes.clientCheckout));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final brightness = Theme.of(context).brightness;
    final quantity = ref.watch(favoriteQuantityProvider(product.id));

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: selectionMode ? onSelectToggle : null,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: isSelected ? scheme.primaryContainer : scheme.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: isSelected
                ? Border.all(color: scheme.primary, width: 1.5)
                : null,
            boxShadow: AppShadows.soft(brightness),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    onTap: selectionMode
                        ? onSelectToggle
                        : () =>
                              context.push(AppRoutes.productDetail(product.id)),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      child: SizedBox(
                        width: 96,
                        height: 96,
                        child: ProductImage(
                          imageUrl: product.imageUrls.isEmpty
                              ? null
                              : product.imageUrls.first,
                          icon: Icons.inventory_2_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                product.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  height: 1.25,
                                ),
                              ),
                            ),
                            if (selectionMode)
                              Padding(
                                padding: const EdgeInsets.only(left: AppSpacing.xs),
                                child: Checkbox(
                                  value: isSelected,
                                  onChanged: (_) => onSelectToggle?.call(),
                                ),
                              )
                            else
                              Padding(
                                padding: const EdgeInsets.only(
                                  // Optically balances `FavoriteToggleButton`'s
                                  // own internal `IconButton` padding against
                                  // the title's baseline instead of sitting
                                  // noticeably higher than it.
                                  top: 4,
                                ),
                                child: FavoriteToggleButton(
                                  productId: product.id,
                                  size: 22,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        CurrencyText(
                          product.priceFcfa,
                          compareAtAmountFcfa: product.compareAtPriceFcfa,
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
              const SizedBox(height: AppSpacing.md),
              IgnorePointer(
                ignoring: selectionMode,
                child: Opacity(
                  opacity: selectionMode ? 0.5 : 1,
                  child: Row(
                    children: [
                      QuantityStepper(
                        quantity: quantity,
                        minQuantity: 1,
                        maxQuantity: product.stockQuantity,
                        onChanged: (value) => ref
                            .read(favoriteQuantityProvider(product.id).notifier)
                            .state = value,
                      ),
                      const Spacer(),
                      Tooltip(
                        message: 'Acheter',
                        child: IconButton.outlined(
                          onPressed: () => _buyNow(context, ref, quantity),
                          icon: const Icon(Icons.shopping_bag_outlined),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Tooltip(
                        message: 'Ajouter au panier',
                        child: IconButton.filledTonal(
                          onPressed: () => _addToCart(context, ref, quantity),
                          icon: const Icon(Icons.add_shopping_cart_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
