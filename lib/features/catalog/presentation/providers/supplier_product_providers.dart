import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/product.dart';
import '../../domain/entities/product_status.dart';
import '../../domain/entities/stock_movement.dart';
import 'catalog_providers.dart';

/// Every one of the operating supplier's own products, regardless of
/// status/verification — see `ProductRepository.watchMyProducts`.
/// `autoDispose`: the underlying datasource re-emits only after a write made
/// through this same client instance (see its doc comment), so a favorite,
/// order, or view logged from someone else's session never reaches an
/// already-open dashboard. Disposing once nothing watches it means the next
/// visit re-subscribes and pulls current `view_count`/etc. from the
/// database instead of replaying a stale cached snapshot indefinitely.
final myProductsProvider = StreamProvider.autoDispose.family<List<Product>, String>((
  ref,
  supplierId,
) {
  return ref.watch(productRepositoryProvider).watchMyProducts(supplierId);
});

final productStockMovementsProvider =
    StreamProvider.family<List<StockMovement>, String>((ref, productId) {
      return ref
          .watch(productRepositoryProvider)
          .watchStockMovements(productId);
    });

/// Search text for "Mes produits", isolated per operating supplier so
/// switching accounts (e.g. in tests) never leaks a stale query.
final myProductsQueryProvider = StateProvider.family<String, String>(
  (ref, supplierId) => '',
);

/// `null` means "every status" — the default view.
final myProductsStatusFilterProvider =
    StateProvider.family<ProductStatus?, String>((ref, supplierId) => null);

final filteredMyProductsProvider =
    Provider.family<AsyncValue<List<Product>>, String>((ref, supplierId) {
      final query = ref
          .watch(myProductsQueryProvider(supplierId))
          .trim()
          .toLowerCase();
      final statusFilter = ref.watch(myProductsStatusFilterProvider(supplierId));

      return ref.watch(myProductsProvider(supplierId)).whenData((products) {
        return products.where((p) {
          if (statusFilter != null && p.status != statusFilter) return false;
          if (query.isEmpty) return true;
          return p.name.toLowerCase().contains(query);
        }).toList();
      });
    });
