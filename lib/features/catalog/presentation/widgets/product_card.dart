import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/app/theme/app_shadows.dart';
import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/utils/currency_formatter.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';
import 'package:mtc_app/core/widgets/resolved_image.dart';
import 'package:mtc_app/features/cart/presentation/controllers/cart_controller.dart';
import 'package:mtc_app/features/cart/presentation/providers/cart_providers.dart';

import '../../domain/entities/product.dart';
import '../../domain/entities/promotion.dart';
import '../../domain/promotion_pricing.dart';
import 'promotion_badge.dart';
import '../../domain/entities/product_category.dart';

extension ProductCategoryIcon on ProductCategory {
  IconData get icon => switch (this) {
    ProductCategory.textilesBogolan => Icons.checkroom_rounded,
    ProductCategory.artisanat => Icons.brush_rounded,
    ProductCategory.electronique => Icons.devices_rounded,
    ProductCategory.alimentation => Icons.rice_bowl_rounded,
    ProductCategory.materiauxConstruction => Icons.construction_rounded,
    ProductCategory.autre => Icons.category_rounded,
  };
}

/// One representative bundled photo per category, used by the Catalogue
/// tab's category tiles (`CatalogueScreen`) — `null` for [autre], which has
/// no sample photos of its own, falling back to its tinted icon there.
extension ProductCategoryImage on ProductCategory {
  String? get imageAsset => switch (this) {
    ProductCategory.textilesBogolan => 'assets/images/products/textiles/fabric.jpg',
    ProductCategory.artisanat => 'assets/images/products/artisanat/mask.jpg',
    ProductCategory.electronique =>
      'assets/images/products/electronique/smartphone.jpg',
    ProductCategory.alimentation => 'assets/images/products/alimentation/rice.jpg',
    ProductCategory.materiauxConstruction =>
      'assets/images/products/materiaux/steel.jpg',
    ProductCategory.autre => null,
  };
}

class ProductCard extends ConsumerWidget {
  const ProductCard({
    super.key,
    required this.product,
    this.overlay,
    this.onOpened,
  });

  final Product product;

  /// Optional widget pinned to the image's top-right corner — e.g. a
  /// favorite-toggle heart. Kept as an injected slot (rather than importing
  /// the favorites feature directly) so this shared widget stays
  /// feature-agnostic; the composing screen decides what to overlay.
  final Widget? overlay;

  /// Notifié quand la carte est ouverte — **en plus** de la navigation, et
  /// non à sa place.
  ///
  /// Sert à la recherche par photo : ouvrir un résultat est l'étiquette du
  /// jeu d'entraînement (`0086`), et c'est le seul endroit où ce geste est
  /// observable. Un rappel plutôt qu'un appel direct à la fonctionnalité
  /// pour la même raison que `overlay` : ce widget est partagé et ne doit
  /// rien connaître de qui l'affiche.
  final VoidCallback? onOpened;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final brightness = Theme.of(context).brightness;
    final titleStyle = textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
    );
    // Fixed to exactly 2 lines' worth of height regardless of how long the
    // name actually is — otherwise a one-line title leaves the text block
    // shorter than a two-line one, and since the photo above sits in an
    // Expanded absorbing the leftover space, that made images different
    // heights from card to card in the same row/grid.
    final titleHeight = (titleStyle?.fontSize ?? 14) * (titleStyle?.height ?? 1.3) * 2;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        boxShadow: AppShadows.soft(brightness),
      ),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            onOpened?.call();
            context.push(AppRoutes.productDetail(product.id));
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Expanded (not a fixed AspectRatio) so the photo absorbs
              // whatever height the grid cell has left over after the text
              // block below — otherwise a short name/no-variant card leaves
              // dead space at the bottom instead of a taller image.
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _CardImage(product: product),
                    if (overlay != null)
                      Positioned(top: 0, right: 0, child: overlay!),
                    // En haut à gauche : le coin droit est déjà pris par les
                    // surcouches d'état (rupture, statut) et le bas droit par
                    // l'ajout rapide.
                    if (_runningPromotion(product) case final promotion?)
                      Positioned(
                        top: AppSpacing.xs,
                        left: AppSpacing.xs,
                        child: PromotionBadge(
                          promotion: promotion,
                          compact: true,
                        ),
                      ),
                    if (product.stockQuantity > 0)
                      Positioned(
                        bottom: AppSpacing.xs,
                        right: AppSpacing.xs,
                        child: _QuickAddToCartButton(product: product),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: titleHeight,
                      child: Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: titleStyle,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          product.ratingAverage.toStringAsFixed(1),
                          style: textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            product.supplierName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _PriceLine(product: product, textTheme: textTheme, scheme: scheme),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// La remise à annoncer sur la vignette, s'il y en a une.
///
/// Prend la meilleure remise **en cours**, conditions de quantité comprises
/// : une vignette doit annoncer un « dès 10 pièces » (c'est ce qui donne
/// envie d'ouvrir la fiche), là où le prix affiché, lui, reste celui d'une
/// unité.
Promotion? _runningPromotion(Product product) {
  Promotion? best;
  for (final promotion in product.promotions) {
    if (!promotion.isRunningAt()) continue;
    final price = priceUnderPromotion(
      basePriceFcfa: product.priceFcfa,
      promotion: promotion,
    );
    if (price >= product.priceFcfa) continue;
    if (best == null ||
        price <
            priceUnderPromotion(
              basePriceFcfa: product.priceFcfa,
              promotion: best,
            )) {
      best = promotion;
    }
  }
  return best;
}

/// The price row on a catalog card — a plain [CurrencyText] for a
/// variant-less product or one whose variants all share the same price,
/// "À partir de X FCFA" when they don't (both `priceFcfa`/`maxPriceFcfa`
/// are trigger-maintained aggregates, see `0018_product_variants.sql`, so
/// this never needs to fetch the variant list itself).
class _PriceLine extends StatelessWidget {
  const _PriceLine({
    required this.product,
    required this.textTheme,
    required this.scheme,
  });

  final Product product;
  final TextTheme textTheme;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final style = textTheme.titleSmall?.copyWith(
      color: scheme.primary,
      fontWeight: FontWeight.w700,
    );
    final maxPrice = product.maxPriceFcfa;
    if (product.hasVariants && maxPrice != null && maxPrice != product.priceFcfa) {
      return Text('À partir de ${CurrencyFormatter.formatFcfa(product.priceFcfa)}', style: style);
    }

    // La vignette montre le prix pour **une** unité : une remise « dès 10 »
    // ne s'affiche donc pas ici, sinon le prix annoncé ne serait pas celui
    // qu'un client obtient en ajoutant l'article.
    final promotion = bestPromotionFor(
      promotions: product.promotions,
      basePriceFcfa: product.priceFcfa,
      quantity: 1,
    );
    if (promotion == null) {
      return CurrencyText(
        product.priceFcfa,
        compareAtAmountFcfa: product.compareAtPriceFcfa,
        style: style,
      );
    }
    return CurrencyText(
      priceUnderPromotion(
        basePriceFcfa: product.priceFcfa,
        promotion: promotion,
      ),
      compareAtAmountFcfa: product.priceFcfa,
      style: style,
    );
  }
}

