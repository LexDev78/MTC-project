import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';
import 'package:mtc_app/features/favorites/presentation/widgets/favorite_toggle_button.dart';

import '../../domain/entities/product.dart';
import '../../domain/entities/product_category.dart';
import '../providers/catalog_providers.dart';
import '../widgets/product_card.dart' show ProductCard, ProductCategoryIcon;
import '../widgets/product_grid.dart';

/// Body of one of the two isolated catalog tabs (Fournisseurs tiers /
/// Fournisseur principal). Parameterized by [supplierType] so both tabs
/// reuse the same widget while keeping fully separate provider state. The
/// filter entry point lives one level up, alongside the category dropdown
/// in `ClientHomeScreen`'s header row (see `_FilterIconButton` there), so
/// it stays visually aligned with it instead of floating in each tab body.
///
/// Two display modes, driven by the same [catalogCategoryProvider] the
/// header's category dropdown writes to:
/// - no category selected → products grouped into vertically-stacked
///   per-category sections, each scrolling horizontally (see
///   [_CategorySections]);
/// - a category selected (from the dropdown, or by tapping a section
///   header below) → the flat 2-column grid, already filtered to just
///   that category by `productListProvider`.
class CatalogTabScreen extends ConsumerWidget {
  const CatalogTabScreen({super.key, required this.supplierType});

  final SupplierType supplierType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productListProvider(supplierType));
    final selectedCategory = ref.watch(catalogCategoryProvider(supplierType));

    return AsyncValueWidget(
      value: productsAsync,
      data: (products) {
        if (products.isEmpty) {
          return const MtcEmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'Aucun produit pour le moment',
          );
        }
        if (selectedCategory == null) {
          return _CategorySections(products: products, supplierType: supplierType);
        }
        return ProductGrid(
          products: products,
          cardOverlayBuilder: (product) => FavoriteToggleButton(
            productId: product.id,
            size: 20,
            inactiveColor: Colors.white,
          ),
        );
      },
    );
  }
}

/// Groups [products] by [ProductCategory] into one section per category —
/// in enum order, skipping categories with no matching product — each a
/// tappable header (jumps into that category's flat grid, by writing to
/// [catalogCategoryProvider]) above a horizontally-scrolling row of cards.
class _CategorySections extends ConsumerWidget {
  const _CategorySections({required this.products, required this.supplierType});

  final List<Product> products;
  final SupplierType supplierType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final byCategory = <ProductCategory, List<Product>>{};
    for (final product in products) {
      (byCategory[product.category] ??= []).add(product);
    }

    final sections = [
      for (final category in ProductCategory.values)
        if (byCategory[category] case final items? when items.isNotEmpty)
          (category, items),
    ];

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      itemCount: sections.length,
      itemBuilder: (context, index) {
        final (category, items) = sections[index];
        return _CategorySection(
          category: category,
          products: items,
          onHeaderTap: () => ref
              .read(catalogCategoryProvider(supplierType).notifier)
              .state = category,
        );
      },
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.category,
    required this.products,
    required this.onHeaderTap,
  });

  final ProductCategory category;
  final List<Product> products;
  final VoidCallback onHeaderTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onHeaderTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Icon(category.icon, size: 18, color: scheme.primary),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    category.label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  'Voir tout',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: scheme.primary),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: scheme.primary,
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          height: 270,
          child: _AutoScrollingProductRow(products: products),
        ),
      ],
    );
  }
}

/// A horizontally-scrolling row of product cards that idly auto-advances —
/// same "auto-scroll until the user actually touches it" idiom as
/// `PromoHeroBanner`'s carousel and the product-detail photo strip. Manual
/// drags cancel the timer immediately and restart it once the user lets go,
/// so it never fights a scroll the user is actively performing.
class _AutoScrollingProductRow extends StatefulWidget {
  const _AutoScrollingProductRow({required this.products});

  final List<Product> products;

  @override
  State<_AutoScrollingProductRow> createState() =>
      _AutoScrollingProductRowState();
}

class _AutoScrollingProductRowState extends State<_AutoScrollingProductRow> {
  static const _cardWidth = 150.0;
  static const _cardGap = AppSpacing.md;

  final _scrollController = ScrollController();
  Timer? _autoScrollTimer;

  @override
  void initState() {
    super.initState();
    if (widget.products.length > 1) _startAutoScroll();
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_scrollController.hasClients) return;
      final maxExtent = _scrollController.position.maxScrollExtent;
      if (maxExtent <= 0) return;
      final next = _scrollController.offset + _cardWidth + _cardGap;
      _scrollController.animateTo(
        next > maxExtent ? 0 : next,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification &&
            notification.dragDetails != null) {
          _autoScrollTimer?.cancel();
        } else if (notification is ScrollEndNotification &&
            notification.dragDetails != null) {
          _startAutoScroll();
        }
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: widget.products.length,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(right: _cardGap),
          child: SizedBox(
            width: _cardWidth,
            child: FadeSlideIn(
              index: index,
              child: ProductCard(
                product: widget.products[index],
                overlay: FavoriteToggleButton(
                  productId: widget.products[index].id,
                  size: 20,
                  inactiveColor: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
