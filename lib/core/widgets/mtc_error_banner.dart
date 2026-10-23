import 'package:flutter/material.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';

/// Un refus à lire là où l'on vient d'agir, dans un formulaire : rouge pâle,
/// avec son icône, sous le champ ou le bouton concerné.
///
/// Pour un écran qui n'a pas pu se charger, c'est `MtcErrorView`.
class MtcErrorBanner extends StatelessWidget {
  const MtcErrorBanner(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm + AppSpacing.xs),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: scheme.onErrorContainer),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(message, style: TextStyle(color: scheme.onErrorContainer)),
          ),
        ],
      ),
    );
  }
}
