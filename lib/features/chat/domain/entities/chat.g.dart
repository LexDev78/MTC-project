// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ChatConversationImpl _$$ChatConversationImplFromJson(
  Map<String, dynamic> json,
) => _$ChatConversationImpl(
  id: json['id'] as String,
  clientId: json['client_id'] as String,
  clientDisplayNameSnapshot: json['client_display_name_snapshot'] as String,
  supplierId: json['supplier_id'] as String,
  supplierName: json['supplier_name'] as String,
  lastMessagePreview: json['last_message_preview'] as String,
  lastMessageAt: DateTime.parse(json['last_message_at'] as String),
  unreadCountClient: (json['unread_count_client'] as num).toInt(),
  unreadCountSupplier: (json['unread_count_supplier'] as num).toInt(),
  closedAt: json['closed_at'] == null
      ? null
      : DateTime.parse(json['closed_at'] as String),
);

Map<String, dynamic> _$$ChatConversationImplToJson(
  _$ChatConversationImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'client_id': instance.clientId,
  'client_display_name_snapshot': instance.clientDisplayNameSnapshot,
  'supplier_id': instance.supplierId,
  'supplier_name': instance.supplierName,
  'last_message_preview': instance.lastMessagePreview,
  'last_message_at': instance.lastMessageAt.toIso8601String(),
  'unread_count_client': instance.unreadCountClient,
  'unread_count_supplier': instance.unreadCountSupplier,
  'closed_at': instance.closedAt?.toIso8601String(),
};

_$ChatMessageImpl _$$ChatMessageImplFromJson(Map<String, dynamic> json) =>
    _$ChatMessageImpl(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      text: json['text'] as String,
      sentAt: DateTime.parse(json['sent_at'] as String),
      isRead: json['is_read'] as bool,
      productId: json['product_id'] as String?,
      productNameSnapshot: json['product_name_snapshot'] as String?,
      productImageSnapshot: json['product_image_snapshot'] as String?,
      productPriceFcfaSnapshot: (json['product_price_fcfa_snapshot'] as num?)
          ?.toInt(),
      productVariantId: json['product_variant_id'] as String?,
      productVariantNameSnapshot:
          json['product_variant_name_snapshot'] as String?,
      attachmentType:
          $enumDecodeNullable(
            _$ChatAttachmentTypeEnumMap,
            json['attachment_type'],
          ) ??
          ChatAttachmentType.none,
      attachmentPath: json['attachment_path'] as String?,
      voiceDurationSeconds: (json['voice_duration_seconds'] as num?)?.toInt(),
    );

Map<String, dynamic> _$$ChatMessageImplToJson(_$ChatMessageImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'conversation_id': instance.conversationId,
      'sender_id': instance.senderId,
      'text': instance.text,
      'sent_at': instance.sentAt.toIso8601String(),
      'is_read': instance.isRead,
      'product_id': instance.productId,
      'product_name_snapshot': instance.productNameSnapshot,
      'product_image_snapshot': instance.productImageSnapshot,
      'product_price_fcfa_snapshot': instance.productPriceFcfaSnapshot,
      'product_variant_id': instance.productVariantId,
      'product_variant_name_snapshot': instance.productVariantNameSnapshot,
      'attachment_type': _$ChatAttachmentTypeEnumMap[instance.attachmentType]!,
      'attachment_path': instance.attachmentPath,
      'voice_duration_seconds': instance.voiceDurationSeconds,
    };

const _$ChatAttachmentTypeEnumMap = {
  ChatAttachmentType.none: 'none',
  ChatAttachmentType.image: 'image',
  ChatAttachmentType.voice: 'voice',
};
