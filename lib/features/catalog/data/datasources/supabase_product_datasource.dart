import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mtc_app/core/error/exceptions.dart';
import 'package:mtc_app/core/utils/realtime_retry.dart';

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

  /// Fires the instant a write goes through *this* datasource instance —
  /// covers a supplier seeing their own edit reflected immediately, without
  /// waiting on Realtime's network round-trip. Not enough on its own for a
  /// *different* session (a client browsing while a supplier edits
  /// elsewhere) — see `_productRealtimeTrigger`, merged alongside this in
  /// `watchProducts`/`watchMyProducts`.
  final _changes = StreamController<void>.broadcast();
  final _stockMovementChanges = StreamController<void>.broadcast();

  Stream<T> _watch<T>(Future<T> Function() fetch, {Stream<void>? extraTriggers}) {
    return Stream<void>.multi((controller) {
      controller.add(null);
      final subscriptions = [
        _changes.stream.listen(controller.add),
        if (extraTriggers != null) extraTriggers.listen(controller.add),
      ];
      controller.onCancel = () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      };
    }, isBroadcast: true).asyncMap((_) => fetch());
  }

  void _notify() => _changes.add(null);

  /// Real Postgres Realtime on `products` (`0026_products_realtime.sql`) —
  /// the row payload itself is ignored, this only exists to wake `_watch`'s
  /// `asyncMap` into re-running the real (filtered/nested) query whenever
  /// *any* product row changes, from *any* session. Query-scoped `.eq(...)`
  /// filters aren't applied here on purpose: RLS already limits which rows
  /// a given session's subscription can even see change, and the narrower
  /// filtering (category/search/supplier) still happens in the real fetch
  /// this triggers.
  Stream<void> get _productRealtimeTrigger =>
      withRealtimeRetry(() => _client.from('products').stream(primaryKey: ['id'])).map((_) {});

  /// Only `getById` embeds this — list queries (`watchProducts`,
  /// `watchMyProducts`) stay cheap, the two new scalar aggregate columns
  /// (`has_variants`, `max_price_fcfa`, `variant_count`) ride along for free
  /// on `select()`. Same nested-select shape as
  /// `SupabaseOrderDatasource._nestedSelect`.
  // The `options:product_characteristic_options(...)` embed must name its
  // FK explicitly (`!product_characteristic_options_characteristic_id_fkey`):
  // since `product_variant_options` widened its primary key to
  // (variant_id, characteristic_id, option_id) (`0028_multi_option_variant_options.sql`,
  // for a variant carrying several options of the same characteristic —
  // e.g. sizes S/M/L together), PostgREST also treats it as a valid
  // many-to-many bridge between `product_characteristics` and
  // `product_characteristic_options`, making the direct one-to-many path
  // ambiguous without this.
  /// Les promotions voyagent avec le produit, y compris dans les listes :
  /// une vignette sans son badge de remise afficherait un prix que le
  /// panier démentirait aussitôt. L'imbrication est plate et minuscule, là
  /// où une seconde requête par vignette ne l'aurait pas été.
  static const _listSelect = '*, promotions:product_promotions(*)';

  static const _nestedSelect =
      '*, promotions:product_promotions(*), '
      'characteristics:product_characteristics(*, type:product_characteristic_types(*), '
      'options:product_characteristic_options!product_characteristic_options_characteristic_id_fkey(*)), '
      'variants:product_variants(*, variant_options:product_variant_options(characteristic_id, option_id))';

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
          .select(_listSelect)
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
    }, extraTriggers: _productRealtimeTrigger);
  }

  Future<Map<String, dynamic>> getById(String id) {
    return _client.from('products').select(_nestedSelect).eq('id', id).single();
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
          .select(_listSelect)
          .eq('supplier_id', supplierId)
          .order('created_at', ascending: false),
      extraTriggers: _productRealtimeTrigger,
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

  /// Full replace, not a diff/patch — `VariantManagerPanel.buildDraft`
  /// always sends the complete resulting set (already merged client-side: existing
  /// variant ids are reused where a regenerated combination still matches,
  /// so their stock/price/photos survive; ids not present here are simply
  /// gone after this call).
  ///
  /// RPC rather than direct table writes: this used to be 6 sequential
  /// PostgREST calls (delete variants, delete characteristics, insert
  /// characteristics, insert options, insert variants, insert variant
  /// options), each its own transaction. The first one alone — deleting all
  /// variants — momentarily drops the product to zero variants and commits
  /// that state on its own, which `products_active_requires_variants`
  /// (0021) rejects for an already-`active` product before the later calls
  /// in this same sequence ever get a chance to re-add any. Bundling
  /// everything into `replace_product_characteristics_and_variants`
  /// (`0024_replace_characteristics_variants_rpc.sql`) makes it one
  /// transaction/commit, like `place_order` does for the same class of
  /// problem.
  Future<void> replaceCharacteristicsAndVariants({
    required String productId,
    required List<Map<String, dynamic>> characteristics,
    required List<Map<String, dynamic>> variants,
  }) async {
    await _client.rpc(
      'replace_product_characteristics_and_variants',
      params: {
        'p_product_id': productId,
        'p_characteristics': characteristics,
        'p_variants': variants,
      },
    );
    _notify();
  }

  /// Atomic RPC (`0016_adjust_stock_rpc.sql`) rather than a client-side
  /// read-then-write — closes the race between reading the current quantity
  /// and writing the new one. [variantId] targets a specific variant's own
  /// stock; `null` targets the product's own (only valid when the product
  /// has no variants, enforced server-side).
  Future<void> adjustStock({
    required String id,
    required int quantityDelta,
    required String reason,
    String? variantId,
    String? note,
  }) async {
    try {
      await _client.rpc(
        'adjust_stock',
        params: {
          'p_product_id': id,
          'p_quantity_delta': quantityDelta,
          'p_reason': reason,
          'p_variant_id': variantId,
          'p_note': note,
        },
      );
    } on PostgrestException catch (e) {
      if (e.message.contains('Stock insuffisant')) {
        throw InsufficientStockException(e.message);
      }
      rethrow;
    }
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

  /// RPC rather than a direct table write — `products` has no staff-read
  /// SELECT policy, and Postgres RLS requires a row to be visible via some
  /// SELECT-capable policy for an UPDATE to even locate it, not just
  /// satisfy the UPDATE policy's own USING clause. A raw client-side
  /// update here would silently affect 0 rows for every staff caller (see
  /// `0009_lot11_supplier_verification_rpc.sql`).
  Future<void> updateSupplierVerification({
    required String supplierId,
    required bool isVerified,
  }) async {
    await _client.rpc(
      'set_products_supplier_verification',
      params: {'p_supplier_id': supplierId, 'p_verified': isVerified},
    );
    _notify();
  }

  /// Fire-and-forget: no `_notify()` here on purpose — a view isn't a
  /// state change either side's own UI needs to react to live (the
  /// viewer isn't watching this product's stats, and the supplier's
  /// dashboard already re-fetches stats on its own visit, see
  /// `fetchSupplierProductStats`).
  Future<void> incrementViewCount(String productId) {
    return _client.rpc(
      'increment_product_view',
      params: {'p_product_id': productId},
    );
  }

  Future<List<Map<String, dynamic>>> fetchSupplierProductStats(
    String supplierId,
  ) async {
    final rows = await _client.rpc(
      'get_supplier_product_stats',
      params: {'p_supplier_id': supplierId},
    );
    return (rows as List).cast<Map<String, dynamic>>();
  }

  /// Promotions (`product_promotions`, `0062`).
  ///
  /// `supplier_id` n'est jamais transmis : un trigger le pose depuis le
  /// produit et refuse un produit qui n'appartient pas à l'appelant
  /// (`stamp_promotion_supplier`). L'envoyer d'ici laisserait croire que
  /// l'app décide à qui appartient la remise.
  Future<void> addPromotion(Map<String, dynamic> row) async {
    await _client.from('product_promotions').insert(row);
    _notify();
  }

  Future<void> updatePromotion(String id, Map<String, dynamic> patch) async {
    await _client.from('product_promotions').update(patch).eq('id', id);
    _notify();
  }

  Future<void> deletePromotion(String id) async {
    await _client.from('product_promotions').delete().eq('id', id);
    _notify();
  }
}
