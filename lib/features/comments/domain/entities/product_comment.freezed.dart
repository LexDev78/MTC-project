// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'product_comment.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

ProductComment _$ProductCommentFromJson(Map<String, dynamic> json) {
  return _ProductComment.fromJson(json);
}

/// @nodoc
mixin _$ProductComment {
  String get id => throw _privateConstructorUsedError;
  String get productId => throw _privateConstructorUsedError;

  /// Resolved from `Product.supplierId` at creation time (denormalized,
  /// same reasoning as every other snapshot in this app) — lets the
  /// supplier's comment inbox filter across all of their products
  /// without a live join back to the catalog.
  String get supplierId => throw _privateConstructorUsedError;
  String get authorId => throw _privateConstructorUsedError;
  String get authorName => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  String get text => throw _privateConstructorUsedError;

  /// True when the author is a supplier account (tiers or MTC principal)
  /// rather than a client — drives the "Fournisseur" badge in the UI.
  bool get isSupplier => throw _privateConstructorUsedError;

  /// Null for a top-level comment; the top-level comment's id for a reply.
  String? get parentId => throw _privateConstructorUsedError;

  /// Local file path for an image or voice-note attachment — same
  /// no-upload-backend caveat as `ChatMessage.attachmentPath`.
  CommentAttachmentType get attachmentType =>
      throw _privateConstructorUsedError;
  String? get attachmentPath => throw _privateConstructorUsedError;

  /// Set only for [CommentAttachmentType.voice], so the bubble can show a
  /// duration immediately without probing the audio file.
  int? get voiceDurationSeconds => throw _privateConstructorUsedError;

  /// User ids who liked this comment — a set rather than a bare count so
  /// "did the current user already like this" is a cheap lookup instead
  /// of needing a separate per-user query.
  Set<String> get likedByUserIds => throw _privateConstructorUsedError;

  /// Serializes this ProductComment to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ProductComment
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ProductCommentCopyWith<ProductComment> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ProductCommentCopyWith<$Res> {
  factory $ProductCommentCopyWith(
    ProductComment value,
    $Res Function(ProductComment) then,
  ) = _$ProductCommentCopyWithImpl<$Res, ProductComment>;
  @useResult
  $Res call({
    String id,
    String productId,
    String supplierId,
    String authorId,
    String authorName,
    DateTime createdAt,
    String text,
    bool isSupplier,
    String? parentId,
    CommentAttachmentType attachmentType,
    String? attachmentPath,
    int? voiceDurationSeconds,
    Set<String> likedByUserIds,
  });
}

/// @nodoc
class _$ProductCommentCopyWithImpl<$Res, $Val extends ProductComment>
    implements $ProductCommentCopyWith<$Res> {
  _$ProductCommentCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ProductComment
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? productId = null,
    Object? supplierId = null,
    Object? authorId = null,
    Object? authorName = null,
    Object? createdAt = null,
    Object? text = null,
    Object? isSupplier = null,
    Object? parentId = freezed,
    Object? attachmentType = null,
    Object? attachmentPath = freezed,
    Object? voiceDurationSeconds = freezed,
    Object? likedByUserIds = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            productId: null == productId
                ? _value.productId
                : productId // ignore: cast_nullable_to_non_nullable
                      as String,
            supplierId: null == supplierId
                ? _value.supplierId
                : supplierId // ignore: cast_nullable_to_non_nullable
                      as String,
            authorId: null == authorId
                ? _value.authorId
                : authorId // ignore: cast_nullable_to_non_nullable
                      as String,
            authorName: null == authorName
                ? _value.authorName
                : authorName // ignore: cast_nullable_to_non_nullable
                      as String,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            text: null == text
                ? _value.text
                : text // ignore: cast_nullable_to_non_nullable
                      as String,
            isSupplier: null == isSupplier
                ? _value.isSupplier
                : isSupplier // ignore: cast_nullable_to_non_nullable
                      as bool,
            parentId: freezed == parentId
                ? _value.parentId
                : parentId // ignore: cast_nullable_to_non_nullable
                      as String?,
            attachmentType: null == attachmentType
                ? _value.attachmentType
                : attachmentType // ignore: cast_nullable_to_non_nullable
                      as CommentAttachmentType,
            attachmentPath: freezed == attachmentPath
                ? _value.attachmentPath
                : attachmentPath // ignore: cast_nullable_to_non_nullable
                      as String?,
            voiceDurationSeconds: freezed == voiceDurationSeconds
                ? _value.voiceDurationSeconds
                : voiceDurationSeconds // ignore: cast_nullable_to_non_nullable
                      as int?,
            likedByUserIds: null == likedByUserIds
                ? _value.likedByUserIds
                : likedByUserIds // ignore: cast_nullable_to_non_nullable
                      as Set<String>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ProductCommentImplCopyWith<$Res>
    implements $ProductCommentCopyWith<$Res> {
  factory _$$ProductCommentImplCopyWith(
    _$ProductCommentImpl value,
    $Res Function(_$ProductCommentImpl) then,
  ) = __$$ProductCommentImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String productId,
    String supplierId,
    String authorId,
    String authorName,
    DateTime createdAt,
    String text,
    bool isSupplier,
    String? parentId,
    CommentAttachmentType attachmentType,
    String? attachmentPath,
    int? voiceDurationSeconds,
    Set<String> likedByUserIds,
  });
}

