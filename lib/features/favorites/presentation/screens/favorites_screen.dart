import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/core/widgets/core_widgets.dart';
import 'package:mtc_app/features/catalog/presentation/widgets/product_grid.dart';

import '../providers/favorite_providers.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(favoriteProductsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Favoris')),
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
          return ProductGrid(products: products);
        },
      ),
    );
  }
}
