// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_review.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ProductReviewImpl _$$ProductReviewImplFromJson(Map<String, dynamic> json) =>
    _$ProductReviewImpl(
      id: json['id'] as String,
      stars: (json['stars'] as num).toInt(),
      comment: json['comment'] as String,
      title: json['title'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      authorName: json['author_name'] as String,
      imagePaths:
          (json['image_paths'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      videoPath: json['video_path'] as String?,
      supplierReply: json['supplier_reply'] as String?,
      supplierRepliedAt: json['supplier_replied_at'] == null
          ? null
          : DateTime.parse(json['supplier_replied_at'] as String),
      comments:
          (json['comments'] as List<dynamic>?)
              ?.map((e) => ReviewComment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$$ProductReviewImplToJson(_$ProductReviewImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'stars': instance.stars,
      'comment': instance.comment,
      'title': instance.title,
      'created_at': instance.createdAt.toIso8601String(),
      'author_name': instance.authorName,
      'image_paths': instance.imagePaths,
      'video_path': instance.videoPath,
      'supplier_reply': instance.supplierReply,
      'supplier_replied_at': instance.supplierRepliedAt?.toIso8601String(),
      'comments': instance.comments,
    };

_$ReviewCommentImpl _$$ReviewCommentImplFromJson(Map<String, dynamic> json) =>
    _$ReviewCommentImpl(
      id: json['id'] as String,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      authorName: json['author_name'] as String,
      authorIsSupplier: json['author_is_supplier'] as bool? ?? false,
      imagePaths:
          (json['image_paths'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      videoPath: json['video_path'] as String?,
    );

Map<String, dynamic> _$$ReviewCommentImplToJson(_$ReviewCommentImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'body': instance.body,
      'created_at': instance.createdAt.toIso8601String(),
      'author_name': instance.authorName,
      'author_is_supplier': instance.authorIsSupplier,
      'image_paths': instance.imagePaths,
      'video_path': instance.videoPath,
    };
