import 'package:flutter/material.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';

/// Une explication qui attend qu'on la demande.
///
/// Les écrans fournisseur portaient plusieurs paragraphes de règles — « un
/// code promo ne s'applique qu'à vos produits », « les remises ne
/// s'additionnent pas » — affichés en permanence, avant même la liste
/// qu'on vient consulter. Utiles la première fois, ils occupent ensuite le
/// haut de l'écran à chaque visite et repoussent le contenu vers le bas.
///
/// Le texte ne disparaît pas pour autant : ces règles évitent de vraies
/// erreurs de prix. Il passe derrière un « ? », à portée de doigt.
class MtcHelpHint extends StatelessWidget {
  const MtcHelpHint({
    super.key,
    required this.title,
    required this.message,
    this.label,
  });

  /// Le titre de la fenêtre d'explication.
  final String title;

  /// L'explication elle-même. Plusieurs paragraphes se séparent par une
  /// ligne vide, comme dans un texte ordinaire.
  final String message;

  /// Une amorce laissée visible à côté du « ? ». Sans elle, on ne sait pas
  /// sur quoi porte l'aide — un point d'interrogation seul n'annonce rien.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null)
          Flexible(
            child: Text(
              label!,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        IconButton(
          icon: const Icon(Icons.help_outline_rounded, size: 20),
          color: scheme.primary,
          tooltip: title,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          padding: EdgeInsets.zero,
          onPressed: () => showDialog<void>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text(title),
              content: SingleChildScrollView(
                child: Text(message, style: const TextStyle(height: 1.4)),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('J\'ai compris'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Même chose, posée en action de barre de titre.
///
/// Un `IconButton` nu dans `AppBar.actions` suffirait, mais la fenêtre et
/// son bouton de fermeture seraient à réécrire à chaque écran.
class MtcHelpAction extends StatelessWidget {
  const MtcHelpAction({super.key, required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: MtcHelpHint(title: title, message: message),
    );
  }
}
