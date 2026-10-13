import 'package:mtc_app/app/router/app_routes.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/core/widgets/core_widgets.dart';
import 'package:mtc_app/features/favorites/presentation/widgets/favorite_toggle_button.dart';
import 'package:mtc_app/features/recommendations/domain/repositories/recommendation_repository.dart';
import 'package:mtc_app/features/recommendations/presentation/providers/recommendation_providers.dart';

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

  /// Lu une fois ici : `dispose` journalise la dernière recherche, et `ref`
  /// n'y est plus utilisable.
  late final RecommendationRepository _recommendations;
  String _lastLoggedQuery = '';

  @override
  void initState() {
    super.initState();
    _recommendations = ref.read(recommendationRepositoryProvider);
  }

  @override
  void dispose() {
    _logQuery();
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Une recherche est journalisée quand elle est validée ou quand le client
  /// quitte l'écran avec — pas à chaque pause de frappe, qui enregistrerait
  /// « bog », « bogo », « bogolan » comme trois intentions.
  void _logQuery() {
    final query = _controller.text.trim();
    if (query.isEmpty || query == _lastLoggedQuery) return;
    _lastLoggedQuery = query;
    unawaited(_recommendations.logSearch(query));
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
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _logQuery(),
        ),
        actions: [
          // Posé ici parce que c'est là qu'on arrive en ne sachant pas quoi
          // taper : chercher par photo est le recours quand le mot manque.
          IconButton(
            icon: const Icon(Icons.photo_camera_outlined),
            tooltip: 'Rechercher par photo',
            onPressed: () => context.push(AppRoutes.clientVisualSearch),
          ),
        ],
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