/// @nodoc
class __$$ProductCommentImplCopyWithImpl<$Res>
    extends _$ProductCommentCopyWithImpl<$Res, _$ProductCommentImpl>
    implements _$$ProductCommentImplCopyWith<$Res> {
  __$$ProductCommentImplCopyWithImpl(
    _$ProductCommentImpl _value,
    $Res Function(_$ProductCommentImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ProductComment
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? productId = null,
    Object? supplierId = null,
    Object? authorId = null,
    Object? authorName = null,
    Object? createdAt = null,
    Object? text = null,
    Object? isSupplier = null,
    Object? parentId = freezed,
    Object? attachmentType = null,
    Object? attachmentPath = freezed,
    Object? voiceDurationSeconds = freezed,
    Object? likedByUserIds = null,
  }) {
    return _then(
      _$ProductCommentImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        productId: null == productId
            ? _value.productId
            : productId // ignore: cast_nullable_to_non_nullable
                  as String,
        supplierId: null == supplierId
            ? _value.supplierId
            : supplierId // ignore: cast_nullable_to_non_nullable
                  as String,
        authorId: null == authorId
            ? _value.authorId
            : authorId // ignore: cast_nullable_to_non_nullable
                  as String,
        authorName: null == authorName
            ? _value.authorName
            : authorName // ignore: cast_nullable_to_non_nullable
                  as String,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        text: null == text
            ? _value.text
            : text // ignore: cast_nullable_to_non_nullable
                  as String,
        isSupplier: null == isSupplier
            ? _value.isSupplier
            : isSupplier // ignore: cast_nullable_to_non_nullable
                  as bool,
        parentId: freezed == parentId
            ? _value.parentId
            : parentId // ignore: cast_nullable_to_non_nullable
                  as String?,
        attachmentType: null == attachmentType
            ? _value.attachmentType
            : attachmentType // ignore: cast_nullable_to_non_nullable
                  as CommentAttachmentType,
        attachmentPath: freezed == attachmentPath
            ? _value.attachmentPath
            : attachmentPath // ignore: cast_nullable_to_non_nullable
                  as String?,
        voiceDurationSeconds: freezed == voiceDurationSeconds
            ? _value.voiceDurationSeconds
            : voiceDurationSeconds // ignore: cast_nullable_to_non_nullable
                  as int?,
        likedByUserIds: null == likedByUserIds
            ? _value._likedByUserIds
            : likedByUserIds // ignore: cast_nullable_to_non_nullable
                  as Set<String>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ProductCommentImpl implements _ProductComment {
  const _$ProductCommentImpl({
    required this.id,
    required this.productId,
    required this.supplierId,
    required this.authorId,
    required this.authorName,
    required this.createdAt,
    required this.text,
    this.isSupplier = false,
    this.parentId,
    this.attachmentType = CommentAttachmentType.none,
    this.attachmentPath,
    this.voiceDurationSeconds,
    final Set<String> likedByUserIds = const <String>{},
  }) : _likedByUserIds = likedByUserIds;

  factory _$ProductCommentImpl.fromJson(Map<String, dynamic> json) =>
      _$$ProductCommentImplFromJson(json);

  @override
  final String id;
  @override
  final String productId;

  /// Resolved from `Product.supplierId` at creation time (denormalized,
  /// same reasoning as every other snapshot in this app) — lets the
  /// supplier's comment inbox filter across all of their products
  /// without a live join back to the catalog.
  @override
  final String supplierId;
  @override
  final String authorId;
  @override
  final String authorName;
  @override
  final DateTime createdAt;
  @override
  final String text;

  /// True when the author is a supplier account (tiers or MTC principal)
  /// rather than a client — drives the "Fournisseur" badge in the UI.
  @override
  @JsonKey()
  final bool isSupplier;

  /// Null for a top-level comment; the top-level comment's id for a reply.
  @override
  final String? parentId;

  /// Local file path for an image or voice-note attachment — same
  /// no-upload-backend caveat as `ChatMessage.attachmentPath`.
  @override
  @JsonKey()
  final CommentAttachmentType attachmentType;
  @override
  final String? attachmentPath;

  /// Set only for [CommentAttachmentType.voice], so the bubble can show a
  /// duration immediately without probing the audio file.
  @override
  final int? voiceDurationSeconds;

  /// User ids who liked this comment — a set rather than a bare count so
  /// "did the current user already like this" is a cheap lookup instead
  /// of needing a separate per-user query.
  final Set<String> _likedByUserIds;

  /// User ids who liked this comment — a set rather than a bare count so
  /// "did the current user already like this" is a cheap lookup instead
  /// of needing a separate per-user query.
  @override
  @JsonKey()
  Set<String> get likedByUserIds {
    if (_likedByUserIds is EqualUnmodifiableSetView) return _likedByUserIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_likedByUserIds);
  }

  @override
  String toString() {
    return 'ProductComment(id: $id, productId: $productId, supplierId: $supplierId, authorId: $authorId, authorName: $authorName, createdAt: $createdAt, text: $text, isSupplier: $isSupplier, parentId: $parentId, attachmentType: $attachmentType, attachmentPath: $attachmentPath, voiceDurationSeconds: $voiceDurationSeconds, likedByUserIds: $likedByUserIds)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ProductCommentImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.productId, productId) ||
                other.productId == productId) &&
            (identical(other.supplierId, supplierId) ||
                other.supplierId == supplierId) &&
            (identical(other.authorId, authorId) ||
                other.authorId == authorId) &&
            (identical(other.authorName, authorName) ||
                other.authorName == authorName) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.text, text) || other.text == text) &&
            (identical(other.isSupplier, isSupplier) ||
                other.isSupplier == isSupplier) &&
            (identical(other.parentId, parentId) ||
                other.parentId == parentId) &&
            (identical(other.attachmentType, attachmentType) ||
                other.attachmentType == attachmentType) &&
            (identical(other.attachmentPath, attachmentPath) ||
                other.attachmentPath == attachmentPath) &&
            (identical(other.voiceDurationSeconds, voiceDurationSeconds) ||
                other.voiceDurationSeconds == voiceDurationSeconds) &&
            const DeepCollectionEquality().equals(
              other._likedByUserIds,
              _likedByUserIds,
            ));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    productId,
    supplierId,
    authorId,
    authorName,
    createdAt,
    text,
    isSupplier,
    parentId,
    attachmentType,
    attachmentPath,
    voiceDurationSeconds,
    const DeepCollectionEquality().hash(_likedByUserIds),
  );

  /// Create a copy of ProductComment
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ProductCommentImplCopyWith<_$ProductCommentImpl> get copyWith =>
      __$$ProductCommentImplCopyWithImpl<_$ProductCommentImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$ProductCommentImplToJson(this);
  }
}

