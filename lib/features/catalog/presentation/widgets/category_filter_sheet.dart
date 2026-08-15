import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';

import '../../domain/entities/product_category.dart';
import '../providers/catalog_providers.dart';

/// Opens the filter/sort bottom sheet for [category]'s product list on the
/// Catalogue tab. Deliberately a lighter version of `ProductFilterSheet`
/// (sort + price only, no size/color/région) — those axes are keyed per
/// `SupplierType` there, which Catalogue's combined-across-suppliers view
/// has no equivalent of.
Future<void> showCategoryFilterSheet(
  BuildContext context, {
  required ProductCategory category,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
    ),
    builder: (context) => CategoryFilterSheet(category: category),
  );
}

class CategoryFilterSheet extends ConsumerStatefulWidget {
  const CategoryFilterSheet({super.key, required this.category});

  final ProductCategory category;

  @override
  ConsumerState<CategoryFilterSheet> createState() => _CategoryFilterSheetState();
}

class _CategoryFilterSheetState extends ConsumerState<CategoryFilterSheet> {
  late ProductSortOption _sort = ref.read(categorySortProvider(widget.category));
  int? _minPrice;
  int? _maxPrice;
  bool _pricesInitialized = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final boundsAsync = ref.watch(categoryPriceBoundsProvider(widget.category));

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
              Text('Prix (FCFA)', style: Theme.of(context).textTheme.titleSmall),
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
                    _minPrice ??= ref.read(categoryMinPriceProvider(widget.category));
                    _maxPrice ??= ref.read(categoryMaxPriceProvider(widget.category));
                    _pricesInitialized = true;
                  }
                  final currentMin = (_minPrice ?? boundMin).clamp(boundMin, boundMax);
                  final currentMax = (_maxPrice ?? boundMax).clamp(boundMin, boundMax);
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
              const SizedBox(height: AppSpacing.md),
              MtcPrimaryButton(
                label: 'Appliquer',
                onPressed: () {
                  ref.read(categorySortProvider(widget.category).notifier).state =
                      _sort;
                  ref.read(categoryMinPriceProvider(widget.category).notifier).state =
                      _minPrice;
                  ref.read(categoryMaxPriceProvider(widget.category).notifier).state =
                      _maxPrice;
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
