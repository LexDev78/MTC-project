// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$OrderItemImpl _$$OrderItemImplFromJson(Map<String, dynamic> json) =>
    _$OrderItemImpl(
      productId: json['product_id'] as String,
      productNameSnapshot: json['product_name_snapshot'] as String,
      unitPriceFcfaSnapshot: (json['unit_price_fcfa_snapshot'] as num).toInt(),
      quantity: (json['quantity'] as num).toInt(),
    );

Map<String, dynamic> _$$OrderItemImplToJson(_$OrderItemImpl instance) =>
    <String, dynamic>{
      'product_id': instance.productId,
      'product_name_snapshot': instance.productNameSnapshot,
      'unit_price_fcfa_snapshot': instance.unitPriceFcfaSnapshot,
      'quantity': instance.quantity,
    };

_$OrderSupplierGroupImpl _$$OrderSupplierGroupImplFromJson(
  Map<String, dynamic> json,
) => _$OrderSupplierGroupImpl(
  id: json['id'] as String,
  supplierId: json['supplier_id'] as String,
  supplierName: json['supplier_name'] as String,
  items: (json['items'] as List<dynamic>)
      .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
      .toList(),
  deliveryMode: $enumDecode(_$DeliveryModeEnumMap, json['delivery_mode']),
  deliveryFeeFcfa: (json['delivery_fee_fcfa'] as num).toInt(),
  subtotalFcfa: (json['subtotal_fcfa'] as num).toInt(),
  status: $enumDecode(_$OrderStatusEnumMap, json['status']),
  cancellationReason: json['cancellation_reason'] as String?,
  cancelledBy: $enumDecodeNullable(_$CancelledByEnumMap, json['cancelled_by']),
);

Map<String, dynamic> _$$OrderSupplierGroupImplToJson(
  _$OrderSupplierGroupImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'supplier_id': instance.supplierId,
  'supplier_name': instance.supplierName,
  'items': instance.items,
  'delivery_mode': _$DeliveryModeEnumMap[instance.deliveryMode]!,
  'delivery_fee_fcfa': instance.deliveryFeeFcfa,
  'subtotal_fcfa': instance.subtotalFcfa,
  'status': _$OrderStatusEnumMap[instance.status]!,
  'cancellation_reason': instance.cancellationReason,
  'cancelled_by': _$CancelledByEnumMap[instance.cancelledBy],
};

const _$DeliveryModeEnumMap = {
  DeliveryMode.selfDelivery: 'self_delivery',
  DeliveryMode.mtcDelivery: 'mtc_delivery',
};

const _$OrderStatusEnumMap = {
  OrderStatus.pending: 'pending',
  OrderStatus.confirmed: 'confirmed',
  OrderStatus.preparing: 'preparing',
  OrderStatus.inTransit: 'in_transit',
  OrderStatus.delivered: 'delivered',
  OrderStatus.cancelled: 'cancelled',
};

const _$CancelledByEnumMap = {
  CancelledBy.client: 'client',
  CancelledBy.supplier: 'supplier',
  CancelledBy.mtc: 'mtc',
};

