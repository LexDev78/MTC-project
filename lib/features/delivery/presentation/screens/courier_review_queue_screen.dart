import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';

import '../../domain/entities/courier_delivery.dart';
import '../controllers/courier_review_controller.dart';
import '../providers/delivery_providers.dart';

/// File des inscriptions livreurs en attente, réservée au staff — pendant de
/// `KycReviewQueueScreen` pour les fournisseurs.
///
/// Plus simple que celle-ci : un livreur n'a pas encore de pièces à examiner,
/// la décision se prend sur son identité et sa ville. Elle se prend donc ici
/// même, sans écran de détail intermédiaire.
class CourierReviewQueueScreen extends ConsumerWidget {
  const CourierReviewQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Validation des livreurs')),
      body: AsyncValueWidget(
        value: ref.watch(pendingCouriersProvider),
        data: (queue) {
          if (queue.isEmpty) {
            return const MtcEmptyState(
              icon: Icons.delivery_dining_outlined,
              title: 'Aucune inscription en attente',
              subtitle: 'Les nouveaux livreurs apparaîtront ici.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: queue.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) => _QueueTile(courier: queue[index]),
          );
        },
      ),
    );
  }
}

class _QueueTile extends ConsumerWidget {
  const _QueueTile({required this.courier});

  final PendingCourier courier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    Future<void> decide({required bool approve}) async {
      String? reason;
      if (!approve) {
        reason = await _askReason(context);
        // Annulé dans la boîte de dialogue : on ne refuse pas par défaut.
        if (reason == null) return;
      }
      final ok = await ref
          .read(courierReviewControllerProvider.notifier)
          .review(courierId: courier.id, approve: approve, reason: reason);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? (approve ? 'Livreur validé.' : 'Inscription refusée.')
                : 'La décision n\'a pas pu être enregistrée.',
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              courier.displayName,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              courier.phoneNumber,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            Text(
              courier.vehicleLabel == null || courier.vehicleLabel!.isEmpty
                  ? courier.city
                  : '${courier.city} · ${courier.vehicleLabel}',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => decide(approve: false),
                    child: const Text('Refuser'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 2,
                  child: MtcPrimaryButton(
                    label: 'Valider',
                    onPressed: () => decide(approve: true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Un refus doit être motivé — le serveur le refuserait sinon
  /// (`review_courier`), et le livreur recevra ce motif tel quel.
  Future<String?> _askReason(BuildContext context) {
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
            hintText: 'Ce message sera envoyé au livreur.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              final reason = controller.text.trim();
              if (reason.isEmpty) return;
              Navigator.of(context).pop(reason);
            },
            child: const Text('Refuser'),
          ),
        ],
      ),
    );
  }
}
