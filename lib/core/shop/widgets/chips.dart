import 'package:flutter/material.dart';

import '../shop_icons.dart';
import '../shop_tokens.dart';

/// La pastille arrondie du kit : catégories de l'accueil (`CategoryBtn`),
/// modes de paiement, filtres. Pleine et violette quand elle est choisie,
/// cerclée sinon.
class ShopPill extends StatelessWidget {
  const ShopPill({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
    this.icon,
    this.large = false,
  });

  final String label;
  final bool active;
  final VoidCallback? onTap;

  /// Une icône du kit (`ShopIcons`), à gauche du libellé.
  final String? icon;

  /// Les pastilles de paiement sont plus grandes que celles des catégories
  /// (texte 16 au lieu de 12), à hauteur égale.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final couleur = active ? Colors.white : scheme.onSurface;
    return Semantics(
      button: true,
      selected: active,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(30)),
        child: AnimatedContainer(
          duration: ShopSizes.duration,
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: ShopSizes.padding),
          decoration: BoxDecoration(
            color: active ? ShopColors.primary : Colors.transparent,
            border: Border.all(
              color: active ? Colors.transparent : scheme.outline,
              width: large ? 1.5 : 1,
            ),
            borderRadius: const BorderRadius.all(Radius.circular(30)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                ShopIcon(icon!, size: 20, color: couleur),
                const SizedBox(width: ShopSizes.padding / 2),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: large ? 16 : 12,
                  fontWeight: FontWeight.w500,
                  color: couleur,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Une rangée de pastilles qui défile, aux marges du kit.
class ShopPillRow extends StatelessWidget {
  const ShopPillRow({
    super.key,
    required this.children,
    this.padding = ShopSizes.padding,
  });

  final List<Widget> children;

  /// Marge des bords ; 32 sur les écrans issus des maquettes.
  final double padding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: padding),
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: ShopSizes.padding / 2),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Deux boutons côte à côte dont un est actif — « Filtrer / Trier » des
/// maquettes de recherche (`OutlinedActiveButton` du kit).
class ShopSegmentedButtons extends StatelessWidget {
  const ShopSegmentedButtons({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: ShopSizes.padding),
          Expanded(
            child: OutlinedButton(
              onPressed: () => onChanged(i),
              style: i == selected
                  ? OutlinedButton.styleFrom(
                      backgroundColor: ShopColors.primary,
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.transparent),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    )
                  : OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
              child: Text(
                labels[i],
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Le tri au-dessus d'une liste (« ⇅ Les plus récents ⌄ », maquette
/// « Reviews ») : il ouvre le choix, il ne trie pas lui-même.
class ShopSortButton extends StatelessWidget {
  const ShopSortButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final encre = Theme.of(context).colorScheme.onSurface;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ShopSizes.radius),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: ShopSizes.padding / 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShopIcon(ShopIcons.sort, color: encre),
            const SizedBox(width: ShopSizes.padding / 2),
            Text(label, style: TextStyle(color: encre, fontSize: 16)),
            const SizedBox(width: ShopSizes.padding / 2),
            ShopIcon(ShopIcons.miniDown, color: encre),
          ],
        ),
      ),
    );
  }
}
