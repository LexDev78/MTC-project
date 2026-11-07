import 'package:flutter/material.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/utils/search_text.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';

import '../../domain/entities/product.dart';

/// Choisir des produits dans un catalogue qui peut en compter cent.
///
/// La première version du sélecteur de codes promo affichait **tous** les
/// produits en pastilles, d'un coup, au milieu d'un formulaire. Avec une
/// dizaine d'articles c'est agréable ; avec cent, c'est un mur qu'on
/// parcourt au doigt en espérant reconnaître un nom.
///
/// Trois règles tiennent cet écran :
///
///  * les produits **sélectionnés** restent toujours visibles, quelle que
///    soit la recherche — sinon on ne pourrait plus en retirer un qui ne
///    correspond pas à ce qu'on vient de taper ;
///  * le reste est filtré, et plafonné : au-delà, on invite à préciser
///    plutôt que de dérouler une liste que personne ne lira ;
///  * « tout sélectionner » existe, parce que « tous mes produits » est le
///    cas le plus courant et qu'il ne doit pas demander cent gestes.
class ProductMultiPicker extends StatefulWidget {
  const ProductMultiPicker({
    super.key,
    required this.products,
    required this.selected,
    required this.onChanged,
    this.emptyMeansAll = true,
  });

  final List<Product> products;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  /// Si vrai, ne rien sélectionner signifie « tous les produits » — la
  /// convention des codes promo (`0071`). L'intitulé affiché en dépend : il
  /// serait faux d'annoncer « aucun produit » là où la base comprend
  /// « tous ».
  final bool emptyMeansAll;

  @override
  State<ProductMultiPicker> createState() => _ProductMultiPickerState();
}

class _ProductMultiPickerState extends State<ProductMultiPicker> {
  final _searchController = TextEditingController();
  String _query = '';

  /// Au-delà, on n'affiche plus : on demande de préciser. Trente pastilles
  /// remplissent déjà un écran de téléphone.
  static const _maxVisible = 30;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggle(String productId, bool selected) {
    final next = {...widget.selected};
    if (selected) {
      next.add(productId);
    } else {
      next.remove(productId);
    }
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = [
      for (final p in widget.products)
        if (widget.selected.contains(p.id)) p,
    ];
    final matching = [
      for (final p in widget.products)
        if (!widget.selected.contains(p.id) &&
            matchesAnySearch([p.name, p.description], _query))
          p,
    ];
    final visible = matching.take(_maxVisible).toList();
    final hidden = matching.length - visible.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MtcTextField(
          controller: _searchController,
          label: 'Rechercher un produit',
          prefixIcon: Icons.search_rounded,
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: Text(
                _summary(selected.length),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            if (widget.selected.isEmpty)
              TextButton(
                onPressed: widget.products.isEmpty
                    ? null
                    : () => widget.onChanged({
                        for (final p in widget.products) p.id,
                      }),
                child: const Text('Tout sélectionner'),
              )
            else
              TextButton(
                onPressed: () => widget.onChanged(const {}),
                child: const Text('Tout effacer'),
              ),
          ],
        ),
        if (selected.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          // Toujours visibles, filtre ou pas : c'est le seul endroit d'où
          // l'on peut retirer un produit déjà choisi.
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final product in selected)
                InputChip(
                  label: Text(product.name, overflow: TextOverflow.ellipsis),
                  selected: true,
                  onDeleted: () => _toggle(product.id, false),
                  onPressed: () => _toggle(product.id, false),
                ),
            ],
          ),
          const Divider(height: AppSpacing.lg),
        ],
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Text(
              widget.products.isEmpty
                  ? 'Vous n\'avez pas encore de produit.'
                  : _query.isEmpty
                  ? 'Tous vos produits sont sélectionnés.'
                  : 'Aucun produit ne correspond à « $_query ».',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          )
        else
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final product in visible)
                FilterChip(
                  label: Text(product.name, overflow: TextOverflow.ellipsis),
                  selected: false,
                  onSelected: (_) => _toggle(product.id, true),
                ),
            ],
          ),
        if (hidden > 0)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              '… et $hidden autre${hidden > 1 ? 's' : ''}. '
              'Précisez votre recherche pour les voir.',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }

  String _summary(int count) {
    if (count == 0) {
      return widget.emptyMeansAll
          ? 'Valable sur tous vos produits. Touchez un produit pour le restreindre.'
          : 'Aucun produit sélectionné.';
    }
    return '$count produit${count > 1 ? 's' : ''} '
        'sélectionné${count > 1 ? 's' : ''}.';
  }
}
