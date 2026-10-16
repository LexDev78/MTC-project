import '../../domain/entities/courier_delivery.dart';
import '../../domain/entities/courier_dossier.dart';
import '../../domain/entities/courier_history.dart';
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
          documentsSubmittedAt: DateTime.parse(
            row['documents_submitted_at'] as String,
          ),
          vehicleType: _vehicleTypeOf(row['vehicle_type'] as String?),
          documents: _documentsOf(row['documents']),
        ),
    ];
  }

  @override
  Future<CourierDossier> fetchMyDossier(String courierId) async {
    final row = await _datasource.fetchMyDossier(courierId);
    final submitted = row['documents_submitted_at'] as String?;
    return CourierDossier(
      documents: _documentsOf(row['documents']),
      vehicleType: _vehicleTypeOf(row['vehicle_type'] as String?),
      vehicleLabel: row['vehicle_label'] as String?,
      submittedAt: submitted == null ? null : DateTime.parse(submitted),
      rejectionReason: row['rejection_reason'] as String?,
    );
  }

  @override
  Future<void> saveDocument({
    required String courierId,
    required CourierDocumentType type,
    required String filePath,
  }) {
    return _datasource.upsertDocument(
      courierId: courierId,
      type: type.wireValue,
      filePath: filePath,
    );
  }

  @override
  Future<void> removeDocument({required String documentId}) {
    return _datasource.removeDocument(documentId: documentId);
  }

  @override
  Future<void> submitDossier({
    required CourierVehicleType vehicleType,
    String? vehicleLabel,
  }) {
    return _datasource.submitDocuments(
      vehicleType: vehicleType.wireValue,
      vehicleLabel: vehicleLabel,
    );
  }

  /// Les pièces arrivent imbriquées dans la fiche. Une fiche sans pièce
  /// remonte une liste vide, pas `null` — PostgREST rend `[]`, mais une
  /// lecture qui n'aurait pas demandé l'imbrication rendrait `null`, et
  /// l'écran du staff ne doit pas tomber pour autant.
  List<CourierDocument> _documentsOf(Object? raw) {
    if (raw is! List) return const [];
    final documents = [
      for (final entry in raw.cast<Map<String, dynamic>>())
        CourierDocument(
          id: entry['id'] as String,
          type: CourierDocumentType.fromWire(entry['type'] as String),
          filePath: entry['file_path'] as String,
          uploadedAt: DateTime.parse(entry['uploaded_at'] as String),
        ),
    ];
    // Ordre d'affichage stable : l'agent retrouve le recto avant le verso,
    // quel que soit l'ordre d'envoi.
    documents.sort(
      (a, b) => a.type.index.compareTo(b.type.index),
    );
    return documents;
  }

  CourierVehicleType? _vehicleTypeOf(String? raw) {
    if (raw == null) return null;
    for (final type in CourierVehicleType.values) {
      if (type.wireValue == raw) return type;
    }
    return null;
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
  Future<List<CourierHistoryEntry>> fetchHistory({
    int limit = 30,
    int offset = 0,
  }) async {
    final rows = await _datasource.fetchHistory(limit: limit, offset: offset);
    return [
      for (final row in rows)
        CourierHistoryEntry(
          deliveryId: row['delivery_id'] as String,
          reference: row['reference'] as String,
          status: DeliveryStatus.fromRow(row['status'] as String),
          pickupCity: row['pickup_city'] as String? ?? '',
          dropoffCity: row['dropoff_city'] as String? ?? '',
          itemCount: (row['item_count'] as num?)?.toInt() ?? 0,
          deliveryFeeFcfa: (row['delivery_fee_fcfa'] as num?)?.toInt() ?? 0,
          acceptedAt: _parseDate(row['accepted_at']),
          pickedUpAt: _parseDate(row['picked_up_at']),
          deliveredAt: _parseDate(row['delivered_at']),
          clientStars: (row['client_stars'] as num?)?.toInt(),
          supplierStars: (row['supplier_stars'] as num?)?.toInt(),
        ),
    ];
  }

  @override
  Future<CourierStats> fetchStats() async {
    final row = await _datasource.fetchStats();
    // Un livreur qui n'a encore rien livré : la RPC agrège sur un ensemble
    // vide, pas sur rien. Le cas « aucune ligne » reste couvert plutôt que
    // de laisser passer une exception pour un compteur à zéro.
    if (row == null) {
      return const CourierStats(
        deliveredCount: 0,
        deliveredFeesFcfa: 0,
        monthDeliveredCount: 0,
        monthFeesFcfa: 0,
        cancelledCount: 0,
        ratingAverage: 0,
        ratingCount: 0,
      );
    }
    return CourierStats(
      deliveredCount: (row['delivered_count'] as num?)?.toInt() ?? 0,
      deliveredFeesFcfa: (row['delivered_fees_fcfa'] as num?)?.toInt() ?? 0,
      monthDeliveredCount: (row['month_delivered_count'] as num?)?.toInt() ?? 0,
      monthFeesFcfa: (row['month_fees_fcfa'] as num?)?.toInt() ?? 0,
      cancelledCount: (row['cancelled_count'] as num?)?.toInt() ?? 0,
      // `numeric` revient en chaîne sur le fil : `as num` échouerait.
      ratingAverage: double.tryParse('${row['rating_average'] ?? 0}') ?? 0,
      ratingCount: (row['rating_count'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<List<CourierRating>> fetchMyRatings({
    int limit = 30,
    int offset = 0,
  }) async {
    final rows = await _datasource.fetchMyRatings(limit: limit, offset: offset);
    return [
      for (final row in rows)
        CourierRating(
          stars: (row['stars'] as num).toInt(),
          raterRole: CourierRaterRole.fromRow(row['rater_role'] as String),
          createdAt: DateTime.parse(row['created_at'] as String),
          deliveryId: row['delivery_id'] as String,
          comment: row['comment'] as String?,
        ),
    ];
  }

  @override
  Future<void> rateCourier({
    required String deliveryId,
    required int stars,
    String? comment,
  }) {
    return _datasource.rateCourier(
      deliveryId: deliveryId,
      stars: stars,
      comment: comment,
    );
  }

  @override
  Future<MyDeliveryRating?> fetchMyRatingForDelivery(String deliveryId) async {
    final row = await _datasource.fetchMyRatingForDelivery(deliveryId);
    if (row == null) return null;
    return MyDeliveryRating(
      stars: (row['stars'] as num).toInt(),
      comment: row['comment'] as String?,
    );
  }

  static DateTime? _parseDate(Object? value) =>
      value == null ? null : DateTime.parse(value as String);

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
