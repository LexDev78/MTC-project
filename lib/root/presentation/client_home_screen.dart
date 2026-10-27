import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/core/error/user_message.dart';
import 'package:mtc_app/core/shop/shop.dart';
import 'package:mtc_app/features/catalog/domain/entities/product.dart';
import 'package:mtc_app/features/catalog/domain/entities/product_category.dart';
import 'package:mtc_app/features/catalog/presentation/widgets/shop_product_data.dart';
import 'package:mtc_app/features/recommendations/presentation/providers/recommendation_providers.dart';

import 'package:mtc_app/features/catalog/presentation/providers/home_catalog.dart';

/// L'accueil du client, d'après le `HomeScreen` du kit FlutterShop.
///
/// Le même enchaînement que le kit — offres, catégories, produits
/// populaires, vente flash, bannières, rangées de produits — rempli avec le
/// vrai catalogue. Une règle tient tout l'écran : **aucune remise affichée
/// qui ne soit pas en cours**. Les bannières qui annoncent un pourcentage
/// ne viennent que des promotions réelles ; sans promotion, l'accueil n'en
/// montre pas.
///
/// La barre du haut (nom, recherche, notifications) et les onglets du bas
/// appartiennent à la coquille, `ClientShell`.
class ClientHomeScreen extends ConsumerWidget {
  const ClientHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogue = ref.watch(homeProductsProvider);

    Future<void> rafraichir() async {
      ref.invalidate(homeProductsProvider);
      ref.invalidate(recommendedFeedProvider);
      await ref
          .read(homeProductsProvider.future)
          .catchError((_) => <Product>[]);
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: rafraichir,
        child: catalogue.when(
          skipLoadingOnReload: true,
          loading: () => const _AccueilEnChargement(),
          error: (error, _) => _Message(
            child: IllustratedMessage(
              illustration: ShopIllustration.serverError,
              title: 'Le catalogue n\'a pas pu être chargé',
              message: messagePourUtilisateur(error),
              action: OutlinedButton(
                onPressed: rafraichir,
                child: const Text('Réessayer'),
              ),
            ),
          ),
          data: (produits) => produits.isEmpty
              ? const _Message(
                  child: IllustratedMessage(
                    illustration: ShopIllustration.emptyState,
                    title: 'Aucun produit pour le moment',
                    message:
                        'Les boutiques ajoutent leurs articles : revenez bientôt.',
                  ),
                )
              : _Accueil(sections: HomeSections(produits)),
        ),
      ),
    );
  }
}

/// Un message plein écran qui reste rafraîchissable d'un geste.
class _Message extends StatelessWidget {
  const _Message({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, contraintes) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(height: contraintes.maxHeight, child: child),
      ),
    );
  }
}

class _Accueil extends ConsumerWidget {
  const _Accueil({required this.sections});

  final HomeSections sections;

  void _ouvrir(BuildContext context, Product produit) =>
      context.push(AppRoutes.productDetail(produit.id));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestions = ref.watch(recommendedFeedProvider).valueOrNull;
    final populaires = sections.popular;
    final flash = sections.flashSale;
    final finFlash = sections.flashSaleEndsAt;
    final promos = sections.onSale;
    final vus = sections.mostViewed;
    final tiers = sections.ofSupplierType(SupplierType.tiers);

    List<ShopProductData> cartes(List<Product> liste) => [
      for (final p in liste) p.shopData(),
    ];

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _OffresEtCategories(promos: promos)),
        SliverToBoxAdapter(
          child: ProductCarouselSection(
            title: 'Produits populaires',
            products: cartes(populaires),
            onTap: (i) => _ouvrir(context, populaires[i]),
          ),
        ),
        if (flash.isNotEmpty && finFlash != null)
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              vertical: ShopSizes.padding * 1.5,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CountdownBanner(
                    image: _photo(flash.first.product),
                    text: 'Vente flash\njusqu\'à -${flash.first.percent} %',
                    endsAt: finFlash,
                    onTap: () => context.push(AppRoutes.clientOnSale),
                  ),
                  const SizedBox(height: ShopSizes.padding / 2),
                  ProductCarouselSection(
                    title: 'Vente flash',
                    products: cartes([for (final p in flash) p.product]),
                    onTap: (i) => _ouvrir(context, flash[i].product),
                  ),
                ],
              ),
            ),
          ),
        if (promos.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: ShopSizes.padding / 4),
              child: OfferBannerStyle2(
                image: _photo(promos.last.product),
                size: ShopBannerSize.small,
                title: 'Bons\nplans',
                subtitle: 'Offre spéciale',
                discountPercent: promos.first.percent,
                onTap: () => context.push(AppRoutes.clientOnSale),
              ),
            ),
          ),
        if (suggestions == null || suggestions.isNotEmpty)
          SliverToBoxAdapter(
            child: ProductCarouselSection(
              title: 'Pour vous',
              products: suggestions == null
                  ? null
                  : cartes([for (final s in suggestions) s.product]),
              onTap: (i) => _ouvrir(context, suggestions![i].product),
            ),
          ),
        SliverToBoxAdapter(
          child: ProductCarouselSection(
            title: 'Les plus populaires',
            secondary: true,
            products: cartes(vus),
            onTap: (i) => _ouvrir(context, vus[i]),
          ),
        ),
        if (tiers.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(
                top: ShopSizes.padding * 1.5 + ShopSizes.padding / 4,
                bottom: ShopSizes.padding / 4,
              ),
              child: OfferBannerStyle5(
                image: _photo(tiers.first),
                title: 'Boutiques\ndu Mali',
                subtitle: 'Fournisseurs tiers',
                bottomText: 'VOIR LES BOUTIQUES',
                onTap: () => context.push(AppRoutes.clientShops),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: ProductCarouselSection(
              title: 'Fournisseurs tiers',
              products: cartes(tiers),
              onTap: (i) => _ouvrir(context, tiers[i]),
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: ShopSizes.padding)),
      ],
    );
  }
}

