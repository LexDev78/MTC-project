import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';

import '../../domain/entities/courier_delivery.dart';
import '../controllers/courier_review_controller.dart';
import '../providers/delivery_providers.dart';

/// File des dossiers livreurs déposés, réservée au staff — pendant de
/// `KycReviewQueueScreen` pour les fournisseurs.
///
/// La décision se prend ici même, sans écran de détail intermédiaire : un
/// dossier livreur tient en une identité, un moyen de transport et deux à
/// quatre pièces, là où un dossier fournisseur porte une forme juridique, un
/// RCCM et un NIF.
///
/// Les pièces sont **affichées**, pas listées (`0105`). Un écran qui se
/// contente d'annoncer « 4 documents » redemande à l'agent de décider sans
/// avoir rien vu — c'est le défaut que `KycDocumentViewer` avait corrigé
/// côté fournisseur, et il n'y a pas de raison de le refaire ici.
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
              title: 'Aucun dossier à examiner',
              subtitle:
                  'Les livreurs apparaissent ici une fois leurs pièces '
                  'déposées.',
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
              _lieuEtVehicule(courier),
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (courier.documents.isEmpty)
              // Ne devrait pas arriver — la file ne liste que les dossiers
              // déposés, et un dépôt exige des pièces. Si cela se produit,
              // c'est un défaut, et l'agent doit le voir plutôt que de
              // valider à l'aveugle.
              Card(
                color: scheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Text(
                    'Dossier déposé sans aucune pièce : à signaler.',
                    style: TextStyle(color: scheme.onErrorContainer),
                  ),
                ),
              )
            else
              for (final document in courier.documents)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: PrivateDocumentViewer(
                    label: document.type.label,
                    path: document.filePath,
                    bucket: 'courier-documents',
                  ),
                ),
            const SizedBox(height: AppSpacing.xs),
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

  /// Ville, moyen de transport et précision, dans cet ordre : l'agent lit
  /// d'abord où le livreur opère, puis avec quoi.
  String _lieuEtVehicule(PendingCourier courier) {
    final morceaux = <String>[courier.city];
    final type = courier.vehicleType;
    if (type != null) morceaux.add(type.label);
    final libelle = courier.vehicleLabel;
    if (libelle != null && libelle.isNotEmpty) morceaux.add(libelle);
    return morceaux.join(' · ');
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
