import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import 'package:mtc_app/core/shop/shop.dart';
import 'package:mtc_app/core/utils/currency_formatter.dart';

import '../../domain/entities/product.dart';
import '../../domain/entities/product_category.dart';
import '../../domain/product_list_filters.dart';

/// Ouvre « Filtrer / Trier » (maquettes « Filter », « Sort by » et
/// « Size » du kit) sur [products], la liste *avant* filtres : les facettes
/// et la réglette de prix en sont tirées, et ne rétrécissent pas à mesure
/// qu'on filtre.
///
/// Rend les nouveaux réglages, ou `null` quand la feuille est fermée sans
/// « Terminé » — rien n'est appliqué avant : on peut essayer, revenir, et
/// partir sans avoir changé la liste.
///
/// [byCategory] à `false` sur la page d'une catégorie, où l'axe n'a pas de
/// sens.
Future<ProductListFilters?> showProductFilterSheet(
  BuildContext context, {
  required List<Product> products,
  required ProductListFilters current,
  bool byCategory = true,
}) {
  return showShopSheet<ProductListFilters>(
    context,
    heightFactor: 0.85,
    child: ProductFilterSheet(
      products: products,
      initial: current,
      byCategory: byCategory,
    ),
  );
}

enum _Vue { filtres, tri, prix, categories, boutiques }

/// Le contenu de [showProductFilterSheet].
class ProductFilterSheet extends StatefulWidget {
  const ProductFilterSheet({
    super.key,
    required this.products,
    required this.initial,
    this.byCategory = true,
  });

  final List<Product> products;
  final ProductListFilters initial;
  final bool byCategory;

  @override
  State<ProductFilterSheet> createState() => _ProductFilterSheetState();
}

class _ProductFilterSheetState extends State<ProductFilterSheet> {
  late ProductListFilters _filtres = widget.initial;
  _Vue _vue = _Vue.filtres;

  /// Les catégories présentes, avec leur nombre d'articles.
  late final Map<ProductCategory, int> _parCategorie = {
    for (final c in ProductCategory.values)
      if (widget.products.where((p) => p.category == c).length case final n
          when n > 0)
        c: n,
  };

