import '../../domain/entities/promo_code.dart';
import '../../domain/repositories/promo_code_repository.dart';
import '../datasources/supabase_promo_code_datasource.dart';

class SupabasePromoCodeRepository implements PromoCodeRepository {
  const SupabasePromoCodeRepository(this._datasource);

  final SupabasePromoCodeDatasource _datasource;

  @override
  Stream<List<PromoCode>> watchMine() {
    return _datasource.watchMine().map(
      (rows) => [for (final row in rows) _fromRow(row)],
    );
  }

  @override
  Future<void> create({
    required String code,
    required int percent,
    String? label,
    DateTime? startsAt,
    DateTime? endsAt,
    int? maxUses,
    int maxUsesPerClient = 1,
    int? minOrderFcfa,
    List<String> productIds = const [],
  }) async {
    final id = await _datasource.create({
      'code': code,
      'percent': percent,
      'label': label,
      // En UTC explicite : une date locale sérialisée sans décalage serait
      // relue comme de l'UTC, et la fenêtre du code se déplacerait du fuseau
      // de l'appareil.
      'starts_at': startsAt?.toUtc().toIso8601String(),
      'ends_at': endsAt?.toUtc().toIso8601String(),
      'max_uses': maxUses,
      'max_uses_per_client': maxUsesPerClient,
      'min_order_fcfa': minOrderFcfa,
    });
    if (productIds.isNotEmpty) {
      await _datasource.setProducts(promoCodeId: id, productIds: productIds);
    }
  }

  @override
  Future<void> update({
    required String id,
    required int percent,
    String? label,
    DateTime? endsAt,
    int? maxUses,
    int maxUsesPerClient = 1,
    int? minOrderFcfa,
    required List<String> productIds,
  }) async {
    await _datasource.update(id, {
      'percent': percent,
      'label': label,
      // `toUtc()` avant de sérialiser : une date locale sans décalage est
      // relue comme de l'UTC, et la fin du code se déplace.
      'ends_at': endsAt?.toUtc().toIso8601String(),
      'max_uses': maxUses,
      'max_uses_per_client': maxUsesPerClient,
      'min_order_fcfa': minOrderFcfa,
    });
    await _datasource.setProducts(promoCodeId: id, productIds: productIds);
  }

  @override
  Future<void> setActive({required String id, required bool isActive}) =>
      _datasource.setActive(id: id, isActive: isActive);

  @override
  Future<void> delete(String id) => _datasource.delete(id);

  @override
  Future<Map<String, ({String code, int discountFcfa})>> fetchForOrder(
    String orderId,
  ) async {
    final rows = await _datasource.fetchForOrder(orderId);
    return {
      for (final row in rows)
        row['supplier_group_id'] as String: (
          code: row['code'] as String,
          discountFcfa: (row['discount_fcfa'] as num).toInt(),
        ),
    };
  }

  @override
  Future<bool> existsForProducts(List<String> productIds) =>
      _datasource.existsForProducts(productIds);

  @override
  Future<PromoCodePreview> preview({
    required String code,
    required List<({String productId, String? variantId, int quantity})> lines,
  }) async {
    final result = await _datasource.preview(
      code: code,
      lines: [
        for (final line in lines)
          {
            'product_id': line.productId,
            'variant_id': line.variantId,
            'quantity': line.quantity,
          },
      ],
    );
    return PromoCodePreview(
      valid: result['valid'] as bool? ?? false,
      reason: result['reason'] as String?,
      code: result['code'] as String?,
      percent: (result['percent'] as num?)?.toInt(),
      supplierId: result['supplier_id'] as String?,
      discountFcfa: (result['discount_fcfa'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Assemblage à la main : `fetch_my_promo_codes` renvoie un objet taillé
/// pour cet écran (le code, ses utilisations, et le détail de chacune), pas
/// une ligne de table.
PromoCode _fromRow(Map<String, dynamic> row) {
  return PromoCode(
    id: row['id'] as String,
    code: row['code'] as String,
    percent: (row['percent'] as num).toInt(),
    isActive: row['is_active'] as bool? ?? true,
    usesCount: (row['uses_count'] as num?)?.toInt() ?? 0,
    maxUsesPerClient: (row['max_uses_per_client'] as num?)?.toInt() ?? 1,
    label: row['label'] as String?,
    startsAt: _date(row['starts_at']),
    endsAt: _date(row['ends_at']),
    maxUses: (row['max_uses'] as num?)?.toInt(),
    minOrderFcfa: (row['min_order_fcfa'] as num?)?.toInt(),
    productIds: [
      for (final id in (row['product_ids'] as List? ?? const []))
        id as String,
    ],
    redemptions: [
      for (final r in (row['redemptions'] as List? ?? const []))
        _redemptionFromRow(Map<String, dynamic>.from(r as Map)),
    ],
  );
}

PromoCodeRedemption _redemptionFromRow(Map<String, dynamic> row) {
  return PromoCodeRedemption(
    id: row['id'] as String,
    createdAt: DateTime.parse(row['created_at'] as String),
    discountFcfa: (row['discount_fcfa'] as num).toInt(),
    clientName: row['client_name'] as String? ?? 'Client MTC',
    items: [
      for (final i in (row['items'] as List? ?? const []))
        PromoCodeRedemptionItem(
          productName: (i as Map)['product_name'] as String? ?? '',
          quantity: (i['quantity'] as num?)?.toInt() ?? 0,
          unitDiscountFcfa: (i['unit_discount_fcfa'] as num?)?.toInt() ?? 0,
        ),
    ],
  );
}

DateTime? _date(Object? value) =>
    value == null ? null : DateTime.parse(value as String);
