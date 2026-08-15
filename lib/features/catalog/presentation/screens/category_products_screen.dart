import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/core/widgets/core_widgets.dart';
import 'package:mtc_app/features/favorites/presentation/widgets/favorite_toggle_button.dart';

import '../../domain/entities/product_category.dart';
import '../providers/catalog_providers.dart';
import '../widgets/category_filter_sheet.dart';
import '../widgets/product_grid.dart';

/// Products in one [ProductCategory], from both supplier types combined —
/// reached by tapping a tile on `CatalogueScreen`.
class CategoryProductsScreen extends ConsumerWidget {
  const CategoryProductsScreen({super.key, required this.category});

  final ProductCategory category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(categoryProductListProvider(category));
    final hasActiveFilter = ref.watch(categoryHasActiveFilterProvider(category));
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(category.label),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.tune_rounded),
                onPressed: () =>
                    showCategoryFilterSheet(context, category: category),
              ),
              if (hasActiveFilter)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: scheme.tertiary,
                      shape: BoxShape.circle,
                      border: Border.all(color: scheme.surface, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: AsyncValueWidget(
        value: productsAsync,
        data: (products) {
          if (products.isEmpty) {
            return const MtcEmptyState(
              icon: Icons.category_outlined,
              title: 'Aucun produit dans cette catégorie',
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
      ),
    );
  }
}
