import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/core/error/user_message.dart';
import 'package:mtc_app/core/shop/shop.dart';
import 'package:mtc_app/features/chat/presentation/open_shop_conversation.dart';
import 'package:mtc_app/features/chat/presentation/screens/chat_thread_screen.dart'
    show ChatProductAttachment;
import 'package:mtc_app/features/comments/presentation/providers/comment_providers.dart';
import 'package:mtc_app/features/comments/presentation/widgets/product_comments_modal.dart';
import 'package:mtc_app/features/favorites/presentation/widgets/bookmark_button.dart';
import 'package:mtc_app/features/ratings/presentation/providers/review_providers.dart';
import 'package:mtc_app/features/recommendations/presentation/providers/recommendation_providers.dart';

import '../../domain/entities/product.dart';
import '../../domain/entities/product_variant.dart';
import '../providers/catalog_providers.dart';
import '../providers/product_selection.dart';
import '../widgets/fullscreen_image_viewer.dart';
import '../widgets/product_buy_sheet.dart';
import '../widgets/product_info_sheets.dart';
import '../widgets/shop_product_data.dart';
import '../widgets/variant_video_player.dart';

/// Ouvre (ou reprend) la conversation avec le fournisseur, l'article — et
/// la variante choisie — en pièce jointe en attente
/// (`ChatThreadScreen.initialAttachment`) : le prochain message porte le
/// nom, le prix et la photo exacts.
Future<void> _contacterLaBoutique(
  BuildContext context,
  WidgetRef ref,
  Product product,
  ProductVariant? variante,
) => openShopConversation(
  context,
  ref,
  supplierId: product.supplierId,
  supplierName: product.supplierName,
  attachment: ChatProductAttachment(product: product, variant: variante),
);

/// La fiche produit du client, d'après `ProductDetailsScreen` du kit :
/// la galerie, la marque et le nom, la disponibilité et la note, puis les
/// rubriques (détails, livraison, boutique, questions), le résumé des avis
/// et « Vous aimerez aussi ». Le prix et l'achat sont dans la barre du bas,
/// qui ouvre la feuille d'achat.
class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final String productId;

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Une fois par visite, pas à chaque reconstruction, et sans attendre le
    // produit : le compteur n'en a pas besoin. Sans attendre non plus le
    // résultat — un compteur raté ne doit ni bloquer ni casser la fiche.
    unawaited(
      ref.read(productRepositoryProvider).incrementViewCount(widget.productId),
    );
    // Le compteur ci-dessus dit combien de fois le produit a été vu ; cette
    // trace dit *par qui*, pour le fil « Pour vous » (`0081`).
    unawaited(
      ref
          .read(recommendationRepositoryProvider)
          .logProductView(widget.productId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final produit = ref.watch(productDetailProvider(widget.productId));

    return produit.when(
      data: (product) => _Fiche(product: product),
      loading: () => const _FicheEnChargement(),
      error: (erreur, _) => Scaffold(
        appBar: AppBar(),
        body: IllustratedMessage(
          illustration: ShopIllustration.serverError,
          title: 'Ce produit n\'a pas pu être chargé',
          message: messagePourUtilisateur(erreur),
          action: OutlinedButton(
            onPressed: () =>
                ref.invalidate(productDetailProvider(widget.productId)),
            child: const Text('Réessayer'),
          ),
        ),
      ),
    );
  }
}

class _Fiche extends ConsumerStatefulWidget {
  const _Fiche({required this.product});

  final Product product;

  @override
  ConsumerState<_Fiche> createState() => _FicheState();
}

class _FicheState extends ConsumerState<_Fiche> {
  @override
  void initState() {
    super.initState();
    final parDefaut = defaultVariantOf(widget.product);
    if (parDefaut != null) {
      // Riverpod interdit d'écrire un provider pendant la construction de
      // l'arbre : juste après cette image, comme le conseille son message.
      Future(() {
        if (!mounted) return;
        final id = widget.product.id;
        ref.read(productVariantIdProvider(id).notifier).state = parDefaut.id;
        ref.read(productPicksProvider(id).notifier).state = derivePicks(
          parDefaut,
          const {},
        );
      });
    }
  }

