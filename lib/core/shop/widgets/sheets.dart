import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../shop_icons.dart';
import '../shop_tokens.dart';

/// Ouvre une feuille du bas à la manière du kit (`customModalBottomSheet`) :
/// coins arrondis de 24, fond de la toile, 75 % de l'écran par défaut.
///
/// Le clavier la remonte, et la raccourcit s'il le faut : un champ de
/// saisie ne doit jamais finir dessous.
Future<T?> showShopSheet<T>(
  BuildContext context, {
  required Widget child,
  double heightFactor = 0.75,
  bool isDismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    clipBehavior: Clip.hardEdge,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: isDismissible,
    useSafeArea: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(ShopSizes.radius * 2),
      ),
    ),
    builder: (context) => LayoutBuilder(
      builder: (context, constraints) {
        final clavier = MediaQuery.viewInsetsOf(context).bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: clavier),
          child: SizedBox(
            height: math.min(
              MediaQuery.sizeOf(context).height * heightFactor,
              constraints.maxHeight - clavier,
            ),
            child: child,
          ),
        );
      },
    ),
  );
}

/// L'en-tête des feuilles et des écrans de maquette : flèche de retour,
/// titre centré, action à droite (« Tout effacer », une icône).
class SheetHeader extends StatelessWidget {
  const SheetHeader({
    super.key,
    required this.title,
    this.onBack,
    this.actionLabel,
    this.onAction,
    this.action,
  });

  final String title;

  /// `null` : la feuille se ferme.
  final VoidCallback? onBack;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final droite =
        action ??
        (actionLabel == null
            ? null
            : TextButton(onPressed: onAction, child: Text(actionLabel!)));
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ShopSizes.padding,
        ShopSizes.padding,
        ShopSizes.padding,
        ShopSizes.padding / 2,
      ),
      child: SizedBox(
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                tooltip: 'Retour',
                onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                icon: const ShopIcon(ShopIcons.arrowLeft),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 96),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.appBarTheme.titleTextStyle,
              ),
            ),
            if (droite != null)
              Align(alignment: Alignment.centerRight, child: droite),
          ],
        ),
      ),
    );
  }
}
