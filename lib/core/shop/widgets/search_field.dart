import 'package:flutter/material.dart';

import 'package:mtc_app/core/utils/search_text.dart';

import '../shop_icons.dart';
import '../shop_tokens.dart';

/// Le champ de recherche du kit (`SearchForm`) : cerclé plutôt que rempli,
/// loupe à gauche, filtre à droite derrière un trait.
///
/// [onTap] sans [controller] : un faux champ qui ouvre l'écran de
/// recherche (découverte, en-têtes de catégorie).
class ShopSearchField extends StatelessWidget {
  const ShopSearchField({
    super.key,
    this.hintText = 'Rechercher…',
    this.controller,
    this.focusNode,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.onFilterTap,
    this.filterActive = false,
    this.filterTooltip = 'Filtrer et trier',
  });

  final String hintText;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final VoidCallback? onFilterTap;

  /// Un point sur l'icône de filtre quand un filtre est posé.
  final bool filterActive;

  /// Ce que le bouton de filtre annonce : « Filtrer » seul là où rien ne
  /// se trie.
  final String filterTooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final traitFin = OutlineInputBorder(
      borderRadius: BorderRadius.circular(ShopSizes.radius),
      borderSide: BorderSide(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
      ),
    );
    final filtre = onFilterTap;
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      readOnly: onTap != null && controller == null,
      onTap: onTap,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hintText,
        filled: false,
        border: traitFin,
        enabledBorder: traitFin,
        prefixIcon: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: ShopIcon(
            ShopIcons.search,
            color: theme.iconTheme.color?.withValues(alpha: 0.3),
          ),
        ),
        suffixIcon: filtre == null
            ? null
            : SizedBox(
                width: 48,
                child: Row(
                  children: [
                    const SizedBox(
                      height: 24,
                      child: VerticalDivider(width: 1),
                    ),
                    Expanded(
                      child: IconButton(
                        onPressed: filtre,
                        tooltip: filterTooltip,
                        icon: Badge(
                          isLabelVisible: filterActive,
                          smallSize: 8,
                          backgroundColor: ShopColors.primary,
                          child: const ShopIcon(ShopIcons.filter),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

/// Une ligne de recherche (maquettes « Search » et « History » du kit) :
/// l'horloge des récentes, le texte, la croix qui l'efface, un trait.
///
/// Avec [highlight], la partie qui correspond à ce qu'on tape est à
/// l'encre, le reste estompé — accents et casse mis de côté.
class SearchHistoryTile extends StatelessWidget {
  const SearchHistoryTile({
    super.key,
    required this.text,
    this.highlight,
    this.showClock = true,
    this.onTap,
    this.onRemove,
    this.showDivider = true,
  });

  final String text;
  final String? highlight;
  final bool showClock;
  final VoidCallback? onTap;

  /// `null` : pas de croix (une suggestion tirée du catalogue).
  final VoidCallback? onRemove;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final encre = theme.colorScheme.onSurface;
    final estompe = encre.withValues(alpha: 0.3);
    final style = TextStyle(fontSize: 16, color: encre);
    final trouve = highlight == null
        ? null
        : searchMatchRange(text, highlight!);
    final libelle = trouve == null
        ? Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style)
        : Text.rich(
            TextSpan(
              style: style.copyWith(color: estompe),
              children: [
                TextSpan(text: text.substring(0, trouve.$1)),
                TextSpan(
                  text: text.substring(trouve.$1, trouve.$2),
                  style: TextStyle(color: encre),
                ),
                TextSpan(text: text.substring(trouve.$2)),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
    final croix = onRemove;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                if (showClock) ...[
                  ShopIcon(ShopIcons.clock, color: estompe),
                  const SizedBox(width: ShopSizes.padding),
                ],
                Expanded(child: libelle),
                if (croix != null)
                  IconButton(
                    tooltip: 'Effacer « $text »',
                    onPressed: croix,
                    icon: ShopIcon(
                      ShopIcons.close,
                      size: 20,
                      color: theme.iconTheme.color?.withValues(alpha: 0.3),
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
