import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/core/widgets/core_widgets.dart';
import 'package:mtc_app/features/favorites/presentation/widgets/favorite_toggle_button.dart';

import '../providers/catalog_providers.dart';
import '../widgets/product_grid.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Without this, every keystroke tears down the previous Postgres `ilike`
  /// query and fires a new one mid-word — wasted DB load and flickering
  /// results. 300ms is long enough to absorb normal typing speed, short
  /// enough that the results still feel immediate once you pause.
  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(globalSearchQueryProvider.notifier).state = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(globalSearchResultsProvider);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Rechercher un produit, un fournisseur...',
            border: InputBorder.none,
          ),
          onChanged: _onQueryChanged,
        ),
      ),
      body: AsyncValueWidget(
        value: resultsAsync,
        data: (products) {
          if (_controller.text.trim().isEmpty) {
            return const MtcEmptyState(
              icon: Icons.search_rounded,
              title: 'Recherchez parmi tous les produits',
            );
          }
          if (products.isEmpty) {
            return const MtcEmptyState(
              icon: Icons.search_off_rounded,
              title: 'Aucun résultat',
            );
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
      ),
    );
  }
}
