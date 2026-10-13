import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/features/catalog/domain/entities/product.dart';
import 'package:mtc_app/features/catalog/presentation/providers/catalog_providers.dart';

import '../../data/supabase_visual_search_datasource.dart';

final visualSearchDatasourceProvider = Provider<SupabaseVisualSearchDatasource>(
  (ref) => SupabaseVisualSearchDatasource(ref.watch(supabaseClientProvider)),
);

/// L'état de l'écran de recherche par photo.
///
/// `null` tant qu'aucune photo n'a été envoyée : l'écran montre alors
/// l'invitation, et non une liste vide qui se lirait comme « aucun
/// résultat ».
final visualSearchProvider =
    AsyncNotifierProvider<VisualSearchController, VisualSearchState?>(
      VisualSearchController.new,
    );

class VisualSearchState {
  const VisualSearchState({required this.products, required this.remaining});

  final List<Product> products;
  final int remaining;
}

class VisualSearchController extends AsyncNotifier<VisualSearchState?> {
  @override
  Future<VisualSearchState?> build() async => null;

  Future<void> search({
    required Uint8List imageBytes,
    required String contentType,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final result = await ref
          .read(visualSearchDatasourceProvider)
          .search(imageBytes: imageBytes, contentType: contentType);

      // Les produits sont résolus par la lecture habituelle du catalogue :
      // elle applique la RLS et les règles d'affichage, donc un produit
      // devenu invisible entre l'indexation et la recherche s'écarte tout
      // seul. L'ordre de la recherche est conservé — c'est lui qui porte la
      // ressemblance.
      final repository = ref.read(productRepositoryProvider);
      final produits = <Product>[];
      for (final match in result.matches) {
        try {
          produits.add(await repository.getById(match.productId));
        } catch (_) {
          // Produit disparu entre-temps : on l'ignore plutôt que de faire
          // échouer toute la recherche pour une ligne.
        }
      }
      return VisualSearchState(
        products: produits,
        remaining: result.remaining,
      );
    });
  }

  void reset() => state = const AsyncData(null);
}
