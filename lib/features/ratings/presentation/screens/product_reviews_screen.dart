import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/core/error/user_message.dart';
import 'package:mtc_app/core/shop/shop.dart';
import 'package:mtc_app/core/utils/date_formatter.dart';
import 'package:mtc_app/features/orders/domain/entities/order_status.dart';
import 'package:mtc_app/features/orders/presentation/providers/order_providers.dart';

import '../../domain/entities/product_review.dart';
import '../../domain/entities/review_sort.dart';
import '../providers/review_providers.dart';
import '../widgets/review_comment_sheet.dart';
import '../widgets/review_media.dart';

/// Les avis d'un produit (maquette « Reviews » du kit) : le résumé en
/// barres, « Donner mon avis », puis les avis des acheteurs, triés au
/// choix et chargés par pages.
///
/// Un avis porte sur une commande chez un vendeur, pas sur l'article seul :
/// il apparaît ici parce que la commande contenait ce produit.
class ProductReviewsScreen extends ConsumerStatefulWidget {
  const ProductReviewsScreen({super.key, required this.productId});

  final String productId;

  @override
  ConsumerState<ProductReviewsScreen> createState() =>
      _ProductReviewsScreenState();
}

class _ProductReviewsScreenState extends ConsumerState<ProductReviewsScreen> {
  ReviewSort _tri = ReviewSort.recent;
  int _pages = 1;

  Future<void> _choisirLeTri() async {
    final choix = await showShopSheet<ReviewSort>(
      context,
      heightFactor: 0.5,
      child: _ChoixDuTri(actuel: _tri),
    );
    if (choix == null || choix == _tri || !mounted) return;
    setState(() {
      _tri = choix;
      _pages = 1;
    });
  }

  /// Un avis se laisse sur une commande livrée : on ouvre la plus récente
  /// qui contenait ce produit, ou l'on dit pourquoi il n'y en a pas.
  Future<void> _donnerMonAvis() async {
    final messager = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      final commandes = await ref.read(ordersForUserProvider.future);
      final livree = commandes
          .where(
            (commande) => commande.supplierGroups.any(
              (groupe) =>
                  groupe.status == OrderStatus.delivered &&
                  groupe.items.any((i) => i.productId == widget.productId),
            ),
          )
          .sortedBy((commande) => commande.placedAt)
          .lastOrNull;
      if (livree == null) {
        messager.showSnackBar(
          const SnackBar(
            content: Text(
              'Vous pourrez donner votre avis une fois ce produit livré.',
            ),
          ),
        );
        return;
      }
      // La part de la boutique qui a livré ce produit : c'est elle qu'on
      // note, pas la première part de la commande.
      final groupe = livree.supplierGroups.firstWhere(
        (g) =>
            g.status == OrderStatus.delivered &&
            g.items.any((i) => i.productId == widget.productId),
      );
      await router.push(AppRoutes.orderReview(livree.id, groupId: groupe.id));
    } catch (erreur) {
      messager.showSnackBar(
        SnackBar(
          content: Text(
            messagePourUtilisateur(
              erreur,
              repli: 'Vos commandes n\'ont pas pu être chargées.',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.productId;
    final resume = ref.watch(productReviewSummaryProvider(id)).valueOrNull;
    final repartition = ref
        .watch(productRatingDistributionProvider(id))
        .valueOrNull;
    final pages = [
      for (var page = 0; page < _pages; page++)
        ref.watch(
          productReviewsPageProvider((productId: id, sort: _tri, page: page)),
        ),
    ];
    final avis = [for (final page in pages) ...?page.valueOrNull];
    final derniere = pages.last;
    final encore =
        derniere.valueOrNull?.length == reviewsPageSize && !derniere.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Avis')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          ShopSizes.screenMargin,
          ShopSizes.padding,
          ShopSizes.screenMargin,
          ShopSizes.screenMargin,
        ),
        children: [
          if (resume != null && resume.reviewCount > 0) ...[
            RatingSummaryCard(
              rating: resume.ratingAverage,
              reviewCount: resume.reviewCount,
              countsByStar: [
                for (var etoiles = 5; etoiles >= 1; etoiles--)
                  repartition?[etoiles] ?? 0,
              ],
            ),
            const SizedBox(height: ShopSizes.padding),
          ],
          ChevronListTile(
            title: 'Donner mon avis',
            icon: ShopIcons.chatAdd,
            fontSize: 16,
            dividerAbove: true,
            contentPadding: EdgeInsets.zero,
            onTap: _donnerMonAvis,
          ),
          const SizedBox(height: ShopSizes.padding * 2.5),
          SectionTitle(
            'Avis clients',
            padding: EdgeInsets.zero,
            trailing: ShopSortButton(label: _tri.label, onTap: _choisirLeTri),
          ),
          const SizedBox(height: ShopSizes.padding * 1.5),
          if (pages.first.hasError && avis.isEmpty)
            IllustratedMessage(
              illustration: ShopIllustration.serverError,
              title: 'Les avis n\'ont pas pu être chargés',
              message: messagePourUtilisateur(pages.first.error),
              compact: true,
              action: OutlinedButton(
                onPressed: () => ref.invalidate(productReviewsPageProvider),
                child: const Text('Réessayer'),
              ),
            )
          else if (pages.first.isLoading && avis.isEmpty)
            for (var i = 0; i < 3; i++) ...[
              const Skeleton(height: 140),
              const SizedBox(height: ShopSizes.padding),
            ]
          else if (avis.isEmpty)
            const IllustratedMessage(
              illustration: ShopIllustration.emptyState,
              title: 'Aucun avis pour l\'instant',
              message:
                  'Les acheteurs de ce produit pourront en laisser un après '
                  'la livraison.',
              compact: true,
            )
          else ...[
            for (final un in avis) ...[
              _AvisAcheteur(avis: un),
              const SizedBox(height: ShopSizes.padding),
            ],
            if (derniere.isLoading)
              const Skeleton(height: 140)
            else if (derniere.hasError)
              TextButton(
                onPressed: () => ref.invalidate(
                  productReviewsPageProvider((
                    productId: id,
                    sort: _tri,
                    page: _pages - 1,
                  )),
                ),
                child: const Text('Réessayer de charger la suite'),
              )
            else if (encore)
              OutlinedButton(
                onPressed: () => setState(() => _pages++),
                child: const Text('Voir plus d\'avis'),
              ),
          ],
        ],
      ),
    );
  }
}

/// Un avis : le nom, la note et le texte du kit, puis ce que MTC y ajoute —
/// les photos de l'acheteur, la réponse du vendeur, les commentaires.
class _AvisAcheteur extends StatelessWidget {
  const _AvisAcheteur({required this.avis});

