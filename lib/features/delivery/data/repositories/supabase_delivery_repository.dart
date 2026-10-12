import '../../domain/entities/courier_delivery.dart';
import '../../domain/repositories/delivery_repository.dart';
import '../datasources/supabase_delivery_datasource.dart';

class SupabaseDeliveryRepository implements DeliveryRepository {
  const SupabaseDeliveryRepository(this._datasource);

  final SupabaseDeliveryDatasource _datasource;

  @override
  Stream<List<CourierDelivery>> watchForCourier(String courierId) {
    return _datasource
        .watchForCourier(courierId)
        .map((rows) => rows.map(_fromRow).toList());
  }

  @override
  Future<void> accept(String deliveryId) => _datasource.accept(deliveryId);

  @override
  Future<void> decline(String deliveryId) => _datasource.decline(deliveryId);

  @override
  Future<void> reofferExpired() => _datasource.reofferExpired();

  @override
  Future<DeliveryStatus> scan({
    required String deliveryId,
    required String code,
  }) async {
    final status = await _datasource.scan(deliveryId: deliveryId, code: code);
    return DeliveryStatus.fromRow(status);
  }

  @override
  Future<String?> fetchCode({
    required String deliveryId,
    required DeliveryCodeKind kind,
  }) {
    return _datasource.fetchCode(deliveryId: deliveryId, kind: kind.wireName);
  }

  @override
  Future<({String id, DeliveryStatus status})?> fetchByGroup(
    String supplierGroupId,
  ) async {
    final row = await _datasource.fetchByGroup(supplierGroupId);
    if (row == null) return null;
    return (
      id: row['id'] as String,
      status: DeliveryStatus.fromRow(row['status'] as String),
    );
  }

  @override
  Future<void> pushPosition({
    required double latitude,
    required double longitude,
  }) {
    return _datasource.pushPosition(latitude: latitude, longitude: longitude);
  }

  @override
  Future<List<PendingCourier>> fetchPendingCouriers() async {
    final rows = await _datasource.fetchPendingCouriers();
    return [
      for (final row in rows)
        PendingCourier(
          id: row['id'] as String,
          displayName: row['display_name'] as String? ?? '',
          phoneNumber: row['phone_number'] as String? ?? '',
          city: row['city'] as String,
          vehicleLabel: row['vehicle_label'] as String?,
          createdAt: DateTime.parse(row['created_at'] as String),
        ),
    ];
  }

  @override
  Future<void> reviewCourier({
    required String courierId,
    required bool approve,
    String? reason,
  }) {
    return _datasource.reviewCourier(
      courierId: courierId,
      approve: approve,
      reason: reason,
    );
  }

  @override
  Future<void> setOnline({
    required String courierId,
    required bool isOnline,
    double? latitude,
    double? longitude,
  }) {
    return _datasource.setOnline(
      courierId: courierId,
      isOnline: isOnline,
      latitude: latitude,
      longitude: longitude,
    );
  }

  /// Remet à plat les quatre tables de la requête imbriquée.
  ///
  /// Écrit à la main plutôt que généré : les alias (`order_data`,
  /// `group_data`, `supplier`, `items`) n'existent que dans cette requête, et une
  /// désérialisation automatique obligerait à créer quatre entités
  /// intermédiaires qui ne servent nulle part ailleurs.
  static CourierDelivery _fromRow(Map<String, dynamic> row) {
    final order = row['order_data'] as Map<String, dynamic>;
    final group = row['group_data'] as Map<String, dynamic>;
    final supplier = group['supplier'] as Map<String, dynamic>?;
    final items = (group['items'] as List<dynamic>? ?? const []);

    return CourierDelivery(
      id: row['id'] as String,
      orderId: row['order_id'] as String,
      supplierGroupId: row['supplier_group_id'] as String,
      status: DeliveryStatus.fromRow(row['status'] as String),
      offerExpiresAt: row['offer_expires_at'] == null
          ? null
          : DateTime.parse(row['offer_expires_at'] as String),
      supplierName: group['supplier_name'] as String,
      supplierAddress: supplier?['full_address'] as String?,
      supplierCity: supplier?['city'] as String? ?? '',
      supplierLatitude: (supplier?['address_latitude'] as num?)?.toDouble(),
      supplierLongitude: (supplier?['address_longitude'] as num?)?.toDouble(),
      supplierPhones: List<String>.from(
        supplier?['public_phone_numbers'] as List<dynamic>? ?? const [],
      ),
      clientName: order['client_display_name_snapshot'] as String,
      clientPhone: order['client_phone_snapshot'] as String,
      clientAlternatePhone: order['alternate_phone'] as String?,
      deliveryAddressLabel: order['delivery_address_label'] as String,
      deliveryCity: order['delivery_city'] as String,
      deliveryDetails: order['delivery_details'] as String? ?? '',
      deliveryLatitude: (order['delivery_latitude'] as num).toDouble(),
      deliveryLongitude: (order['delivery_longitude'] as num).toDouble(),
      items: [
        for (final item in items.cast<Map<String, dynamic>>())
          DeliveryItem(
            productName: item['product_name_snapshot'] as String,
            quantity: item['quantity'] as int,
            variantName: item['variant_name_snapshot'] as String?,
          ),
      ],
      deliveryFeeFcfa: group['delivery_fee_fcfa'] as int,
      subtotalFcfa: group['subtotal_fcfa'] as int,
      collectOnDelivery: order['payment_method'] == 'on_delivery',
    );
  }
}