/// One-tap "add to cart" pinned to the image's bottom-right corner — mirrors
/// the reference marketplace mockup's small purple cart button on every
/// product card, so a client can stock up while browsing without opening
/// each product's detail page.
class _QuickAddToCartButton extends ConsumerWidget {
  const _QuickAddToCartButton({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    // Already-in-cart state flips the button to a white pill with a blue
    // (primary-colored) cart icon, instead of the solid purple "add" look —
    // and turns the tap into a toggle-off (remove) instead of add-again.
    final cartItem = ref.watch(cartItemForProductProvider(product.id));
    final inCart = cartItem != null;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        boxShadow: AppShadows.soft(brightness),
        border: inCart ? Border.all(color: scheme.primary, width: 1.5) : null,
      ),
      child: Material(
        color: inCart ? scheme.surface : scheme.primary,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          onTap: () {
            final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
            if (cartItem != null) {
              ref.read(cartControllerProvider.notifier).removeItem(cartItem.id);
              messenger.showSnackBar(
                SnackBar(
                  duration: const Duration(seconds: 1),
                  content: Text('${product.name} retiré du panier'),
                ),
              );
            } else {
              ref.read(cartControllerProvider.notifier).addProduct(product);
              messenger.showSnackBar(
                SnackBar(
                  duration: const Duration(seconds: 1),
                  content: Text('${product.name} ajouté au panier'),
                ),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xs),
            child: Icon(
              Icons.shopping_cart_rounded,
              size: 18,
              color: inCart ? scheme.primary : scheme.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// The card's photo slot — a single [ProductImage] when [Product.imageUrls]
/// has 0 or 1 entries, otherwise a `PageView` that auto-advances through
/// all of them every 4s (still swipeable by hand too), so a multi-photo
/// listing gets noticed while just scrolling past instead of only on its
/// detail page. Mirrors `ProductDetailScreen`'s own gallery auto-advance
/// (`_ProductDetailContentState._startIdleAutoScroll`) — same interval,
/// same curve — just without that screen's fullscreen-viewer pause/thumbnail
/// strip, neither of which make sense at card size.
class _CardImage extends StatefulWidget {
  const _CardImage({required this.product});

  final Product product;

  @override
  State<_CardImage> createState() => _CardImageState();
}

class _CardImageState extends State<_CardImage> {
  final _pageController = PageController();
  Timer? _autoScrollTimer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    if (widget.product.imageUrls.length > 1) _startAutoScroll();
  }

  void _startAutoScroll() {
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_pageController.hasClients) return;
      final next = (_page + 1) % widget.product.imageUrls.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.product.imageUrls;
    if (images.length <= 1) {
      return ProductImage(
        imageUrl: images.isEmpty ? null : images.first,
        icon: widget.product.category.icon,
      );
    }
    return PageView.builder(
      controller: _pageController,
      itemCount: images.length,
      onPageChanged: (index) => _page = index,
      itemBuilder: (context, index) => ProductImage(
        imageUrl: images[index],
        icon: widget.product.category.icon,
      ),
    );
  }
}

/// Shows the product's first photo, falling back to a tinted category icon
/// when no asset is available or the asset fails to load (kept resilient
/// since [Product.imageUrls] is allowed to be empty in the data model).
class ProductImage extends StatelessWidget {
  const ProductImage({super.key, required this.imageUrl, required this.icon});

  final String? imageUrl;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (imageUrl == null) {
      return _fallback(scheme);
    }

    // Grid/list thumbnail, never shown larger than a couple hundred logical
    // pixels wide — decoding at that size instead of whatever resolution
    // the source photo actually is avoids allocating a full-size bitmap for
    // every card, on every scroll, across every catalog/search/favorites
    // grid in the app (the single most-rendered image widget here).
    return ResolvedImage(
      path: imageUrl!,
      bucket: 'product-images',
      errorBuilder: (context, error, stackTrace) => _fallback(scheme),
      cacheWidth: 400,
    );
  }

  Widget _fallback(ColorScheme scheme) {
    return Container(
      color: scheme.primaryContainer.withValues(alpha: 0.4),
      child: Icon(icon, size: 40, color: scheme.primary),
    );
  }
}