abstract class _ProductComment implements ProductComment {
  const factory _ProductComment({
    required final String id,
    required final String productId,
    required final String supplierId,
    required final String authorId,
    required final String authorName,
    required final DateTime createdAt,
    required final String text,
    final bool isSupplier,
    final String? parentId,
    final CommentAttachmentType attachmentType,
    final String? attachmentPath,
    final int? voiceDurationSeconds,
    final Set<String> likedByUserIds,
  }) = _$ProductCommentImpl;

  factory _ProductComment.fromJson(Map<String, dynamic> json) =
      _$ProductCommentImpl.fromJson;

  @override
  String get id;
  @override
  String get productId;

  /// Resolved from `Product.supplierId` at creation time (denormalized,
  /// same reasoning as every other snapshot in this app) — lets the
  /// supplier's comment inbox filter across all of their products
  /// without a live join back to the catalog.
  @override
  String get supplierId;
  @override
  String get authorId;
  @override
  String get authorName;
  @override
  DateTime get createdAt;
  @override
  String get text;

  /// True when the author is a supplier account (tiers or MTC principal)
  /// rather than a client — drives the "Fournisseur" badge in the UI.
  @override
  bool get isSupplier;

  /// Null for a top-level comment; the top-level comment's id for a reply.
  @override
  String? get parentId;

  /// Local file path for an image or voice-note attachment — same
  /// no-upload-backend caveat as `ChatMessage.attachmentPath`.
  @override
  CommentAttachmentType get attachmentType;
  @override
  String? get attachmentPath;

  /// Set only for [CommentAttachmentType.voice], so the bubble can show a
  /// duration immediately without probing the audio file.
  @override
  int? get voiceDurationSeconds;

  /// User ids who liked this comment — a set rather than a bare count so
  /// "did the current user already like this" is a cheap lookup instead
  /// of needing a separate per-user query.
  @override
  Set<String> get likedByUserIds;

  /// Create a copy of ProductComment
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ProductCommentImplCopyWith<_$ProductCommentImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