  void _pleinEcran(List<String> photos, int depuis) {
    if (photos.isEmpty) return;
    showFullscreenImageViewer(context, images: photos, initialIndex: depuis);
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final id = product.id;

    ref.listen(productVariantIdProvider(id), (avant, apres) {
      if (avant == apres) return;
      // Une quantité choisie sur le stock de l'ancienne variante peut
      // dépasser celui de la nouvelle : on repart de 1 plutôt que de la
      // rogner sans le dire.
      ref.read(productQuantityProvider(id).notifier).state = 1;
      final variante = product.variants.firstWhereOrNull((v) => v.id == apres);
      if (variante != null) {
        ref.read(productPicksProvider(id).notifier).state = derivePicks(
          variante,
          ref.read(productPicksProvider(id)),
        );
      }
    });

    final variantId = ref.watch(productVariantIdProvider(id));
    final picks = ref.watch(productPicksProvider(id));
    final variante = product.variants.firstWhereOrNull(
      (v) => v.id == variantId,
    );
    final aEnvoyer = variante == null
        ? null
        : resolveVariantForPurchase(variante, picks, product.characteristics);
    // Les photos de la variante choisie quand elle en a, celles du produit
    // sinon.
    final photos = variante != null && variante.imageUrls.isNotEmpty
        ? variante.imageUrls
        : product.imageUrls;
    final prix = product.unitPricing(basePriceFcfa: variante?.priceFcfa);
    final resume = ref.watch(productReviewSummaryProvider(id)).valueOrNull;
    final enStock = product.stockQuantity > 0;

    return Scaffold(
      bottomNavigationBar: enStock
          ? CartButton(
              priceFcfa: prix.priceFcfa,
              title: 'Acheter',
              onPressed: () => showProductBuySheet(context, product),
            )
          : NoticeCard(
              icon: ShopIcons.chat,
              text: 'En rupture de stock. Demandez à la boutique quand il '
                  'revient.',
              trailing: const ShopIcon(ShopIcons.miniRight),
              onTap: () =>
                  _contacterLaBoutique(context, ref, product, aEnvoyer),
            ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              floating: true,
              actions: [
                BookmarkButton(productId: id),
                const SizedBox(width: ShopSizes.padding / 2),
              ],
            ),
            SliverToBoxAdapter(
              // Une autre variante, une autre série de photos : la galerie
              // repart de la première.
              child: KeyedSubtree(
                key: ValueKey(variantId),
                child: ShopProductGallery(
                  images: photos,
                  onTap: (index) => _pleinEcran(photos, index),
                  overlay: _Pastilles(
                    percent: prix.percent,
                    videoPath: variante?.videoPath,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: ShopProductInfo(
                brand: product.supplierName,
                title: product.name,
                availability: AvailabilityTag(
                  isAvailable: enStock,
                  label: enStock ? 'En stock' : 'Rupture de stock',
                ),
                rating: resume?.ratingAverage ?? 0,
                reviewCount: resume?.reviewCount ?? 0,
                description: product.description,
              ),
            ),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  ChevronListTile(
                    title: 'Détails du produit',
                    icon: ShopIcons.product,
                    fontSize: 16,
                    dividerAbove: true,
                    showDivider: false,
                    onTap: () => showProductDetailsSheet(context, product),
                  ),
                  ChevronListTile(
                    title: 'Livraison',
                    icon: ShopIcons.delivery,
                    fontSize: 16,
                    dividerAbove: true,
                    showDivider: false,
                    onTap: () => showDeliveryMethodsSheet(context, product),
                  ),
                  ChevronListTile(
                    title: product.supplierName,
                    icon: ShopIcons.stores,
                    fontSize: 16,
                    trailingText: 'Boutique',
                    dividerAbove: true,
                    showDivider: false,
                    onTap: () => context.push(
                      AppRoutes.supplierProfile(product.supplierId),
                    ),
                  ),
                  ChevronListTile(
                    title: 'Poser une question à la boutique',
                    icon: ShopIcons.chat,
                    fontSize: 16,
                    dividerAbove: true,
                    showDivider: false,
                    onTap: () =>
                        _contacterLaBoutique(context, ref, product, aEnvoyer),
                  ),
                  _LigneCommentaires(productId: id),
                ],
              ),
            ),
            SliverToBoxAdapter(child: _ResumeDesAvis(productId: id)),
            SliverToBoxAdapter(
              child: ChevronListTile(
                title: 'Avis',
                icon: ShopIcons.chat,
                fontSize: 16,
                trailingText: (resume?.reviewCount ?? 0) > 0
                    ? '${resume!.reviewCount}'
                    : null,
                dividerAbove: true,
                onTap: () => context.push(AppRoutes.productReviews(id)),
              ),
            ),
            SliverToBoxAdapter(child: _Similaires(product: product)),
            const SliverToBoxAdapter(
              child: SizedBox(height: ShopSizes.padding),
            ),
          ],
        ),
      ),
    );
  }
}

