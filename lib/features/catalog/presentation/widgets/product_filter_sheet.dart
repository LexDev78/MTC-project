import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';

import '../../domain/entities/product_category.dart';
import '../providers/catalog_providers.dart';

/// Opens the filter/sort bottom sheet for [supplierType]'s catalog tab.
Future<void> showProductFilterSheet(
  BuildContext context, {
  required SupplierType supplierType,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppSpacing.radiusLg),
      ),
    ),
    builder: (context) => ProductFilterSheet(supplierType: supplierType),
  );
}

class ProductFilterSheet extends ConsumerStatefulWidget {
  const ProductFilterSheet({super.key, required this.supplierType});

  final SupplierType supplierType;

  @override
  ConsumerState<ProductFilterSheet> createState() => _ProductFilterSheetState();
}

class _ProductFilterSheetState extends ConsumerState<ProductFilterSheet> {
  late ProductSortOption _sort = ref.read(
    catalogSortProvider(widget.supplierType),
  );
  late final Set<String> _sizes = {
    ...ref.read(catalogSelectedSizesProvider(widget.supplierType)),
  };
  late final Set<String> _colors = {
    ...ref.read(catalogSelectedColorsProvider(widget.supplierType)),
  };
  late final Set<ProductRegion> _regions = {
    ...ref.read(catalogSelectedRegionsProvider(widget.supplierType)),
  };
  int? _minPrice;
  int? _maxPrice;
  bool _pricesInitialized = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final boundsAsync = ref.watch(
      catalogPriceBoundsProvider(widget.supplierType),
    );
    final availableSizesAsync = ref.watch(
      catalogAvailableSizesProvider(widget.supplierType),
    );
    final availableColorsAsync = ref.watch(
      catalogAvailableColorsProvider(widget.supplierType),
    );

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.md,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Filtrer & trier',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _sort = ProductSortOption.relevance;
                      _minPrice = null;
                      _maxPrice = null;
                      _sizes.clear();
                      _colors.clear();
                      _regions.clear();
                    }),
                    child: const Text('Réinitialiser'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text('Trier par', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final option in ProductSortOption.values)
                    ChoiceChip(
                      label: Text(option.label),
                      selected: _sort == option,
                      onSelected: (_) => setState(() => _sort = option),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Prix (FCFA)',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              boundsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, _) => const SizedBox.shrink(),
                data: (bounds) {
                  final (boundMin, boundMax) = bounds;
                  if (boundMin >= boundMax) return const SizedBox.shrink();
                  if (!_pricesInitialized) {
                    _minPrice ??= ref.read(
                      catalogMinPriceProvider(widget.supplierType),
                    );
                    _maxPrice ??= ref.read(
                      catalogMaxPriceProvider(widget.supplierType),
                    );
                    _pricesInitialized = true;
                  }
                  final currentMin = (_minPrice ?? boundMin).clamp(
                    boundMin,
                    boundMax,
                  );
                  final currentMax = (_maxPrice ?? boundMax).clamp(
                    boundMin,
                    boundMax,
                  );
                  final values = RangeValues(
                    currentMin.toDouble(),
                    currentMax.toDouble(),
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            CurrencyText(currentMin),
                            CurrencyText(currentMax),
                          ],
                        ),
                      ),
                      RangeSlider(
                        min: boundMin.toDouble(),
                        max: boundMax.toDouble(),
                        values: values,
                        divisions: 20,
                        labels: RangeLabels('$currentMin', '$currentMax'),
                        onChanged: (range) => setState(() {
                          _minPrice = range.start.round();
                          _maxPrice = range.end.round();
                        }),
                      ),
                    ],
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.lg),
                child: _MultiSelectSection<ProductRegion>(
                  label: 'Région',
                  options: ProductRegion.values,
                  optionLabel: (region) => region.label,
                  selected: _regions,
                  onToggle: (value) => setState(
                    () => _regions.contains(value)
                        ? _regions.remove(value)
                        : _regions.add(value),
                  ),
                ),
              ),
              availableColorsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (colors) => colors.isEmpty
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.lg),
                        child: _MultiSelectSection(
                          label: 'Couleur',
                          options: colors,
                          selected: _colors,
                          onToggle: (value) => setState(
                            () => _colors.contains(value)
                                ? _colors.remove(value)
                                : _colors.add(value),
                          ),
                        ),
                      ),
              ),
              availableSizesAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (sizes) => sizes.isEmpty
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.lg),
                        child: _MultiSelectSection(
                          label: 'Taille',
                          options: sizes,
                          selected: _sizes,
                          onToggle: (value) => setState(
                            () => _sizes.contains(value)
                                ? _sizes.remove(value)
                                : _sizes.add(value),
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: AppSpacing.md),
              MtcPrimaryButton(
                label: 'Appliquer',
                onPressed: () {
                  ref
                          .read(
                            catalogSortProvider(widget.supplierType).notifier,
                          )
                          .state =
                      _sort;
                  ref
                          .read(
                            catalogMinPriceProvider(
                              widget.supplierType,
                            ).notifier,
                          )
                          .state =
                      _minPrice;
                  ref
                          .read(
                            catalogMaxPriceProvider(
                              widget.supplierType,
                            ).notifier,
                          )
                          .state =
                      _maxPrice;
                  ref
                      .read(
                        catalogSelectedSizesProvider(
                          widget.supplierType,
                        ).notifier,
                      )
                      .state = {
                    ..._sizes,
                  };
                  ref
                      .read(
                        catalogSelectedColorsProvider(
                          widget.supplierType,
                        ).notifier,
                      )
                      .state = {
                    ..._colors,
                  };
                  ref
                      .read(
                        catalogSelectedRegionsProvider(
                          widget.supplierType,
                        ).notifier,
                      )
                      .state = {
                    ..._regions,
                  };
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A "Couleur"/"Taille"/"Région" multi-select block — a product matches if
/// it has *any* of the checked values on that axis. Generic over [T] so it
/// covers both free-form string axes (colors/sizes) and fixed enum axes
/// (region), with [optionLabel] deciding how each value is displayed.
class _MultiSelectSection<T> extends StatelessWidget {
  const _MultiSelectSection({
    required this.label,
    required this.options,
    required this.selected,
    required this.onToggle,
    this.optionLabel,
  });

  final String label;
  final List<T> options;
  final Set<T> selected;
  final void Function(T value) onToggle;

  /// Defaults to `toString()` — fine for plain strings (colors/sizes),
  /// overridden for enums that need a human-readable label.
  final String Function(T value)? optionLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final option in options)
              FilterChip(
                label: Text(optionLabel?.call(option) ?? option.toString()),
                selected: selected.contains(option),
                onSelected: (_) => onToggle(option),
              ),
          ],
        ),
      ],
    );
  }
}
