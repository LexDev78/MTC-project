import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/core/widgets/core_widgets.dart';
import 'package:mtc_app/features/favorites/presentation/widgets/favorite_toggle_button.dart';

import '../../domain/entities/product_category.dart';
import '../providers/catalog_providers.dart';
import '../widgets/product_grid.dart';

/// Body of one of the two isolated catalog tabs (Fournisseurs tiers /
/// Fournisseur principal) on Accueil. Parameterized by [supplierType] so
/// both tabs reuse the same widget while keeping fully separate provider
/// state. The filter entry point lives one level up, alongside the
/// category dropdown in `ClientHomeScreen`'s header row (see
/// `_FilterIconButton` there), so it stays visually aligned with it
/// instead of floating in this tab body.
///
/// A flat, ungrouped feed of cards — deliberately not grouped by category
/// here (that's what the "Catalogue" tab is for, see `CatalogueScreen`/
/// `CategoryProductsScreen`). The category dropdown still narrows this
/// same grid via [catalogCategoryProvider]/`productListProvider`; it just
/// no longer changes which *widget* renders — always the flat grid, never
/// grouped sections.
class CatalogTabScreen extends ConsumerWidget {
  const CatalogTabScreen({super.key, required this.supplierType});

  final SupplierType supplierType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productListProvider(supplierType));

    return AsyncValueWidget(
      value: productsAsync,
      data: (products) {
        if (products.isEmpty) {
          return const MtcEmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'Aucun produit pour le moment',
          );
        }
        return ProductGrid(
          products: products,
          cardOverlayBuilder: (product) => FavoriteToggleButton(
            productId: product.id,
            size: 20,
            inactiveColor: Colors.white,
          ),
        );
      },
    );
  }
}