/// En haut à gauche de la galerie : la remise en cours pour une unité, et
/// la vidéo de la variante choisie, qui reste là où l'on regarde les
/// photos plutôt que d'être une page de plus du carrousel.
class _Pastilles extends StatelessWidget {
  const _Pastilles({required this.percent, required this.videoPath});

  final int? percent;
  final String? videoPath;

  @override
  Widget build(BuildContext context) {
    final video = videoPath;
    if (percent == null && video == null) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (percent != null) DiscountBadge(percent!),
        if (percent != null && video != null)
          const SizedBox(width: ShopSizes.padding / 2),
        if (video != null)
          Material(
            color: Colors.black.withValues(alpha: 0.55),
            shape: const StadiumBorder(),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: () => showVariantVideo(context, video),
              child: const Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: ShopSizes.padding * 0.75,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Vidéo',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Les questions publiques sur l'article, avec leur nombre : une raison
/// de toucher la ligne avant même d'y lire une réponse.
class _LigneCommentaires extends ConsumerWidget {
  const _LigneCommentaires({required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nombre =
        ref.watch(productCommentsProvider(productId)).valueOrNull?.length ?? 0;
    return ChevronListTile(
      title: 'Commentaires',
      icon: ShopIcons.faq,
      fontSize: 16,
      trailingText: nombre > 0 ? '$nombre' : null,
      dividerAbove: true,
      onTap: () => showProductCommentsModal(context, productId: productId),
    );
  }
}

/// Le résumé des avis (`ReviewCard` du kit) : la moyenne et la répartition
/// par note, comptées en base sur tous les avis du produit.
class _ResumeDesAvis extends ConsumerWidget {
  const _ResumeDesAvis({required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resume = ref
        .watch(productReviewSummaryProvider(productId))
        .valueOrNull;
    // Une fiche reste lisible quand ses avis ne chargent pas : rien plutôt
    // qu'une erreur à la place du produit.
    if (resume == null) return const SizedBox(height: ShopSizes.padding);
    if (resume.reviewCount == 0) {
      return const Padding(
        padding: EdgeInsets.all(ShopSizes.padding),
        child: Text(
          'Aucun avis pour l\'instant. Les acheteurs de ce produit pourront '
          'en laisser un après la livraison.',
          style: TextStyle(height: 1.4),
        ),
      );
    }
    final repartition = ref
        .watch(productRatingDistributionProvider(productId))
        .valueOrNull;
    return Padding(
      padding: const EdgeInsets.all(ShopSizes.padding),
      child: RatingSummaryCard(
        rating: resume.ratingAverage,
        reviewCount: resume.reviewCount,
        countsByStar: [
          for (var etoiles = 5; etoiles >= 1; etoiles--)
            repartition?[etoiles] ?? 0,
        ],
      ),
    );
  }
}

/// « Vous aimerez aussi » : la même catégorie, du même côté du catalogue.
class _Similaires extends ConsumerWidget {
  const _Similaires({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final similaires = ref.watch(similarProductsProvider(product));
    if (similaires.hasError) return const SizedBox.shrink();
    final liste = similaires.valueOrNull;
    if (liste != null && liste.isEmpty) return const SizedBox.shrink();
    return ProductCarouselSection(
      title: 'Vous aimerez aussi',
      products: liste?.map((p) => p.shopData()).toList(),
      onTap: (index) =>
          context.push(AppRoutes.productDetail(liste![index].id)),
    );
  }
}

/// La fiche pendant son chargement : les silhouettes de la galerie et des
/// textes, à leur place.
class _FicheEnChargement extends StatelessWidget {
  const _FicheEnChargement();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: ShopSizes.padding),
        children: const [
          AspectRatio(
            aspectRatio: 1,
            child: Skeleton(radius: ShopSizes.radius * 2),
          ),
          SizedBox(height: ShopSizes.padding),
          Skeleton(height: 12, width: 100),
          SizedBox(height: ShopSizes.padding / 2),
          Skeleton(height: 24, width: 240),
          SizedBox(height: ShopSizes.padding),
          Skeleton(height: 28, width: 120),
          SizedBox(height: ShopSizes.padding),
          Skeleton(height: 12),
          SizedBox(height: ShopSizes.padding / 2),
          Skeleton(height: 12),
        ],
      ),
    );
  }
}
