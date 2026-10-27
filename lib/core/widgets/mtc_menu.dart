import 'package:flutter/material.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';

/// Un groupe d'entrées de menu, posé dans une carte.
///
/// C'est le motif des écrans de compte : un titre de section, puis des
/// lignes séparées par un trait fin, le tout dans une carte sur la toile
/// teintée. Une liste de `ListTile` nus posés sur le fond ne sépare rien —
/// « Mes commandes » et « Paramètres » s'y valent visuellement, et l'œil ne
/// sait pas par où entrer.
///
/// Partagé par le profil client et le compte fournisseur : deux écrans qui
/// répondent à la même question (« où est ce que je cherche ? ») doivent se
/// ressembler.
class MtcMenuSection extends StatelessWidget {
  const MtcMenuSection({super.key, this.title, required this.children});

  /// Absent pour une section isolée, qui n'a pas besoin d'être nommée.
  final String? title;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xs,
              0,
              AppSpacing.xs,
              AppSpacing.sm,
            ),
            child: Text(
              title!,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
                letterSpacing: 0.4,
              ),
            ),
          ),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  // Le trait part après l'icône, comme dans les réglages du
                  // système : il sépare les libellés sans couper la colonne
                  // d'icônes, qui reste lisible comme un tout.
                  Divider(
                    height: 1,
                    indent: AppSpacing.md + _MtcMenuIcon.size + AppSpacing.md,
                    color: scheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Une entrée de menu : icône dans une pastille teintée, libellé, ligne
/// d'explication, chevron.
///
/// Le **sous-titre** est ce qui distingue un menu qu'on parcourt d'un menu
/// qu'on devine. « Mes commandes » dit où l'on va ; « Suivre et retrouver vos
/// achats » dit pourquoi on y irait.
class MtcMenuTile extends StatelessWidget {
  const MtcMenuTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.badge,
    this.danger = false,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  /// Un compteur à poser sur l'icône (messages non lus, notifications).
  /// Reçoit l'icône déjà dessinée et l'enveloppe — c'est la forme
  /// d'`AnimatedCountBadge`.
  final Widget Function(Widget icon)? badge;

  /// Pour les gestes qui détruisent : suppression du compte, déconnexion.
  final bool danger;

  /// Remplace le chevron — un interrupteur, une valeur affichée.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final accent = danger ? scheme.error : scheme.primary;

    Widget pastille = _MtcMenuIcon(
      icon: icon,
      color: accent,
      background: danger ? scheme.errorContainer : scheme.primaryContainer,
    );
    if (badge != null) pastille = badge!(pastille);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + AppSpacing.xs,
        ),
        child: Row(
          children: [
            pastille,
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: danger ? scheme.error : null,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            trailing ??
                (onTap == null
                    ? const SizedBox.shrink()
                    : Icon(
                        Icons.chevron_right_rounded,
                        color: scheme.onSurfaceVariant,
                      )),
          ],
        ),
      ),
    );
  }
}

class _MtcMenuIcon extends StatelessWidget {
  const _MtcMenuIcon({
    required this.icon,
    required this.color,
    required this.background,
  });

  static const double size = 40;

  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm + 4),
      ),
      child: Icon(icon, size: 22, color: color),
    );
  }
}
