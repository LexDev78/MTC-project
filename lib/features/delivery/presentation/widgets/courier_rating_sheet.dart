import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';
import 'package:mtc_app/features/ratings/presentation/widgets/star_rating_input.dart';
import 'package:mtc_app/core/error/user_message.dart';

import '../controllers/courier_rating_controller.dart';
import '../providers/courier_history_providers.dart';

/// Noter le livreur d'une course livrée — même feuille pour le client et
/// pour le fournisseur.
///
/// Un seul composant pour les deux côtés, parce que le geste est le même et
/// que le rôle n'est pas une saisie : le serveur le déduit de l'appelant
/// (`rate_courier`, `0059`). Un composant par rôle aurait surtout créé deux
/// endroits où corriger la même chose.
///
/// Ouvre une feuille modale plutôt qu'un écran : la note se donne en deux
/// gestes depuis la commande qu'on est en train de regarder, et perdre cette
/// commande de vue pour cliquer cinq étoiles serait un détour.
Future<void> showCourierRatingSheet(
  BuildContext context, {
  required String deliveryId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      // Le clavier remonte sous le champ de commentaire : sans cela, la
      // saisie se ferait derrière.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
      ),
      child: _CourierRatingSheet(deliveryId: deliveryId),
    ),
  );
}

class _CourierRatingSheet extends ConsumerStatefulWidget {
  const _CourierRatingSheet({required this.deliveryId});

  final String deliveryId;

  @override
  ConsumerState<_CourierRatingSheet> createState() =>
      _CourierRatingSheetState();
}

class _CourierRatingSheetState extends ConsumerState<_CourierRatingSheet> {
  final _comment = TextEditingController();
  int _stars = 0;

  /// Pré-remplissage fait une seule fois : réappliquer la note existante à
  /// chaque reconstruction écraserait les étoiles que l'utilisateur vient de
  /// changer.
  bool _prefilled = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = await ref
        .read(courierRatingControllerProvider.notifier)
        .submit(
          deliveryId: widget.deliveryId,
          stars: _stars,
          comment: _comment.text,
        );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Merci, votre note est enregistrée.')),
      );
      return;
    }
    // Le motif vient du serveur (course non livrée, pas la vôtre…) : on
    // l'affiche tel quel plutôt que d'en inventer un approximatif.
    final error = ref.read(courierRatingControllerProvider).error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          messagePourUtilisateur(
            error,
            repli: 'La note n\'a pas pu être envoyée.',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLoading = ref.watch(courierRatingControllerProvider).isLoading;
    final existing = ref.watch(myDeliveryRatingProvider(widget.deliveryId));

    final already = existing.valueOrNull;
    if (!_prefilled && already != null) {
      _prefilled = true;
      _stars = already.stars;
      _comment.text = already.comment ?? '';
    }

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
              already == null ? 'Noter le livreur' : 'Modifier votre note',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Ponctualité, soin du colis, correction. Le livreur verra la '
              'note et votre mot, jamais votre nom.',
              style: TextStyle(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            StarRatingInput(
              value: _stars,
              onChanged: (value) => setState(() => _stars = value),
            ),
            const SizedBox(height: AppSpacing.md),
            MtcTextField(
              controller: _comment,
              label: 'Commentaire (facultatif)',
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.lg),
            MtcPrimaryButton(
              label: already == null ? 'Envoyer la note' : 'Mettre à jour',
              isLoading: isLoading,
              // Zéro étoile n'est pas une note : le serveur la refuserait,
              // autant ne pas laisser croire que le bouton va marcher.
              onPressed: _stars == 0 ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
