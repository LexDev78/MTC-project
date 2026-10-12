import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/utils/date_formatter.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';

import '../../domain/entities/product_characteristic_type.dart';
import '../controllers/characteristic_type_review_controller.dart';
import '../providers/characteristic_type_providers.dart';

/// Staff-only queue of supplier-proposed characteristic types awaiting a
/// decision — reached from the "Fournisseur principal" dashboard, same
/// pattern as `KycReviewQueueScreen`. Unlike KYC, there's a single field to
/// review (the proposed label), so approve/reject happen inline here
/// instead of on a separate detail screen.
class CharacteristicTypeReviewQueueScreen extends ConsumerWidget {
  const CharacteristicTypeReviewQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Types de caractéristiques')),
      body: AsyncValueWidget(
        value: ref.watch(characteristicTypeQueueProvider),
        data: (queue) {
          if (queue.isEmpty) {
            return const MtcEmptyState(
              icon: Icons.tune_rounded,
              title: 'Aucune proposition en attente',
              subtitle:
                  'Les nouveaux types de caractéristiques proposés par les '
                  'fournisseurs apparaîtront ici.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: queue.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) => _QueueTile(type: queue[index]),
          );
        },
      ),
    );
  }
}

class _QueueTile extends ConsumerWidget {
  const _QueueTile({required this.type});

  final ProductCharacteristicType type;

  Future<String?> _promptRejectionReason(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Motif du refus'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Expliquez pourquoi ce type est refusé…',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Rejeter'),
          ),
        ],
      ),
    );
  }

  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    final staffId = ref.read(currentUserProvider).valueOrNull?.id;
    if (staffId == null || type.proposedBySupplierId == null) return;
    await ref
        .read(characteristicTypeReviewControllerProvider.notifier)
        .approve(
          id: type.id,
          proposedBySupplierId: type.proposedBySupplierId!,
          staffId: staffId,
        );
  }

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    final reason = await _promptRejectionReason(context);
    if (reason == null || reason.isEmpty) return;
    final staffId = ref.read(currentUserProvider).valueOrNull?.id;
    if (staffId == null || type.proposedBySupplierId == null || !context.mounted) {
      return;
    }
    await ref
        .read(characteristicTypeReviewControllerProvider.notifier)
        .reject(
          id: type.id,
          proposedBySupplierId: type.proposedBySupplierId!,
          staffId: staffId,
          reason: reason,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final reviewState = ref.watch(characteristicTypeReviewControllerProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: scheme.primaryContainer,
              child: Icon(Icons.tune_rounded, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type.label,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    'Proposé ${DateFormatter.relative(type.createdAt)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.close_rounded, color: scheme.error),
              tooltip: 'Rejeter',
              onPressed: reviewState.isLoading
                  ? null
                  : () => _reject(context, ref),
            ),
            IconButton(
              icon: Icon(Icons.check_rounded, color: scheme.primary),
              tooltip: 'Approuver',
              onPressed: reviewState.isLoading
                  ? null
                  : () => _approve(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}