  /// Les boutiques présentes, par nom, avec leur nombre d'articles.
  late final List<({String id, String nom, int nombre})> _boutiques = [
    for (final groupe in groupBy(
      widget.products,
      (Product p) => p.supplierId,
    ).entries)
      (
        id: groupe.key,
        nom: groupe.value.first.supplierName,
        nombre: groupe.value.length,
      ),
  ]..sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));

  late final (int, int)? _bornes = displayedPriceBounds(widget.products);

  bool get _sousVue =>
      _vue == _Vue.prix || _vue == _Vue.categories || _vue == _Vue.boutiques;

  /// Dans une sous-feuille, efface son seul axe ; ailleurs, tout.
  void _effacer() => setState(() {
    _filtres = switch (_vue) {
      _Vue.prix => _filtres.withPriceRange(null, null),
      _Vue.categories => _filtres.copyWith(categories: const {}),
      _Vue.boutiques => _filtres.copyWith(supplierIds: const {}),
      _Vue.filtres || _Vue.tri => const ProductListFilters(),
    };
  });

  String get _resumePrix {
    final bas = _filtres.minPriceFcfa;
    final haut = _filtres.maxPriceFcfa;
    if (bas == null && haut == null) return 'Tous';
    String f(int? v) =>
        v == null ? '…' : CurrencyFormatter.formatFcfaCompact(v);
    return '${f(bas)} – ${f(haut)}';
  }

  String _resume<T>(Set<T> choisis, String Function(T) libelle) {
    if (choisis.isEmpty) return 'Toutes';
    if (choisis.length == 1) return libelle(choisis.single);
    return '${choisis.length} choisies';
  }

  @override
  Widget build(BuildContext context) {
    final titre = switch (_vue) {
      _Vue.filtres => 'Filtrer',
      _Vue.tri => 'Trier par',
      _Vue.prix => 'Prix',
      _Vue.categories => 'Catégorie',
      _Vue.boutiques => 'Boutique',
    };
    final nomsBoutiques = {for (final b in _boutiques) b.id: b.nom};

    return Scaffold(
      body: Column(
        children: [
          SheetHeader(
            title: titre,
            onBack: _sousVue ? () => setState(() => _vue = _Vue.filtres) : null,
            actionLabel: 'Tout effacer',
            onAction: _effacer,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: ShopSizes.screenMargin,
              ),
              children: [
                if (!_sousVue) ...[
                  const SizedBox(height: ShopSizes.padding / 2),
                  ShopSegmentedButtons(
                    labels: const ['Filtrer', 'Trier'],
                    selected: _vue == _Vue.tri ? 1 : 0,
                    onChanged: (i) =>
                        setState(() => _vue = i == 1 ? _Vue.tri : _Vue.filtres),
                  ),
                  const SizedBox(height: ShopSizes.padding / 2),
                ],
                ...switch (_vue) {
                  _Vue.filtres => [
                    if (widget.byCategory && _parCategorie.length > 1)
                      ChevronListTile(
                        title: 'Catégorie',
                        fontSize: 16,
                        trailingText: _resume(
                          _filtres.categories,
                          (c) => c.label,
                        ),
                        contentPadding: EdgeInsets.zero,
                        onTap: () => setState(() => _vue = _Vue.categories),
                      ),
                    if (_boutiques.length > 1)
                      ChevronListTile(
                        title: 'Boutique',
                        fontSize: 16,
                        trailingText: _resume(
                          _filtres.supplierIds,
                          (id) => nomsBoutiques[id] ?? '1 choisie',
                        ),
                        contentPadding: EdgeInsets.zero,
                        onTap: () => setState(() => _vue = _Vue.boutiques),
                      ),
                    ChevronListTile(
                      title: 'Prix',
                      fontSize: 16,
                      trailingText: _resumePrix,
                      contentPadding: EdgeInsets.zero,
                      onTap: () => setState(() => _vue = _Vue.prix),
                    ),
                    ShopCheckboxTile(
                      title: 'En stock uniquement',
                      value: _filtres.inStockOnly,
                      onChanged: (v) => setState(
                        () => _filtres = _filtres.copyWith(
                          inStockOnly: v ?? false,
                        ),
                      ),
                    ),
                  ],
                  _Vue.tri => [
                    for (final option in ProductSortOption.values)
                      ShopRadioTile<ProductSortOption>(
                        title: option.label,
                        value: option,
                        groupValue: _filtres.sort,
                        onChanged: (v) => setState(
                          () => _filtres = _filtres.copyWith(sort: v),
                        ),
                      ),
                  ],
                  _Vue.categories => [
                    for (final MapEntry(key: c, value: n)
                        in _parCategorie.entries)
                      ShopCheckboxTile(
                        title: c.label,
                        count: n,
                        value: _filtres.categories.contains(c),
                        onChanged: (v) => setState(
                          () => _filtres = _filtres.copyWith(
                            categories: _bascule(_filtres.categories, c, v),
                          ),
                        ),
                      ),
                  ],
                  _Vue.boutiques => [
                    for (final b in _boutiques)
                      ShopCheckboxTile(
                        title: b.nom,
                        count: b.nombre,
                        value: _filtres.supplierIds.contains(b.id),
                        onChanged: (v) => setState(
                          () => _filtres = _filtres.copyWith(
                            supplierIds: _bascule(
                              _filtres.supplierIds,
                              b.id,
                              v,
                            ),
                          ),
                        ),
                      ),
                  ],
                  _Vue.prix => [
                    _ReglettePrix(
                      bornes: _bornes,
                      min: _filtres.minPriceFcfa,
                      max: _filtres.maxPriceFcfa,
                      onChanged: (bas, haut) => setState(
                        () => _filtres = _filtres.withPriceRange(bas, haut),
                      ),
                    ),
                  ],
                },
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        label: 'Terminé',
        onPressed: () => Navigator.of(context).pop(_filtres),
      ),
    );
  }

  static Set<T> _bascule<T>(Set<T> ensemble, T valeur, bool? coche) =>
      coche ?? false ? {...ensemble, valeur} : ({...ensemble}..remove(valeur));
}

/// La fourchette de prix, entre le moins cher et le plus cher de la liste,
/// au prix affiché.
class _ReglettePrix extends StatelessWidget {
  const _ReglettePrix({
    required this.bornes,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final (int, int)? bornes;
  final int? min;
  final int? max;

  /// Une borne remise à l'extrémité redevient `null` : « jusqu'au plus
  /// cher » doit suivre le catalogue, pas figer le prix d'aujourd'hui.
  final void Function(int? bas, int? haut) onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = bornes;
    if (b == null || b.$1 >= b.$2) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: ShopSizes.padding),
        child: Text(
          b == null
              ? 'Aucun article à filtrer par prix.'
              : 'Tous les articles sont au même prix.',
          style: theme.textTheme.bodyMedium,
        ),
      );
    }
    final (borneMin, borneMax) = b;
    final bas = (min ?? borneMin).clamp(borneMin, borneMax);
    final haut = (max ?? borneMax).clamp(borneMin, borneMax);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: ShopSizes.padding),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              CurrencyFormatter.formatFcfa(bas),
              style: theme.textTheme.bodyLarge,
            ),
            Text(
              CurrencyFormatter.formatFcfa(haut),
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
        RangeSlider(
          min: borneMin.toDouble(),
          max: borneMax.toDouble(),
          values: RangeValues(bas.toDouble(), haut.toDouble()),
          divisions: 20,
          activeColor: ShopColors.primary,
          onChanged: (plage) {
            final nouveauBas = plage.start.round();
            final nouveauHaut = plage.end.round();
            onChanged(
              nouveauBas <= borneMin ? null : nouveauBas,
              nouveauHaut >= borneMax ? null : nouveauHaut,
            );
          },
        ),
      ],
    );
  }
}