_$OrderImpl _$$OrderImplFromJson(Map<String, dynamic> json) => _$OrderImpl(
  id: json['id'] as String,
  clientId: json['client_id'] as String,
  clientDisplayNameSnapshot: json['client_display_name_snapshot'] as String,
  clientPhoneSnapshot: json['client_phone_snapshot'] as String,
  supplierGroups: (json['supplier_groups'] as List<dynamic>)
      .map((e) => OrderSupplierGroup.fromJson(e as Map<String, dynamic>))
      .toList(),
  status: $enumDecode(_$OrderStatusEnumMap, json['status']),
  placedAt: DateTime.parse(json['placed_at'] as String),
  totalFcfa: (json['total_fcfa'] as num).toInt(),
  deliveryAddressLabel: json['delivery_address_label'] as String,
  deliveryCity: json['delivery_city'] as String,
  deliveryDetails: json['delivery_details'] as String,
  deliveryLatitude: (json['delivery_latitude'] as num).toDouble(),
  deliveryLongitude: (json['delivery_longitude'] as num).toDouble(),
  fulfillmentMethod:
      $enumDecodeNullable(
        _$FulfillmentMethodEnumMap,
        json['fulfillment_method'],
      ) ??
      FulfillmentMethod.homeDelivery,
  courierPhone: json['courier_phone'] as String?,
  alternatePhone: json['alternate_phone'] as String?,
  deliveryDate: json['delivery_date'] == null
      ? null
      : DateTime.parse(json['delivery_date'] as String),
  deliveryTimeSlotLabel: json['delivery_time_slot_label'] as String?,
  isPriority: json['is_priority'] as bool? ?? false,
  priorityFeeFcfa: (json['priority_fee_fcfa'] as num?)?.toInt() ?? 0,
  supplierMessageType:
      $enumDecodeNullable(
        _$SupplierMessageTypeEnumMap,
        json['supplier_message_type'],
      ) ??
      SupplierMessageType.none,
  supplierMessageText: json['supplier_message_text'] as String?,
  supplierMessageVoicePath: json['supplier_message_voice_path'] as String?,
  supplierMessageVoiceDurationSeconds:
      (json['supplier_message_voice_duration_seconds'] as num?)?.toInt(),
  paymentMethod:
      $enumDecodeNullable(_$PaymentMethodEnumMap, json['payment_method']) ??
      PaymentMethod.onDelivery,
  paymentStatus:
      $enumDecodeNullable(_$PaymentStatusEnumMap, json['payment_status']) ??
      PaymentStatus.pendingOnDelivery,
  mobileMoneyProvider: $enumDecodeNullable(
    _$MobileMoneyProviderEnumMap,
    json['mobile_money_provider'],
  ),
);

Map<String, dynamic> _$$OrderImplToJson(
  _$OrderImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'client_id': instance.clientId,
  'client_display_name_snapshot': instance.clientDisplayNameSnapshot,
  'client_phone_snapshot': instance.clientPhoneSnapshot,
  'supplier_groups': instance.supplierGroups,
  'status': _$OrderStatusEnumMap[instance.status]!,
  'placed_at': instance.placedAt.toIso8601String(),
  'total_fcfa': instance.totalFcfa,
  'delivery_address_label': instance.deliveryAddressLabel,
  'delivery_city': instance.deliveryCity,
  'delivery_details': instance.deliveryDetails,
  'delivery_latitude': instance.deliveryLatitude,
  'delivery_longitude': instance.deliveryLongitude,
  'fulfillment_method': _$FulfillmentMethodEnumMap[instance.fulfillmentMethod]!,
  'courier_phone': instance.courierPhone,
  'alternate_phone': instance.alternatePhone,
  'delivery_date': instance.deliveryDate?.toIso8601String(),
  'delivery_time_slot_label': instance.deliveryTimeSlotLabel,
  'is_priority': instance.isPriority,
  'priority_fee_fcfa': instance.priorityFeeFcfa,
  'supplier_message_type':
      _$SupplierMessageTypeEnumMap[instance.supplierMessageType]!,
  'supplier_message_text': instance.supplierMessageText,
  'supplier_message_voice_path': instance.supplierMessageVoicePath,
  'supplier_message_voice_duration_seconds':
      instance.supplierMessageVoiceDurationSeconds,
  'payment_method': _$PaymentMethodEnumMap[instance.paymentMethod]!,
  'payment_status': _$PaymentStatusEnumMap[instance.paymentStatus]!,
  'mobile_money_provider':
      _$MobileMoneyProviderEnumMap[instance.mobileMoneyProvider],
};

const _$FulfillmentMethodEnumMap = {
  FulfillmentMethod.pickupPoint: 'pickup_point',
  FulfillmentMethod.homeDelivery: 'home_delivery',
};

const _$SupplierMessageTypeEnumMap = {
  SupplierMessageType.none: 'none',
  SupplierMessageType.text: 'text',
  SupplierMessageType.voice: 'voice',
};

const _$PaymentMethodEnumMap = {
  PaymentMethod.now: 'now',
  PaymentMethod.onDelivery: 'on_delivery',
};

const _$PaymentStatusEnumMap = {
  PaymentStatus.paid: 'paid',
  PaymentStatus.pendingOnDelivery: 'pending_on_delivery',
};

const _$MobileMoneyProviderEnumMap = {
  MobileMoneyProvider.orangeMoney: 'orange_money',
  MobileMoneyProvider.moovMoney: 'moov_money',
};
