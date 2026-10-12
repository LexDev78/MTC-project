import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/utils/date_formatter.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';
import 'package:mtc_app/features/catalog/presentation/providers/supplier_product_providers.dart';
import 'package:mtc_app/features/suppliers/presentation/providers/operating_supplier_providers.dart';

import '../providers/comment_providers.dart';
import '../providers/supplier_comment_inbox_providers.dart';
import '../widgets/product_comments_modal.dart';

/// Cross-product comment inbox for the operating supplier — reached from
/// an action on the "Produits" tab rather than its own tab of `SupplierShell`
/// (the shell stays at 6 branches). Tapping an entry reuses
/// `showProductCommentsModal` as-is to actually read/reply to the thread —
/// this screen's job is only to say "here's what's waiting for a reply,
/// across every one of your listings".
class SupplierCommentInboxScreen extends ConsumerStatefulWidget {
  const SupplierCommentInboxScreen({super.key});

  @override
  ConsumerState<SupplierCommentInboxScreen> createState() =>
      _SupplierCommentInboxScreenState();
}

class _SupplierCommentInboxScreenState
    extends ConsumerState<SupplierCommentInboxScreen> {
  @override
  void initState() {
    super.initState();
    // `supplierProductCommentsProvider` is `autoDispose`, but Flutter's
    // Navigator keeps a popped route's state around for its exit
    // animation/potential back-swipe (`maintainState`), so the previous
    // visit's watch doesn't reliably drop to zero listeners before this one
    // starts — `autoDispose` alone can't be trusted to force a fresh fetch.
    // Same fix as `NotificationCenterScreen`: explicitly invalidate on open.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final supplierId = ref.read(operatingSupplierIdProvider);
      if (supplierId == null) return;
      ref.invalidate(supplierProductCommentsProvider(supplierId));
      ref.invalidate(myProductsProvider(supplierId));
    });
  }

  @override
  Widget build(BuildContext context) {
    final supplierId = ref.watch(operatingSupplierIdProvider);
    if (supplierId == null) {
      return const Scaffold(body: MtcLoadingView());
    }

    final itemsAsync = ref.watch(supplierCommentInboxProvider(supplierId));

    return Scaffold(
      appBar: AppBar(title: const Text('Commentaires produits')),
      body: AsyncValueWidget(
        value: itemsAsync,
        data: (items) {
          if (items.isEmpty) {
            return const MtcEmptyState(
              icon: Icons.forum_outlined,
              title: 'Aucun commentaire pour le moment',
              subtitle:
                  'Les questions de vos clients sur vos produits apparaîtront ici.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) =>
                _CommentInboxTile(item: items[index]),
          );
        },
      ),
    );
  }
}

class _CommentInboxTile extends StatelessWidget {
  const _CommentInboxTile({required this.item});

  final SupplierCommentInboxItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final comment = item.comment;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showProductCommentsModal(
          context,
          productId: comment.productId,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.productName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  RoleBadge(
                    label: item.hasSupplierReply ? 'Répondu' : 'En attente',
                    color: item.hasSupplierReply
                        ? scheme.primary
                        : scheme.tertiary,
                    icon: item.hasSupplierReply
                        ? Icons.check_circle_outline_rounded
                        : Icons.schedule_rounded,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      comment.authorName,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  Text(
                    DateFormatter.relative(comment.createdAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                comment.text.isEmpty ? 'Pièce jointe' : comment.text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (item.replies.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${item.replies.length} réponse(s)',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
