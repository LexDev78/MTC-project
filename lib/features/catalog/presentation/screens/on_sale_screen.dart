import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/core/error/user_message.dart';
import 'package:mtc_app/core/shop/shop.dart';

import '../../domain/entities/product.dart';
import '../providers/home_catalog.dart';
import '../widgets/shop_product_data.dart';

/// Les promotions en cours, d'après la maquette « On sale » du kit : la
/// bande de vente flash, la grande bannière, la rangée « Vente flash »,
/// puis toutes les remises en grille.
///
/// Tout pourcentage affiché ici est celui d'une promotion qui court
/// vraiment (`HomeSections.onSale`) — le même calcul que le prix facturé.
class OnSaleScreen extends ConsumerWidget {
  const OnSaleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogue = ref.watch(homeProductsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Promotions'),
        actions: [
          IconButton(
            tooltip: 'Panier',
            onPressed: () => context.go(AppRoutes.clientCart),
            icon: const ShopIcon(ShopIcons.bag),
          ),
          const SizedBox(width: ShopSizes.padding / 2),
        ],
      ),
      body: catalogue.when(
        loading: () => ListView(
          children: const [
            BannerSkeleton(aspectRatio: 6),
            SizedBox(height: ShopSizes.padding / 2),
            BannerSkeleton(aspectRatio: 1.1),
          ],
        ),
        error: (error, _) => IllustratedMessage(
          illustration: ShopIllustration.serverError,
          title: 'Les promotions n\'ont pas pu être chargées',
          message: messagePourUtilisateur(error),
          action: OutlinedButton(
            onPressed: () => ref.invalidate(homeProductsProvider),
            child: const Text('Réessayer'),
          ),
        ),
        data: (produits) {
          final sections = HomeSections(produits);
          final promos = sections.onSale;
          if (promos.isEmpty) {
            return const IllustratedMessage(
              illustration: ShopIllustration.emptyState,
              title: 'Aucune promotion en cours',
              message:
                  'Les remises des boutiques apparaîtront ici dès qu\'elles commencent.',
            );
          }
          return _Promotions(sections: sections, promos: promos);
        },
      ),
    );
  }
}

class _Promotions extends StatelessWidget {
  const _Promotions({required this.sections, required this.promos});

  final HomeSections sections;
  final List<PromotedProduct> promos;

  void _ouvrir(BuildContext context, Product produit) =>
      context.push(AppRoutes.productDetail(produit.id));

  @override
  Widget build(BuildContext context) {
    final flash = sections.flashSale;
    final fin = sections.flashSaleEndsAt;
    final meilleure = promos.first;
    String? photo(Product p) => p.imageUrls.isEmpty ? null : p.imageUrls.first;

    return CustomScrollView(
      slivers: [
        if (flash.isNotEmpty && fin != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: ShopSizes.padding / 2),
              child: ShopBanner(
                image: photo(flash.first.product),
                aspectRatio: 375 / 63,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: ShopSizes.padding,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Vente flash -${flash.first.percent} %',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ShopTextStyles.display(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                        Transform.scale(
                          scale: 0.75,
                          alignment: Alignment.centerRight,
                          child: CountdownBoxes(endsAt: fin),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: OfferBannerLarge(
            image: photo(meilleure.product),
            title: meilleure.label?.trim().isNotEmpty == true
                ? meilleure.label!.trim()
                : meilleure.product.category.label,
            subtitle: 'OFFRE SPÉCIALE',
            discountPercent: meilleure.percent,
            onTap: () => _ouvrir(context, meilleure.product),
          ),
        ),
        if (flash.isNotEmpty && fin != null)
          SliverToBoxAdapter(
            child: ProductCarouselSection(
              title: 'Vente flash',
              trailing: CountdownBoxes(
                endsAt: fin,
                style: CountdownStyle.outlined,
              ),
              products: [for (final p in flash) p.product.shopData()],
              onTap: (i) => _ouvrir(context, flash[i].product),
            ),
          ),
        const SliverToBoxAdapter(
          child: SectionTitle(
            'Toutes les promotions',
            padding: EdgeInsets.fromLTRB(
              ShopSizes.padding,
              ShopSizes.padding * 1.5,
              ShopSizes.padding,
              ShopSizes.padding,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            ShopSizes.padding,
            0,
            ShopSizes.padding,
            ShopSizes.padding,
          ),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              mainAxisSpacing: ShopSizes.padding,
              crossAxisSpacing: ShopSizes.padding,
              childAspectRatio: 0.66,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => ShopProductCard(
                width: null,
                height: null,
                data: promos[index].product.shopData(),
                onTap: () => _ouvrir(context, promos[index].product),
              ),
              childCount: promos.length,
            ),
          ),
        ),
      ],
    );
  }
}
