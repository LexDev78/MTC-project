import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mtc_app/core/error/exceptions.dart';
import 'package:mtc_app/core/utils/id_generator.dart';

import '../../domain/entities/product_category.dart';

/// `ProductCategory.textilesBogolan`-style camelCase names don't all equal
/// their snake_case DB value (see `@JsonValue` on the enum,
/// `product_category.dart`, Lot 2) — needed here to push category
/// filtering down into the query rather than fetching everything and
/// filtering in Dart.
String categoryToDb(ProductCategory category) => switch (category) {
  ProductCategory.textilesBogolan => 'textiles_bogolan',
  ProductCategory.artisanat => 'artisanat',
  ProductCategory.electronique => 'electronique',
  ProductCategory.alimentation => 'alimentation',
  ProductCategory.materiauxConstruction => 'materiaux_construction',
  ProductCategory.autre => 'autre',
};

/// Raw `products`/`stock_movements` table I/O — no `Product` entity
/// knowledge here (see `SupabaseProductRepository`, which maps rows
/// to/from the domain entity via `Product.fromJson`/`toJson`, Lot 2).
class SupabaseProductDatasource {
  SupabaseProductDatasource(this._client);

  final SupabaseClient _client;

  /// No Realtime here (out of scope for this lot, see
  /// BACKEND_MIGRATION_PROGRESS.md) — re-fetches on every write made
  /// through this same repository instance, same "notify after mutation"
  /// shape the in-memory datasource used, just backed by a real query.
  final _changes = StreamController<void>.broadcast();
  final _stockMovementChanges = StreamController<void>.broadcast();

  Stream<T> _watch<T>(Future<T> Function() fetch) {
    return Stream<void>.multi((controller) {
      controller.add(null);
      final subscription = _changes.stream.listen(controller.add);
      controller.onCancel = subscription.cancel;
    }, isBroadcast: true).asyncMap((_) => fetch());
  }

  void _notify() => _changes.add(null);

  /// Server-side pushdown of every `ProductRepository.watchProducts` filter
  /// — public catalog visibility (`status = 'active' and
  /// is_supplier_verified = true`) is already enforced by
  /// `products_select_public` RLS, so this only needs the *tab/search*
  /// filters, matching `InMemoryProductRepository.watchProducts` exactly.
  Stream<List<Map<String, dynamic>>> watchProducts({
    String? supplierType,
    ProductCategory? category,
    String? query,
    String? supplierId,
  }) {
    return _watch(() async {
      var builder = _client
          .from('products')
          .select()
          .eq('status', 'active')
          .eq('is_supplier_verified', true);
      if (supplierType == 'tiers') builder = builder.eq('supplier_type', 'tiers');
      if (category != null) builder = builder.eq('category', categoryToDb(category));
      if (supplierId != null) builder = builder.eq('supplier_id', supplierId);
      final normalizedQuery = query?.trim();
      if (normalizedQuery != null && normalizedQuery.isNotEmpty) {
        final escaped = normalizedQuery.replaceAll(',', ' ').replaceAll('%', ' ');
        builder = builder.or(
          'name.ilike.%$escaped%,description.ilike.%$escaped%,supplier_name.ilike.%$escaped%',
        );
      }
      return builder
          .order('rating_average', ascending: false)
          .order('name', ascending: true);
    });
  }

  Future<Map<String, dynamic>> getById(String id) {
    return _client.from('products').select().eq('id', id).single();
  }

  Future<void> updateSupplierRating({
    required String supplierId,
    required double ratingAverage,
    required int ratingCount,
  }) async {
    await _client
        .from('products')
        .update({'rating_average': ratingAverage, 'rating_count': ratingCount})
        .eq('supplier_id', supplierId);
    _notify();
  }

  Stream<List<Map<String, dynamic>>> watchMyProducts(String supplierId) {
    return _watch(
      () => _client
          .from('products')
          .select()
          .eq('supplier_id', supplierId)
          .order('created_at', ascending: false),
    );
  }

  Future<Map<String, dynamic>> add(Map<String, dynamic> row) async {
    final inserted = await _client.from('products').insert(row).select().single();
    _notify();
    return inserted;
  }

  Future<void> update(String id, Map<String, dynamic> fields) async {
    await _client.from('products').update(fields).eq('id', id);
    _notify();
  }

  Future<void> setStatus(String id, String status) async {
    await _client.from('products').update({'status': status}).eq('id', id);
    _notify();
  }

  Future<void> adjustStock({
    required String id,
    required int quantityDelta,
    required String reason,
    String? note,
  }) async {
    final current = await getById(id);
    final currentQuantity = current['stock_quantity'] as int;
    final newQuantity = currentQuantity + quantityDelta;
    if (newQuantity < 0) {
      throw InsufficientStockException(
        'Stock insuffisant pour ${current['name']} : '
        '$currentQuantity disponible(s), ${-quantityDelta} demandé(s).',
      );
    }

    await _client.from('products').update({'stock_quantity': newQuantity}).eq('id', id);
    await _client.from('stock_movements').insert({
      'id': IdGenerator.next(),
      'product_id': id,
      'quantity_delta': quantityDelta,
      'reason': reason,
      'note': note,
    });
    _notify();
    _stockMovementChanges.add(null);
  }

  Stream<List<Map<String, dynamic>>> watchStockMovements(String productId) {
    return Stream<void>.multi((controller) {
      controller.add(null);
      final subscription = _stockMovementChanges.stream.listen(controller.add);
      controller.onCancel = subscription.cancel;
    }, isBroadcast: true).asyncMap(
      (_) => _client
          .from('stock_movements')
          .select()
          .eq('product_id', productId)
          .order('occurred_at', ascending: false),
    );
  }

  Future<void> updateSupplierVerification({
    required String supplierId,
    required bool isVerified,
  }) async {
    await _client
        .from('products')
        .update({'is_supplier_verified': isVerified})
        .eq('supplier_id', supplierId);
    _notify();
  }
}
