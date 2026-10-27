import 'package:flutter/material.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';

/// Prévient qu'une position n'a jamais été pointée sur la carte.
///
/// Les comptes antérieurs au sélecteur portent les coordonnées du **centre
/// de leur ville**, pas de leur adresse : rien ne les distingue d'un point
/// choisi, et c'est ce qui donne l'impression que la carte se trompe. Le
/// livreur va au centre-ville parce que c'est littéralement ce qui est
/// enregistré.
///
/// Dit la conséquence et non l'état technique — « votre position n'est pas
/// confirmée » n'apprend rien à personne, « les livreurs iront au centre de
/// la ville » se comprend tout de suite.
class PositionToConfirmBanner extends StatelessWidget {
  const PositionToConfirmBanner({
    super.key,
    required this.message,
    required this.onFix,
    this.actionLabel = 'Placer le point',
  });

  final String message;
  final VoidCallback onFix;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      color: scheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.wrong_location_outlined,
                  color: scheme.onTertiaryContainer,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(color: scheme.onTertiaryContainer),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: onFix,
              icon: const Icon(Icons.map_outlined),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
