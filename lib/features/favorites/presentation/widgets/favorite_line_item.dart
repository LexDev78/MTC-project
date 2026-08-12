import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/app/theme/app_shadows.dart';
import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';
import 'package:mtc_app/features/cart/presentation/controllers/cart_controller.dart';
import 'package:mtc_app/features/catalog/domain/entities/product.dart';
import 'package:mtc_app/features/catalog/presentation/widgets/product_card.dart'
    show ProductImage;

import '../controllers/favorite_controller.dart';
import '../providers/favorite_providers.dart';

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

  Future<void> _buyNow(BuildContext context, WidgetRef ref, int quantity) async {
    await ref
        .read(cartControllerProvider.notifier)
        .addProduct(product, quantity: quantity);
    if (context.mounted) {
      unawaited(context.push(AppRoutes.clientCheckout));
    }
  }

  static const _compactButtonStyle = ButtonStyle(
    padding: WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: AppSpacing.sm),
    ),
    minimumSize: WidgetStatePropertyAll(Size.zero),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12)),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final isCompact =
        MediaQuery.sizeOf(context).width < AppSpacing.compactScreenWidth;
    final quantity = ref.watch(favoriteQuantityProvider(product.id));

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: selectionMode ? onSelectToggle : null,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: isSelected ? scheme.primaryContainer : scheme.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: isSelected
                ? Border.all(color: scheme.primary, width: 1.5)
                : null,
            boxShadow: AppShadows.soft(brightness),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                onTap: selectionMode
                    ? onSelectToggle
                    : () => context.push(AppRoutes.productDetail(product.id)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  child: SizedBox(
                    width: 64,
                    height: 64,
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
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    CurrencyText(
                      product.priceFcfa,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    QuantityStepper(
                      quantity: quantity,
                      minQuantity: 1,
                      maxQuantity: product.stockQuantity,
                      onChanged: (value) => ref
                          .read(favoriteQuantityProvider(product.id).notifier)
                          .state = value,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    IgnorePointer(
                      ignoring: selectionMode,
                      child: Opacity(
                        opacity: selectionMode ? 0.5 : 1,
                        child: SizedBox(
                          height: 32,
                          child: Row(
                            children: [
                              Expanded(
                                child: Tooltip(
                                  message: 'Acheter',
                                  child: OutlinedButton(
                                    style: _compactButtonStyle,
                                    onPressed: () =>
                                        _buyNow(context, ref, quantity),
                                    child: isCompact
                                        ? const Icon(
                                            Icons.shopping_bag_outlined,
                                            size: 16,
                                          )
                                        : const Text('Acheter'),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: Tooltip(
                                  message: 'Ajouter au panier',
                                  child: FilledButton.tonal(
                                    style: _compactButtonStyle,
                                    onPressed: () =>
                                        _addToCart(context, ref, quantity),
                                    child: isCompact
                                        ? const Icon(
                                            Icons.add_shopping_cart_rounded,
                                            size: 16,
                                          )
                                        : const Text('Ajouter au panier'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              if (selectionMode)
                Checkbox(
                  value: isSelected,
                  onChanged: (_) => onSelectToggle?.call(),
                )
              else
                IconButton(
                  icon: Icon(Icons.favorite_rounded, color: scheme.error),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Retirer des favoris',
                  onPressed: () => ref
                      .read(favoriteControllerProvider.notifier)
                      .toggle(product.id),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
