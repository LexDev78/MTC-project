import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';

import '../../domain/entities/courier_dossier.dart';
import '../controllers/courier_dossier_controller.dart';
import '../providers/delivery_providers.dart';

/// Le dossier du livreur : moyen de transport, pièces, dépôt (`0105`).
///
/// L'ordre de l'écran suit l'ordre de la décision : le moyen de transport
/// **d'abord**, parce que c'est lui qui détermine les pièces exigées. Choisir
/// « moto » fait apparaître le permis et la carte grise ; choisir « vélo »
/// les fait disparaître. Afficher les cinq cases à tout le monde ferait
/// renoncer un livreur à vélo persuadé qu'il lui manque un permis.
class CourierDossierScreen extends ConsumerStatefulWidget {
  const CourierDossierScreen({super.key});

  @override
  ConsumerState<CourierDossierScreen> createState() =>
      _CourierDossierScreenState();
}

class _CourierDossierScreenState extends ConsumerState<CourierDossierScreen> {
  CourierVehicleType? _vehicule;
  final _libelle = TextEditingController();
  bool _libelleInitialise = false;

  @override
  void dispose() {
    _libelle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mon dossier')),
      body: AsyncValueWidget(
        value: ref.watch(courierDossierProvider),
        data: (dossier) {
          // Le dossier déjà déposé ne se modifie plus : la politique
          // d'écriture le gèle pendant l'examen, et un écran qui laisserait
          // essayer ne récolterait qu'un refus silencieux.
          if (dossier.isSubmitted) return _EnExamen(dossier: dossier);

          _vehicule ??= dossier.vehicleType;
          if (!_libelleInitialise) {
            _libelle.text = dossier.vehicleLabel ?? '';
            _libelleInitialise = true;
          }
          return _Formulaire(
            dossier: dossier,
            vehicule: _vehicule,
            libelle: _libelle,
            onVehicule: (type) => setState(() => _vehicule = type),
          );
        },
      ),
    );
  }
}

/// Dossier entre les mains de MTC : on dit ce qui a été envoyé, et on
/// n'offre rien à modifier.
class _EnExamen extends StatelessWidget {
  const _EnExamen({required this.dossier});

  final CourierDossier dossier;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Card(
          color: scheme.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Icon(Icons.hourglass_top_rounded, color: scheme.onSecondaryContainer),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Vos pièces sont déposées. Un agent MTC les examine ; '
                    'vous recevrez une notification dès la décision.',
                    style: TextStyle(color: scheme.onSecondaryContainer),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (dossier.vehicleType != null)
          ListTile(
            leading: const Icon(Icons.two_wheeler_outlined),
            title: const Text('Moyen de transport'),
            subtitle: Text(
              dossier.vehicleLabel == null || dossier.vehicleLabel!.isEmpty
                  ? dossier.vehicleType!.label
                  : '${dossier.vehicleType!.label} · ${dossier.vehicleLabel}',
            ),
          ),
        for (final document in dossier.documents)
          ListTile(
            leading: Icon(Icons.check_circle_rounded, color: scheme.primary),
            title: Text(document.type.label),
            subtitle: const Text('Envoyé'),
          ),
      ],
    );
  }
}

class _Formulaire extends ConsumerWidget {
  const _Formulaire({
    required this.dossier,
    required this.vehicule,
    required this.libelle,
    required this.onVehicule,
  });

  final CourierDossier dossier;
  final CourierVehicleType? vehicule;
  final TextEditingController libelle;
  final ValueChanged<CourierVehicleType> onVehicule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final controller = ref.watch(courierDossierControllerProvider.notifier);
    final enCours = ref.watch(courierDossierControllerProvider).isLoading;
    final manquantes = vehicule == null
        ? const <CourierDocumentType>[]
        : dossier.missingFor(vehicule!);

    Future<void> deposer() async {
      final ok = await controller.submit(
        vehicleType: vehicule!,
        vehicleLabel: libelle.text.trim().isEmpty ? null : libelle.text.trim(),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Dossier déposé. MTC vous répondra après examen.'
                : controller.lastError ?? 'Le dépôt a échoué.',
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        if (dossier.rejectionReason != null) ...[
          Card(
            color: scheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dossier refusé',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: scheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  // Le motif vient de l'agent, mot pour mot : c'est lui qui
                  // dit quelle pièce reprendre.
                  Text(
                    dossier.rejectionReason!,
                    style: TextStyle(color: scheme.onErrorContainer),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Text(
          'Moyen de transport',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Il décide des pièces à fournir.',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final type in CourierVehicleType.values)
              ChoiceChip(
                label: Text(type.label),
                selected: vehicule == type,
                onSelected: (_) => onVehicule(type),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        MtcTextField(
          controller: libelle,
          label: 'Précision — ex. Djakarta rouge (optionnel)',
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: Text(
                'Pièces',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const MtcHelpHint(
              title: 'Qui voit mes pièces ?',
              message:
                  'Vos pièces ne sont visibles que par vous et par les agents '
                  'MTC chargés de la validation. Aucun client ni fournisseur '
                  'n\'y a accès, et aucun autre livreur.',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (vehicule == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Text(
              'Choisissez d\'abord votre moyen de transport.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          )
        else
          for (final type in _emplacements(vehicule!))
            DocumentSlotTile(
              label: type.label,
              hasFile: dossier.documentOf(type) != null,
              isRequired: vehicule!.requiredDocuments.contains(type),
              onPicked: (file) =>
                  controller.addDocument(type: type, file: file),
              onRemove: () {
                final existing = dossier.documentOf(type);
                if (existing != null) {
                  controller.removeDocument(documentId: existing.id);
                }
              },
            ),
        const SizedBox(height: AppSpacing.lg),
        if (manquantes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              'Il manque : ${manquantes.map((t) => t.label).join(', ')}.',
              style: TextStyle(color: scheme.error),
            ),
          ),
        MtcPrimaryButton(
          label: 'Déposer mon dossier',
          // Le serveur refuserait de toute façon un dossier incomplet
          // (`submit_courier_documents`) ; désactiver le bouton évite au
          // livreur d'avoir à lire un refus pour l'apprendre.
          onPressed: vehicule == null || manquantes.isNotEmpty || enCours
              ? null
              : deposer,
        ),
      ],
    );
  }

  /// Les emplacements montrés : les pièces exigées, plus l'assurance, qui
  /// reste facultative mais que l'agent regarde quand elle est là.
  List<CourierDocumentType> _emplacements(CourierVehicleType vehicule) => [
    ...vehicule.requiredDocuments,
    if (vehicule.isMotorised) CourierDocumentType.insurance,
  ];
}
