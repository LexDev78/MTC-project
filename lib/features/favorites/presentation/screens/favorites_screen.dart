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
import 'package:mtc_app/features/orders/presentation/providers/checkout_providers.dart';

import '../controllers/favorite_controller.dart';
import '../providers/favorite_providers.dart';
import '../widgets/favorite_line_item.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  void _enterSelectionMode() {
    setState(() => _selectionMode = true);
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelected(String productId) {
    setState(() {
      if (!_selectedIds.remove(productId)) {
        _selectedIds.add(productId);
      }
    });
  }

  void _toggleSelectAll(List<Product> products) {
    setState(() {
      if (_selectedIds.length == products.length) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(products.map((p) => p.id));
      }
    });
  }

  Iterable<Product> _selectedProducts(List<Product> products) =>
      products.where((p) => _selectedIds.contains(p.id));

  Future<void> _removeSelected(List<Product> products) async {
    final controller = ref.read(favoriteControllerProvider.notifier);
    for (final product in _selectedProducts(products)) {
      await controller.toggle(product.id);
    }
    if (mounted) _exitSelectionMode();
  }

  Future<void> _addSelectedToCart(List<Product> products) async {
    final controller = ref.read(cartControllerProvider.notifier);
    for (final product in _selectedProducts(products)) {
      final quantity = ref.read(favoriteQuantityProvider(product.id));
      await controller.addProduct(product, quantity: quantity);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoutés au panier')),
      );
      _exitSelectionMode();
    }
  }

  Future<void> _buySelected(List<Product> products) async {
    final controller = ref.read(cartControllerProvider.notifier);
    for (final product in _selectedProducts(products)) {
      final quantity = ref.read(favoriteQuantityProvider(product.id));
      await controller.addProduct(product, quantity: quantity);
    }
    if (mounted) {
      _exitSelectionMode();
      // These selected favorites were just added to the real cart above
      // (there can be several, not just one), so checkout must read from
      // the cart — clear any leftover single-item "Acheter" override first.
      ref.read(buyNowItemProvider.notifier).state = null;
      unawaited(context.push(AppRoutes.clientCheckout));
    }
  }

  @override
  Widget build(BuildContext context) {
    final favoritesAsync = ref.watch(favoriteProductsProvider);
    final products = favoritesAsync.valueOrNull ?? const <Product>[];

    return Scaffold(
      appBar: AppBar(
        leading: _selectionMode
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Annuler',
                onPressed: _exitSelectionMode,
              )
            : null,
        title: Text(
          _selectionMode ? '${_selectedIds.length} sélectionné(s)' : 'Favoris',
        ),
        actions: [
          if (_selectionMode)
            IconButton(
              icon: Icon(
                _selectedIds.length == products.length && products.isNotEmpty
                    ? Icons.deselect_rounded
                    : Icons.select_all_rounded,
              ),
              tooltip: 'Tout sélectionner',
              onPressed: () => _toggleSelectAll(products),
            )
          else
            IconButton(
              icon: const Icon(Icons.checklist_rounded),
              tooltip: 'Sélectionner plusieurs',
              onPressed: products.isEmpty ? null : _enterSelectionMode,
            ),
        ],
      ),
      body: AsyncValueWidget(
        value: favoritesAsync,
        data: (products) {
          if (products.isEmpty) {
            return const MtcEmptyState(
              icon: Icons.favorite_border_rounded,
              title: 'Aucun favori pour le moment',
              subtitle:
                  'Appuyez sur le cœur sur un produit pour le retrouver ici.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            itemCount: products.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final product = products[index];
              return FavoriteLineItem(
                product: product,
                selectionMode: _selectionMode,
                isSelected: _selectedIds.contains(product.id),
                onSelectToggle: () => _toggleSelected(product.id),
              );
            },
          );
        },
      ),
      bottomNavigationBar: _selectionMode && _selectedIds.isNotEmpty
          ? _SelectionActionBar(
              onRemove: () => _removeSelected(products),
              onAddToCart: () => _addSelectedToCart(products),
              onBuy: () => _buySelected(products),
            )
          : null,
    );
  }
}

class _SelectionActionBar extends StatelessWidget {
  const _SelectionActionBar({
    required this.onRemove,
    required this.onAddToCart,
    required this.onBuy,
  });

  final VoidCallback onRemove;
  final VoidCallback onAddToCart;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final isCompact =
        MediaQuery.sizeOf(context).width < AppSpacing.compactScreenWidth;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        boxShadow: AppShadows.bar(brightness),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Tooltip(
                message: 'Retirer',
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: scheme.error,
                  ),
                  onPressed: onRemove,
                  icon: const Icon(Icons.favorite_border_rounded, size: 18),
                  label: isCompact
                      ? const SizedBox.shrink()
                      : const Text('Retirer'),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Tooltip(
                message: 'Ajouter au panier',
                child: OutlinedButton(
                  onPressed: onAddToCart,
                  child: isCompact
                      ? const Icon(Icons.add_shopping_cart_rounded, size: 18)
                      : const Text('Ajouter au panier'),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Tooltip(
                message: 'Acheter',
                child: isCompact
                    ? FilledButton(
                        onPressed: onBuy,
                        child: const Icon(
                          Icons.shopping_bag_outlined,
                          size: 18,
                        ),
                      )
                    : MtcPrimaryButton(label: 'Acheter', onPressed: onBuy),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
