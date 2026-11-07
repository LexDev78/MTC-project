import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../shop_icons.dart';
import '../shop_tokens.dart';

/// La ligne de menu du kit, suivie d'un trait : icône au trait, libellé,
/// chevron. Elle remplace les quatre variantes du kit (`DividerListTile`,
/// `ProductListTile`, `ProfileMenuListTile`, `…WithTrilingText`), qui ne
/// différaient que par un trait au-dessus ou un texte avant le chevron.
class ChevronListTile extends StatelessWidget {
  const ChevronListTile({
    super.key,
    required this.title,
    this.icon,
    this.onTap,
    this.trailingText,
    this.trailing,
    this.showDivider = true,
    this.dividerAbove = false,
    this.showChevron = true,
    this.danger = false,
    this.contentPadding,
    this.fontSize = 14,
  });

  final String title;

  /// Une icône du kit (`ShopIcons`).
  final String? icon;
  final VoidCallback? onTap;

  /// Un état avant le chevron (« Désactivé », « 3 »).
  final String? trailingText;

  /// Un widget avant le chevron : compteur, pastille.
  final Widget? trailing;
  final bool showDivider;
  final bool dividerAbove;
  final bool showChevron;

  /// La déconnexion : icône et libellé en rouge, sans chevron.
  final bool danger;
  final EdgeInsetsGeometry? contentPadding;

  /// 14 dans les menus du profil, 16 sur la fiche produit
  /// (`ProductListTile` du kit garde la taille d'un `ListTile`).
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final couleur = danger ? ShopColors.error : theme.iconTheme.color;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (dividerAbove) const Divider(height: 1),
        ListTile(
          onTap: onTap,
          minLeadingWidth: 24,
          contentPadding: contentPadding,
          leading: icon == null ? null : ShopIcon(icon!, color: couleur),
          title: Text(
            title,
            style: TextStyle(
              fontSize: fontSize,
              height: 1,
              color: danger ? ShopColors.error : theme.colorScheme.onSurface,
            ),
          ),
          trailing:
              danger ||
                  (!showChevron && trailing == null && trailingText == null)
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (trailingText != null)
                      Text(trailingText!, style: theme.textTheme.bodyMedium),
                    ?trailing,
                    if (showChevron)
                      ShopIcon(
                        ShopIcons.miniRight,
                        color: theme.iconTheme.color?.withValues(alpha: 0.4),
                      ),
                  ],
                ),
        ),
        if (showDivider) const Divider(height: 1),
      ],
    );
  }
}

/// Un réglage à bascule, titre et explication (« Notifications »,
/// « Emballage cadeau » des maquettes).
class ShopSwitchTile extends StatelessWidget {
  const ShopSwitchTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.showDivider = true,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: ShopSizes.padding),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.bodyLarge),
                    if (subtitle != null) ...[
                      const SizedBox(height: ShopSizes.padding / 2),
                      Text(subtitle!, style: theme.textTheme.bodyMedium),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: ShopSizes.padding),
              CupertinoSwitch(
                value: value,
                onChanged: onChanged,
                activeTrackColor: ShopColors.primary,
              ),
            ],
          ),
        ),
        if (showDivider) const Divider(height: 1),
      ],
    );
  }
}