  final ProductReview avis;

  @override
  Widget build(BuildContext context) {
    final aMedia = avis.imagePaths.isNotEmpty || avis.videoPath != null;
    return ReviewTile(
      author: avis.authorName,
      timeAgo: DateFormatter.relative(avis.createdAt),
      rating: avis.stars.toDouble(),
      title: avis.title,
      comment: avis.comment,
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (aMedia)
            MediaStrip(
              imagePaths: avis.imagePaths,
              videoPath: avis.videoPath,
              thumbnailSize: 64,
            ),
          if (avis.supplierReply case final reponse?) ...[
            const SizedBox(height: ShopSizes.padding / 2),
            SellerReply(text: reponse),
          ],
          for (final commentaire in avis.comments)
            _Commentaire(commentaire: commentaire),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                // La famille aussi : un `textStyle` de bouton remplace celui
                // du thème au lieu de s'y fondre.
                textStyle: const TextStyle(
                  fontFamily: ShopTheme.fontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onPressed: () =>
                  showReviewCommentSheet(context, reviewId: avis.id),
              icon: const ShopIcon(
                ShopIcons.chat,
                size: 18,
                color: ShopColors.primary,
              ),
              label: const Text('Commenter'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Un commentaire sous l'avis : la question d'un autre client, ou la
/// précision du vendeur, signalée comme telle.
class _Commentaire extends StatelessWidget {
  const _Commentaire({required this.commentaire});

  final ReviewComment commentaire;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vendeur = commentaire.authorIsSupplier;
    return Padding(
      padding: const EdgeInsets.only(top: ShopSizes.padding / 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShopIcon(
            vendeur ? ShopIcons.stores : ShopIcons.profile,
            size: 16,
            color: vendeur ? ShopColors.primary : null,
          ),
          const SizedBox(width: ShopSizes.padding / 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    text: commentaire.authorName,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                    children: [
                      if (vendeur)
                        const TextSpan(
                          text: ' · vendeur',
                          style: TextStyle(color: ShopColors.primary),
                        ),
                      TextSpan(
                        text:
                            '  ${DateFormatter.relative(commentaire.createdAt)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  commentaire.body,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    height: 1.4,
                  ),
                ),
                MediaStrip(
                  imagePaths: commentaire.imagePaths,
                  videoPath: commentaire.videoPath,
                  thumbnailSize: 56,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Le choix du tri, en feuille (la feuille « Trier par » du kit).
class _ChoixDuTri extends StatelessWidget {
  const _ChoixDuTri({required this.actuel});

  final ReviewSort actuel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SheetHeader(title: 'Trier les avis'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: ShopSizes.screenMargin,
            ),
            children: [
              for (final tri in ReviewSort.values)
                ShopRadioTile<ReviewSort>(
                  title: tri.label,
                  value: tri,
                  groupValue: actuel,
                  onChanged: (choix) => Navigator.of(context).pop(choix),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
