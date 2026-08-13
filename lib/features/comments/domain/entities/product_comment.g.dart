// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_comment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ProductCommentImpl _$$ProductCommentImplFromJson(Map<String, dynamic> json) =>
    _$ProductCommentImpl(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      supplierId: json['supplier_id'] as String,
      authorId: json['author_id'] as String,
      authorName: json['author_name'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      text: json['text'] as String,
      isSupplier: json['is_supplier'] as bool? ?? false,
      parentId: json['parent_id'] as String?,
      attachmentType:
          $enumDecodeNullable(
            _$CommentAttachmentTypeEnumMap,
            json['attachment_type'],
          ) ??
          CommentAttachmentType.none,
      attachmentPath: json['attachment_path'] as String?,
      voiceDurationSeconds: (json['voice_duration_seconds'] as num?)?.toInt(),
      likedByUserIds:
          (json['liked_by_user_ids'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toSet() ??
          const <String>{},
    );

Map<String, dynamic> _$$ProductCommentImplToJson(
  _$ProductCommentImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'product_id': instance.productId,
  'supplier_id': instance.supplierId,
  'author_id': instance.authorId,
  'author_name': instance.authorName,
  'created_at': instance.createdAt.toIso8601String(),
  'text': instance.text,
  'is_supplier': instance.isSupplier,
  'parent_id': instance.parentId,
  'attachment_type': _$CommentAttachmentTypeEnumMap[instance.attachmentType]!,
  'attachment_path': instance.attachmentPath,
  'voice_duration_seconds': instance.voiceDurationSeconds,
  'liked_by_user_ids': instance.likedByUserIds.toList(),
};

const _$CommentAttachmentTypeEnumMap = {
  CommentAttachmentType.none: 'none',
  CommentAttachmentType.image: 'image',
  CommentAttachmentType.voice: 'voice',
};
