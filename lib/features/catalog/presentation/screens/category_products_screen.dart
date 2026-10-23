import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/core/error/user_message.dart';
import 'package:mtc_app/core/shop/shop.dart';

import '../../domain/entities/product.dart';
import '../../domain/entities/product_category.dart';
import '../../domain/product_list_filters.dart';
import '../providers/catalog_providers.dart';
import '../widgets/product_filter_sheet.dart';
import '../widgets/product_image.dart' show ProductCategoryImage;
import '../widgets/shop_product_data.dart';
import '../widgets/shop_product_grid.dart';

/// Une catégorie, d'après la maquette « Kids » du kit : la recherche avec
/// son filtre, la bannière de la catégorie, puis les articles en grille —
/// des deux types de fournisseurs.
class CategoryProductsScreen extends ConsumerWidget {
  const CategoryProductsScreen({super.key, required this.category});

  final ProductCategory category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final produits = ref.watch(categoryProductListProvider(category));
    final tous = ref.watch(categoryAllProductsProvider(category));
    final filtres = ref.watch(categoryFiltersProvider(category));
    final filtre = filtres.hasFilter;

    Future<void> filtrer() async {
      final choix = await showProductFilterSheet(
        context,
        products: tous.valueOrNull ?? const [],
        current: filtres,
        byCategory: false,
      );
      if (choix != null) {
        ref.read(categoryFiltersProvider(category).notifier).state = choix;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(category.label),
        actions: [
          IconButton(
            tooltip: 'Panier',
            onPressed: () => context.go(AppRoutes.clientCart),
            icon: const ShopIcon(ShopIcons.bag),
          ),
          const SizedBox(width: ShopSizes.padding / 2),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                ShopSizes.screenMargin,
                ShopSizes.padding / 2,
                ShopSizes.screenMargin,
                ShopSizes.padding * 1.5,
              ),
              child: ShopSearchField(
                hintText: 'Rechercher un article…',
                onTap: () => context.push(AppRoutes.clientSearch),
                onFilterTap: filtrer,
                filterActive: filtres.isActive,
              ),
            ),
          ),
          SliverToBoxAdapter(
            // La catégorie entière, pas la liste filtrée : la bannière
            // présente la catégorie, elle ne commente pas les filtres.
            child: _Banniere(category: category, produits: tous.valueOrNull),
          ),
          ...produits.when(
            loading: () => [
              SliverPadding(
                padding: const EdgeInsets.all(ShopSizes.screenMargin),
                sliver: SliverGrid.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: ShopSizes.padding,
                  crossAxisSpacing: ShopSizes.padding,
                  childAspectRatio: 0.66,
                  children: List.generate(
                    4,
                    (_) => const ProductCardSkeleton(),
                  ),
                ),
              ),
            ],
            error: (error, _) => [
              SliverToBoxAdapter(
                child: IllustratedMessage(
                  compact: true,
                  illustration: ShopIllustration.serverError,
                  title: 'Les articles n\'ont pas pu être chargés',
                  message: messagePourUtilisateur(error),
                ),
              ),
            ],
            data: (liste) => [
              if (liste.isEmpty)
                SliverToBoxAdapter(
                  child: IllustratedMessage(
                    compact: true,
                    illustration: ShopIllustration.emptyState,
                    title: filtre
                        ? 'Aucun article pour ces filtres'
                        : 'Aucun article dans cette catégorie',
                    message: filtre
                        ? 'Élargissez la fourchette de prix, ou effacez les filtres.'
                        : 'Les boutiques n\'y ont encore rien publié.',
                    action: filtre
                        ? OutlinedButton(
                            // Le tri reste : il ne vide pas une liste.
                            onPressed: () =>
                                ref
                                    .read(
                                      categoryFiltersProvider(
                                        category,
                                      ).notifier,
                                    )
                                    .state = ProductListFilters(
                                  sort: filtres.sort,
                                ),
                            child: const Text('Effacer les filtres'),
                          )
                        : null,
                  ),
                )
              else
                SliverShopProductGrid(
                  products: liste,
                  padding: ShopSizes.screenMargin,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// La bannière de la catégorie (« SPECIAL OFFER / FASHION SALE / 50% OFF »
/// dans la maquette) : la remise annoncée est la plus forte qui court
/// vraiment dans la catégorie ; sans remise, le nombre d'articles.
class _Banniere extends StatelessWidget {
  const _Banniere({required this.category, required this.produits});

  final ProductCategory category;
  final List<Product>? produits;

  @override
  Widget build(BuildContext context) {
    final liste = produits ?? const <Product>[];
    final remises = [for (final p in liste) p.shopData().discountPercent ?? 0]
      ..sort();
    final meilleure = remises.isEmpty ? 0 : remises.last;
    final pastille = meilleure > 0
        ? 'Jusqu\'à -$meilleure %'
        : (produits == null
              ? null
              : liste.length == 1
              ? '1 article'
              : '${liste.length} articles');
    return ShopBanner(
      image: category.imageAsset,
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: ShopSizes.padding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'SÉLECTION MTC',
                  style: ShopTextStyles.display(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: ShopSizes.padding / 4),
                BannerHeadline(
                  category.label,
                  fontSize: 30,
                  textAlign: TextAlign.center,
                ),
                if (pastille != null) ...[
                  const SizedBox(height: ShopSizes.padding / 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: ShopSizes.padding,
                      vertical: ShopSizes.padding / 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      pastille.toUpperCase(),
                      style: ShopTextStyles.display(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: ShopColors.black80,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
