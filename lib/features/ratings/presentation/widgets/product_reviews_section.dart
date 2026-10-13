import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/core/storage/media_picker.dart';
import 'package:mtc_app/core/utils/date_formatter.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';
import 'package:mtc_app/core/widgets/resolved_image.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/catalog/presentation/widgets/fullscreen_image_viewer.dart';
import 'package:mtc_app/features/catalog/presentation/widgets/variant_video_player.dart';

import '../../domain/entities/product_review.dart';
import '../controllers/review_comment_controller.dart';
import '../providers/review_providers.dart';

/// Le bucket des médias d'avis (`0061`), public en lecture comme les avis
/// qu'ils accompagnent.
const _bucket = 'review-media';

/// Les avis des acheteurs, sur la fiche produit.
///
/// Un avis porte sur une commande chez un vendeur et non sur un article :
/// il s'affiche ici parce que la commande contenait ce produit. Le titre le
/// dit — « acheteurs de ce produit » — plutôt que de laisser croire à une
/// note article par article qui n'existe pas.
///
/// Deux avis au plus dans la page, le reste derrière un bouton : une fiche
/// produit qui s'allonge de vingt avis n'est plus une fiche produit.
class ProductReviewsSection extends ConsumerWidget {
  const ProductReviewsSection({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(productReviewSummaryProvider(productId));
    final reviewsAsync = ref.watch(productReviewsProvider(productId));
    final scheme = Theme.of(context).colorScheme;
    final count = summary.valueOrNull?.reviewCount ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.rate_review_outlined, color: scheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Avis des acheteurs',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (count > 0)
              MtcRatingStars(
                rating: summary.valueOrNull?.ratingAverage ?? 0,
                ratingCount: count,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        reviewsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Center(child: CircularProgressIndicator()),
          ),
          // Une fiche produit reste consultable même si ses avis ne
          // chargent pas : on n'y remplace pas le produit par une erreur.
          error: (_, _) => Text(
            'Les avis n\'ont pas pu être chargés.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          data: (reviews) {
            if (reviews.isEmpty) {
              return Text(
                'Aucun avis pour l\'instant. Les acheteurs de ce produit '
                'pourront en laisser un après livraison.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final review in reviews.take(2))
                  ReviewCard(review: review, productId: productId),
                if (reviews.length > 2)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () =>
                          showProductReviewsModal(context, productId: productId),
                      icon: const Icon(Icons.expand_more_rounded),
                      label: Text('Voir les ${reviews.length} avis'),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Tous les avis, en plein écran.
Future<void> showProductReviewsModal(
  BuildContext context, {
  required String productId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      builder: (context, controller) =>
          _AllReviews(productId: productId, scrollController: controller),
    ),
  );
}

class _AllReviews extends ConsumerWidget {
  const _AllReviews({required this.productId, required this.scrollController});

  final String productId;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(productReviewsProvider(productId));

    return AsyncValueWidget(
      value: reviewsAsync,
      data: (reviews) => ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: reviews.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Text(
                'Avis des acheteurs',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            );
          }
          return ReviewCard(
            review: reviews[index - 1],
            productId: productId,
          );
        },
      ),
    );
  }
}

/// Un avis : la note, le mot de l'acheteur, ses photos, la réponse du
/// vendeur, et les commentaires.
class ReviewCard extends ConsumerWidget {
  const ReviewCard({
    super.key,
    required this.review,
    required this.productId,
  });

  final ProductReview review;
  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    // Un visiteur sans compte lit les avis mais n'y répond pas : afficher le
    // bouton l'enverrait vers un refus.
    final isSignedIn = ref.watch(currentUserProvider).valueOrNull != null;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                MtcRatingStars(
                  rating: review.stars.toDouble(),
                  showValue: false,
                  asStars: true,
                  size: 15,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    review.authorName,
                    style: theme.textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  DateFormatter.formatDate(review.createdAt),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            if (review.comment.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(review.comment),
            ],
            MediaStrip(
              imagePaths: review.imagePaths,
              videoPath: review.videoPath,
            ),
            if (review.supplierReply != null) ...[
              const SizedBox(height: AppSpacing.sm),
              _SupplierReply(reply: review.supplierReply!),
            ],
            for (final comment in review.comments)
              _CommentTile(comment: comment, productId: productId),
            if (isSignedIn)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => showReviewCommentSheet(
                    context,
                    reviewId: review.id,
                    productId: productId,
                  ),
                  icon: const Icon(Icons.add_comment_outlined, size: 18),
                  label: const Text('Commenter'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// La réponse publique du vendeur à l'avis, visuellement rattachée à lui.
class _SupplierReply extends StatelessWidget {
  const _SupplierReply({required this.reply});

  final String reply;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Réponse du vendeur',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(reply),
        ],
      ),
    );
  }
}

class _CommentTile extends ConsumerWidget {
  const _CommentTile({required this.comment, required this.productId});