String? _photo(Product produit) =>
    produit.imageUrls.isEmpty ? null : produit.imageUrls.first;

/// Le carrousel d'offres puis les catégories (`OffersCarouselAndCategories`
/// du kit).
class _OffresEtCategories extends ConsumerWidget {
  const _OffresEtCategories({required this.promos});

  final List<PromotedProduct> promos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void ouvrirProduit(Product p) =>
        context.push(AppRoutes.productDetail(p.id));
    void ouvrirCategorie(ProductCategory categorie) {
      unawaited(
        ref.read(recommendationRepositoryProvider).logCategoryOpen(categorie),
      );
      context.push(AppRoutes.catalogueCategory(categorie.name));
    }

    // Les accroches de MTC, sans remise : elles complètent le carrousel
    // jusqu'à quatre offres quand les promotions manquent.
    final accroches = [
      OfferBannerStyle1(
        image: 'assets/images/products/textiles/fabric.jpg',
        text: 'Le meilleur du Mali,\nlivré chez vous',
        onTap: () => context.go(AppRoutes.clientCatalogue),
      ),
      OfferBannerStyle1(
        image: 'assets/images/products/artisanat/mask.jpg',
        text: 'Artisanat authentique,\nfait main',
        onTap: () => ouvrirCategorie(ProductCategory.artisanat),
      ),
      OfferBannerStyle1(
        image: 'assets/images/products/electronique/solar_panel.jpg',
        text: 'MTC Officiel,\nqualité garantie',
        onTap: () => context.go(AppRoutes.clientCatalogue),
      ),
    ];
    String titre(PromotedProduct p) => p.label?.trim().isNotEmpty == true
        ? p.label!.trim()
        : p.product.category.label;
    final offres = <Widget>[
      accroches.first,
      if (promos.isNotEmpty)
        OfferBannerStyle2(
          image: _photo(promos[0].product),
          title: titre(promos[0]),
          subtitle: promos[0].product.supplierName,
          discountPercent: promos[0].percent,
          onTap: () => ouvrirProduit(promos[0].product),
        ),
      if (promos.length > 1)
        OfferBannerStyle3(
          image: _photo(promos[1].product),
          title: titre(promos[1]),
          discountPercent: promos[1].percent,
          onTap: () => ouvrirProduit(promos[1].product),
        ),
      if (promos.length > 2)
        OfferBannerStyle4(
          image: _photo(promos[2].product),
          title: titre(promos[2]),
          subtitle: 'OFFRE SPÉCIALE',
          discountPercent: promos[2].percent,
          onTap: () => ouvrirProduit(promos[2].product),
        ),
    ];
    for (final accroche in accroches.skip(1)) {
      if (offres.length >= 4) break;
      offres.add(accroche);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OffersCarousel(banners: offres),
        const SizedBox(height: ShopSizes.padding / 2),
        const SectionTitle('Catégories'),
        ShopPillRow(
          children: [
            ShopPill(
              label: 'Toutes les catégories',
              active: true,
              onTap: () => context.go(AppRoutes.clientCatalogue),
            ),
            ShopPill(
              label: 'Promotions',
              icon: ShopIcons.sale,
              active: false,
              onTap: () => context.push(AppRoutes.clientOnSale),
            ),
            for (final categorie in ProductCategory.values)
              ShopPill(
                label: categorie.label,
                icon: categorie.shopIcon,
                active: false,
                onTap: () => ouvrirCategorie(categorie),
              ),
          ],
        ),
      ],
    );
  }
}

/// L'accueil pendant le premier chargement : la même mise en page, en
/// silhouettes (« le chargement n'est plus ennuyeux », dit le kit).
class _AccueilEnChargement extends StatelessWidget {
  const _AccueilEnChargement();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const BannerSkeleton(),
        const SizedBox(height: ShopSizes.padding / 2),
        const SectionTitle('Catégories'),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: ShopSizes.padding),
          physics: const NeverScrollableScrollPhysics(),
          child: Row(
            children: [
              for (final largeur in const [140.0, 100.0, 90.0, 110.0])
                Padding(
                  padding: const EdgeInsets.only(right: ShopSizes.padding / 2),
                  child: Skeleton(height: 36, width: largeur, radius: 30),
                ),
            ],
          ),
        ),
        ProductCarouselSection(
          title: 'Produits populaires',
          products: null,
          onTap: (_) {},
        ),
        ProductCarouselSection(
          title: 'Les plus populaires',
          secondary: true,
          products: null,
          onTap: (_) {},
        ),
      ],
    );
  }
}
