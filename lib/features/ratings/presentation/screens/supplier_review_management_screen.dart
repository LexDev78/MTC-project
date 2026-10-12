import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/utils/date_formatter.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';
import 'package:mtc_app/features/suppliers/presentation/providers/operating_supplier_providers.dart';

import '../../domain/entities/review.dart';
import '../controllers/review_controller.dart';
import '../providers/review_providers.dart';
import '../widgets/product_reviews_section.dart' show MediaStrip;

/// Every review left on the operating supplier's storefront, with the
/// ability to write (or edit) a public reply — reached from an action on
/// the "Profil" tab rather than its own branch of `SupplierShell`, same
/// placement logic as the Lot 9 comment inbox.
class SupplierReviewManagementScreen extends ConsumerWidget {
  const SupplierReviewManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supplierId = ref.watch(operatingSupplierIdProvider);
    if (supplierId == null) {
      return const Scaffold(body: MtcLoadingView());
    }

    final reviewsAsync = ref.watch(supplierReviewsProvider(supplierId));

    return Scaffold(
      appBar: AppBar(title: const Text('Avis clients')),
      body: AsyncValueWidget(
        value: reviewsAsync,
        data: (reviews) {
          if (reviews.isEmpty) {
            return const MtcEmptyState(
              icon: Icons.star_border_rounded,
              title: 'Aucun avis pour le moment',
              subtitle: 'Les avis laissés par vos clients apparaîtront ici.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: reviews.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) =>
                _ReviewManagementTile(review: reviews[index]),
          );
        },
      ),
    );
  }
}

class _ReviewManagementTile extends ConsumerStatefulWidget {
  const _ReviewManagementTile({required this.review});

  final Review review;

  @override
  ConsumerState<_ReviewManagementTile> createState() =>
      _ReviewManagementTileState();
}

class _ReviewManagementTileState extends ConsumerState<_ReviewManagementTile> {
  bool _isReplying = false;
  late final _controller = TextEditingController(
    text: widget.review.supplierReply,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reply = _controller.text.trim();
    if (reply.isEmpty) return;
    final ok = await ref
        .read(reviewControllerProvider.notifier)
        .replyToReview(reviewId: widget.review.id, reply: reply);
    if (ok && mounted) setState(() => _isReplying = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final review = widget.review;
    final hasReply = review.supplierReply != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                MtcRatingStars(rating: review.stars.toDouble(), showValue: false),
                const Spacer(),
                RoleBadge(
                  label: hasReply ? 'Répondu' : 'En attente',
                  color: hasReply ? scheme.primary : scheme.tertiary,
                  icon: hasReply
                      ? Icons.check_circle_outline_rounded
                      : Icons.schedule_rounded,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  DateFormatter.relative(review.createdAt),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(review.comment),
            // Les photos de l'acheteur (`0061`) : un reproche illustré ne se
            // traite pas comme un reproche décrit, et le vendeur doit voir ce
            // que voient ses futurs clients.
            MediaStrip(
              imagePaths: review.imagePaths,
              videoPath: review.videoPath,
            ),
            if (hasReply && !_isReplying) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Votre réponse',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(review.supplierReply!),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => setState(() => _isReplying = true),
                  child: const Text('Modifier la réponse'),
                ),
              ),
            ],
            if (_isReplying || !hasReply) ...[
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: 'Écrire une réponse publique...',
                ),
                minLines: 1,
                maxLines: 3,
              ),
              // `OverflowBar` rather than a plain `Row`: the app's
              // `FilledButtonThemeData` sets `minimumSize:
              // Size.fromHeight(56)` (infinite width, for the usual
              // full-bleed CTAs) — a bare `Row` gives its non-flex children
              // unbounded width to measure themselves against, and an
              // infinite minimum width against infinite available width
              // crashes the button's ink-shape layout. `OverflowBar` (what
              // `AlertDialog.actions` uses under the hood) measures each
              // child via dry layout first, so it stays immune.
              OverflowBar(
                alignment: MainAxisAlignment.end,
                spacing: AppSpacing.xs,
                children: [
                  if (_isReplying)
                    TextButton(
                      onPressed: () => setState(() => _isReplying = false),
                      child: const Text('Annuler'),
                    ),
                  FilledButton(
                    onPressed: _submit,
                    child: const Text('Envoyer'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