  final ReviewComment comment;
  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, left: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                comment.authorIsSupplier
                    ? Icons.storefront_rounded
                    : Icons.person_outline_rounded,
                size: 15,
                color: comment.authorIsSupplier
                    ? scheme.primary
                    : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  comment.authorName,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (comment.authorIsSupplier) ...[
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '· vendeur',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.primary,
                  ),
                ),
              ],
              const SizedBox(width: AppSpacing.sm),
              Text(
                DateFormatter.relative(comment.createdAt),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 19),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(comment.body),
                MediaStrip(
                  imagePaths: comment.imagePaths,
                  videoPath: comment.videoPath,
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

/// Bande de vignettes : photos cliquables, vidéo jouable.
///
/// Les chemins Storage ne sont jamais persistés en URL — ils sont résolus à
/// l'affichage, comme partout ailleurs (`ResolvedImage`).
class MediaStrip extends StatelessWidget {
  const MediaStrip({
    super.key,
    required this.imagePaths,
    this.videoPath,
    this.thumbnailSize = 72,
  });

  final List<String> imagePaths;
  final String? videoPath;
  final double thumbnailSize;

  @override
  Widget build(BuildContext context) {
    if (imagePaths.isEmpty && videoPath == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: SizedBox(
        height: thumbnailSize,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (var i = 0; i < imagePaths.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: GestureDetector(
                  onTap: () => showFullscreenImageViewer(
                    context,
                    images: imagePaths,
                    initialIndex: i,
                    bucket: _bucket,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    child: SizedBox(
                      width: thumbnailSize,
                      height: thumbnailSize,
                      child: ResolvedImage(
                        path: imagePaths[i],
                        bucket: _bucket,
                        cacheWidth: 200,
                      ),
                    ),
                  ),
                ),
              ),
            if (videoPath != null)
              GestureDetector(
                onTap: () =>
                    showVariantVideo(context, videoPath!, bucket: _bucket),
                child: Container(
                  width: thumbnailSize,
                  height: thumbnailSize,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: const Icon(Icons.play_circle_outline_rounded),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Rédige un commentaire sous un avis, avec ses médias.
Future<void> showReviewCommentSheet(
  BuildContext context, {
  required String reviewId,
  required String productId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
      ),
      child: _CommentComposer(reviewId: reviewId, productId: productId),
    ),
  );
}

class _CommentComposer extends ConsumerStatefulWidget {
  const _CommentComposer({required this.reviewId, required this.productId});

  final String reviewId;
  final String productId;

  @override
  ConsumerState<_CommentComposer> createState() => _CommentComposerState();
}

class _CommentComposerState extends ConsumerState<_CommentComposer> {
  final _body = TextEditingController();
  final _images = <String>[];
  String? _videoPath;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    // Sans cette écoute, le bouton resterait grisé pendant toute la saisie :
    // son état dépend du texte, et rien d'autre ne reconstruit la feuille.
    _body.addListener(_onBodyChanged);
  }

  void _onBodyChanged() => setState(() {});

  @override
  void dispose() {
    _body.removeListener(_onBodyChanged);
    _body.dispose();
    super.dispose();
  }

  /// Le dossier d'envoi est l'identifiant de l'auteur : c'est ce que la
  /// policy Storage impose, et ce que la base revérifie à l'écriture de la
  /// ligne (`validate_media_paths`, `0061`).
  String? get _folder => ref.read(currentUserProvider).valueOrNull?.id;

  void _signal(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addPhotos() async {
    final folder = _folder;
    if (folder == null) return;
    setState(() => _uploading = true);
    final result = await pickAndUploadImages(
      client: ref.read(supabaseClientProvider),
      bucket: _bucket,
      folder: folder,
      // Quatre, comme le plafond posé en base : annoncer plus serait
      // promettre un envoi que l'écriture refusera.
      limit: 4,
    );
    if (!mounted) return;
    setState(() {
      _uploading = false;
      _images.addAll(result.paths);
      if (_images.length > 4) _images.removeRange(4, _images.length);
    });
    if (result.failures > 0) {
      _signal(
        result.failures == 1
            ? 'Une photo n\'a pas pu être ajoutée.'
            : '${result.failures} photos n\'ont pas pu être ajoutées.',
      );
    }
  }

  Future<void> _addVideo() async {
    final folder = _folder;
    if (folder == null) return;
    setState(() => _uploading = true);
    try {
      final path = await pickAndUploadVideo(
        client: ref.read(supabaseClientProvider),
        bucket: _bucket,
        folder: folder,
      );
      if (!mounted) return;
      setState(() => _videoPath = path ?? _videoPath);
    } catch (e) {
      _signal('Impossible d\'ajouter cette vidéo. $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _submit() async {
    final ok = await ref
        .read(reviewCommentControllerProvider.notifier)
        .add(
          reviewId: widget.reviewId,
          productId: widget.productId,
          body: _body.text.trim(),
          imagePaths: _images,
          videoPath: _videoPath,
        );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      return;
    }
    final error = ref.read(reviewCommentControllerProvider).error;
    _signal(error?.toString() ?? 'Le commentaire n\'a pas pu être publié.');
  }

  @override
  Widget build(BuildContext context) {
    final isLoading =
        ref.watch(reviewCommentControllerProvider).isLoading || _uploading;
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Commenter cet avis',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Votre commentaire sera visible par tous les visiteurs de ce '
              'produit.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.md),
            MtcTextField(
              controller: _body,
              label: 'Votre commentaire',
              maxLines: 3,
            ),
            if (_images.isNotEmpty || _videoPath != null)
              MediaStrip(imagePaths: _images, videoPath: _videoPath),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isLoading || _images.length >= 4
                        ? null
                        : _addPhotos,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(
                      _images.isEmpty ? 'Photos' : '${_images.length}/4',
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isLoading ? null : _addVideo,
                    icon: const Icon(Icons.videocam_outlined),
                    label: Text(_videoPath == null ? 'Vidéo' : 'Remplacer'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            MtcPrimaryButton(
              label: 'Publier',
              isLoading: isLoading,
              // Un commentaire vide est refusé en base (`length(btrim(body))
              // > 0`) : autant ne pas laisser croire que le bouton part.
              onPressed: _body.text.trim().isEmpty ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
