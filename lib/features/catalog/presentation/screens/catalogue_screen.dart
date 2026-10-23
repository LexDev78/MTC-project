import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/core/shop/shop.dart';
import 'package:mtc_app/features/recommendations/presentation/providers/recommendation_providers.dart';

import '../../domain/entities/product_category.dart';
import '../../domain/product_list_filters.dart';
import '../providers/catalog_providers.dart';
import '../widgets/shop_product_data.dart';

/// L'onglet « Découvrir », d'après le `DiscoverScreen` du kit : la
/// recherche, puis les catégories en lignes qui se déplient.
///
/// MTC n'a pas de sous-catégories : chaque catégorie se déplie sur des
/// entrées qui existent vraiment — tout voir, les nouveautés, les mieux
/// notés, les petits prix — qui ouvrent la catégorie déjà triée.
class CatalogueScreen extends ConsumerWidget {
  const CatalogueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void ouvrir(ProductCategory categorie, ProductSortOption tri) {
      unawaited(
        ref.read(recommendationRepositoryProvider).logCategoryOpen(categorie),
      );
      // Une entrée de la découverte est une vue de la catégorie : elle part
      // de zéro, sans les filtres d'une visite précédente.
      ref.read(categoryFiltersProvider(categorie).notifier).state =
          ProductListFilters(sort: tri);
      context.push(AppRoutes.catalogueCategory(categorie.name));
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(ShopSizes.padding),
              child: ShopSearchField(
                hintText: 'Rechercher un article…',
                onTap: () => context.push(AppRoutes.clientSearch),
                // Comme dans le kit, le filtre est toujours là ; les
                // filtres eux-mêmes vivent dans la recherche.
                onFilterTap: () => context.push(AppRoutes.clientSearch),
              ),
            ),
            const SectionTitle(
              'Catégories',
              padding: EdgeInsets.symmetric(
                horizontal: ShopSizes.padding,
                vertical: ShopSizes.padding / 2,
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  ChevronListTile(
                    icon: ShopIcons.sale,
                    title: 'Promotions',
                    showDivider: false,
                    onTap: () => context.push(AppRoutes.clientOnSale),
                  ),
                  ChevronListTile(
                    icon: ShopIcons.stores,
                    title: 'Boutiques du Mali',
                    showDivider: false,
                    onTap: () => context.push(AppRoutes.clientShops),
                  ),
                  for (final categorie in ProductCategory.values)
                    _CategorieDepliable(
                      categorie: categorie,
                      onOpen: (tri) => ouvrir(categorie, tri),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Une catégorie qui se déplie (`ExpansionCategory` du kit).
class _CategorieDepliable extends StatelessWidget {
  const _CategorieDepliable({required this.categorie, required this.onOpen});

  final ProductCategory categorie;
  final void Function(ProductSortOption tri) onOpen;

  static const _entrees = [
    ('Tous les articles', ProductSortOption.relevance),
    ('Nouveautés', ProductSortOption.newest),
    ('Les mieux notés', ProductSortOption.ratingDesc),
    ('Petits prix', ProductSortOption.priceAsc),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExpansionTile(
      iconColor: theme.colorScheme.onSurface,
      collapsedIconColor: theme.textTheme.bodyMedium?.color,
      shape: const Border(),
      collapsedShape: const Border(),
      leading: ShopIcon(categorie.shopIcon),
      title: Text(categorie.label, style: const TextStyle(fontSize: 14)),
      textColor: theme.colorScheme.onSurface,
      childrenPadding: const EdgeInsets.only(left: ShopSizes.padding * 3.5),
      children: [
        for (var i = 0; i < _entrees.length; i++) ...[
          ListTile(
            onTap: () => onOpen(_entrees[i].$2),
            title: Text(_entrees[i].$1, style: const TextStyle(fontSize: 14)),
          ),
          if (i < _entrees.length - 1) const Divider(height: 1),
        ],
      ],
    );
  }
}