/// Une case à cocher suivie d'un trait, avec un compte grisé (« S (29) ») :
/// la maquette « Size » du kit — une case de 16 au bord de la marge, le
/// texte 8 plus loin, toute la ligne sensible au toucher.
class ShopCheckboxTile extends StatelessWidget {
  const ShopCheckboxTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.count,
  });

  final String title;
  final bool value;
  final ValueChanged<bool?>? onChanged;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final changer = onChanged;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          checked: value,
          child: InkWell(
            onTap: changer == null ? null : () => changer(!value),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: ShopSizes.padding),
              child: Row(
                children: [
                  _CaseCarree(coche: value),
                  const SizedBox(width: ShopSizes.padding / 2),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: title,
                        style: TextStyle(
                          fontSize: 16,
                          color: theme.colorScheme.onSurface,
                        ),
                        children: [
                          if (count != null)
                            TextSpan(
                              text: ' ($count)',
                              style: TextStyle(
                                color: value
                                    ? theme.colorScheme.onSurface
                                    : theme.colorScheme.onSurface.withValues(
                                        alpha: 0.2,
                                      ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

/// Un choix exclusif suivi d'un trait (« Trier par »).
class ShopRadioTile<T> extends StatelessWidget {
  const ShopRadioTile({
    super.key,
    required this.title,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    this.square = false,
  });

  final String title;
  final T value;
  final T? groupValue;
  final ValueChanged<T?> onChanged;

  /// La case carrée des raisons d'annulation du kit (« Cancel order »), au
  /// lieu du rond : l'apparence d'une case à cocher, mais un seul choix —
  /// et c'est ce que les lecteurs d'écran annoncent.
  final bool square;

  @override
  Widget build(BuildContext context) {
    final choisi = value == groupValue;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          inMutuallyExclusiveGroup: true,
          checked: choisi,
          child: InkWell(
            onTap: () => onChanged(value),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: ShopSizes.padding),
              child: Row(
                children: [
                  if (square)
                    _CaseCarree(coche: choisi)
                  else
                    AnimatedContainer(
                      duration: ShopSizes.duration,
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: choisi
                              ? ShopColors.primary
                              : _contourDeCase(context),
                          width: choisi ? 5 : 1.5,
                        ),
                      ),
                    ),
                  const SizedBox(width: ShopSizes.padding / 2),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(fontSize: 16, color: scheme.onSurface),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

/// Le contour d'une case ou d'un rond vide : le gris clair des maquettes
/// sur fond blanc ; sur fond sombre, le trait des séparateurs disparaît, et
/// le kit prend alors son gris moyen (`whileColor40`).
Color _contourDeCase(BuildContext context) {
  final theme = Theme.of(context);
  return theme.brightness == Brightness.dark
      ? ShopColors.white40
      : theme.colorScheme.outline;
}

/// La case du kit : 16 points, coins arrondis, violette et cochée quand
/// elle est prise.
class _CaseCarree extends StatelessWidget {
  const _CaseCarree({required this.coche});

  final bool coche;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: ShopSizes.duration,
      width: 16,
      height: 16,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: coche ? ShopColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(ShopSizes.radius / 3),
        border: coche
            ? null
            : Border.all(color: _contourDeCase(context), width: 1.5),
      ),
      child: coche
          ? const ShopIcon(ShopIcons.singlecheck, size: 12, color: Colors.white)
          : null,
    );
  }
}

/// Une information en ligne : libellé gris à gauche, valeur à droite
/// (fiche « Profil » des maquettes, récapitulatifs).
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.onTap,
    this.showDivider = true,
  }) : child = null,
       stacked = false;

  /// Le libellé au-dessus, la valeur dessous et en entier : pour un texte
  /// long qu'une ligne couperait (un message), ou un contenu qui n'est pas
  /// du texte ([child], une note vocale par exemple).
  const InfoRow.stacked({
    super.key,
    required this.label,
    this.value = '',
    this.child,
    this.valueColor,
    this.showDivider = true,
  }) : onTap = null,
       stacked = true;

  final String label;
  final String value;
  final Color? valueColor;
  final VoidCallback? onTap;
  final bool showDivider;
  final Widget? child;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final libelle = Text(
      label,
      style: theme.textTheme.bodyLarge?.copyWith(
        color: theme.textTheme.bodyMedium?.color,
      ),
    );
    if (stacked) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: ShopSizes.padding * 1.25,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                libelle,
                const SizedBox(height: ShopSizes.padding / 2),
                child ??
                    Text(
                      value,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: valueColor ?? theme.colorScheme.onSurface,
                        height: 1.4,
                      ),
                    ),
              ],
            ),
          ),
          if (showDivider) const Divider(height: 1),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: ShopSizes.padding * 1.25,
            ),
            child: Row(
              children: [
                libelle,
                const SizedBox(width: ShopSizes.padding),
                Expanded(
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: valueColor ?? theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showDivider) const Divider(height: 1),
      ],
    );
  }
}

/// Une option à bascule mise en avant (« Make it a Gift » du kit) : une
/// pastille violette, un titre et sa précision, l'interrupteur à droite.
class ToggleCard extends StatelessWidget {
  const ToggleCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  /// Une icône du kit (`ShopIcons`), en blanc sur la pastille.
  final String icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final changer = onChanged;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: changer == null ? null : () => changer(!value),
        borderRadius: BorderRadius.circular(ShopSizes.radius),
        child: Ink(
          padding: const EdgeInsets.all(ShopSizes.padding),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ShopSizes.radius),
            border: Border.all(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ShopColors.primary,
                  borderRadius: BorderRadius.circular(ShopSizes.radius),
                ),
                child: ShopIcon(icon, color: Colors.white),
              ),
              const SizedBox(width: ShopSizes.padding),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleSmall),
                    const SizedBox(height: ShopSizes.padding / 4),
                    Text(subtitle, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
              const SizedBox(width: ShopSizes.padding / 2),
              CupertinoSwitch(
                value: value,
                onChanged: onChanged,
                activeTrackColor: ShopColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
