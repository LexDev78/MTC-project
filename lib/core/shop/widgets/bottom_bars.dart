import 'package:flutter/material.dart';

import 'package:mtc_app/core/utils/currency_formatter.dart';

import '../shop_icons.dart';
import '../shop_tokens.dart';

/// Le bouton du bas de la fiche produit (`CartButton` du kit) : le prix à
/// gauche, l'action à droite sur un pan assombri.
class CartButton extends StatelessWidget {
  const CartButton({
    super.key,
    required this.priceFcfa,
    required this.title,
    this.subtitle = 'Prix unitaire',
    required this.onPressed,
    this.isLoading = false,
  });

  final int priceFcfa;
  final String title;
  final String subtitle;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final texte = Theme.of(
      context,
    ).textTheme.titleSmall!.copyWith(color: Colors.white);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: ShopSizes.padding,
          vertical: ShopSizes.radius / 2,
        ),
        child: SizedBox(
          height: 64,
          child: Material(
            color: Colors.transparent,
            clipBehavior: Clip.hardEdge,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(ShopSizes.radius)),
            ),
            // Le dégradé de la charte, comme les autres boutons pleins
            // (`ShopTheme.fondDegrade`) ; `Ink` le peint sous l'onde du toucher.
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    for (final couleur in ShopColors.gradient)
                      onPressed == null
                          ? couleur.withValues(alpha: 0.5)
                          : couleur,
                  ],
                ),
              ),
              child: InkWell(
                onTap: isLoading ? null : onPressed,
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: ShopSizes.padding,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                CurrencyFormatter.formatFcfa(priceFcfa),
                                style: texte,
                              ),
                            ),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Container(
                        alignment: Alignment.center,
                        height: double.infinity,
                        color: Colors.black.withValues(alpha: 0.15),
                        child: isLoading
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                title,
                                style: texte,
                                textAlign: TextAlign.center,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Le gros bouton (au dégradé de la charte) collé en bas des écrans de maquette
/// (« Commander », « Continuer », « Confirmer »), avec ce qu'il faut de
/// marge pour le geste de retour du téléphone.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.color,
    this.above,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  /// Une icône du kit devant le libellé (« Suivre ma commande »).
  final Widget? icon;

  /// Le rouge de l'annulation ; le dégradé de la charte sinon.
  final Color? color;

  /// Ce qui s'affiche juste au-dessus du bouton (un total, une mention).
  final Widget? above;

  @override
  Widget build(BuildContext context) {
    final style = ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 18),
      // Une couleur imposée (le rouge d'une annulation) remplace le dégradé
      // du thème : il la recouvrirait.
      backgroundColor: color,
      disabledBackgroundColor: color?.withValues(alpha: 0.4),
      backgroundBuilder: color == null ? null : (_, _, child) => child!,
    );
    final contenu = isLoading
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : Text(label);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          ShopSizes.screenMargin,
          ShopSizes.padding / 2,
          ShopSizes.screenMargin,
          ShopSizes.padding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (above != null) ...[
              above!,
              const SizedBox(height: ShopSizes.padding),
            ],
            SizedBox(
              width: double.infinity,
              child: icon == null || isLoading
                  ? ElevatedButton(
                      onPressed: isLoading ? null : onPressed,
                      style: style,
                      child: contenu,
                    )
                  : ElevatedButton.icon(
                      onPressed: onPressed,
                      style: style,
                      icon: icon,
                      label: contenu,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// La carte du bas d'une fiche en rupture (`NotifyMeCard` du kit) : une
/// pastille violette, une phrase, et ce qui se passe au toucher à droite.
class NoticeCard extends StatelessWidget {
  const NoticeCard({
    super.key,
    required this.icon,
    required this.text,
    this.onTap,
    this.trailing,
  });

  /// Une icône du kit (`ShopIcons`), en blanc sur la pastille.
  final String icon;
  final String text;
  final VoidCallback? onTap;

  /// Un interrupteur, un chevron.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final encre = Theme.of(context).colorScheme.onSurface;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: ShopSizes.padding,
          vertical: ShopSizes.padding / 2,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(ShopSizes.radius),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(ShopSizes.radius),
                border: Border.all(color: encre.withValues(alpha: 0.1)),
              ),
              padding: const EdgeInsets.all(ShopSizes.padding),
              child: Row(
                children: [
                  Container(
                    height: 40,
                    width: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: ShopColors.primary,
                      borderRadius: BorderRadius.circular(ShopSizes.radius),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: ShopIcon(icon, color: Colors.white),
                  ),
                  const SizedBox(width: ShopSizes.padding),
                  Expanded(
                    child: Text(
                      text,
                      style: TextStyle(
                        color: encre,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
