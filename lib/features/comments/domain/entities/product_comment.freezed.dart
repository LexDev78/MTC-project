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

/// @nodoc
mixin _$ProductComment {
  String get id => throw _privateConstructorUsedError;
  String get productId => throw _privateConstructorUsedError;
  String get authorId => throw _privateConstructorUsedError;
  String get authorName => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  String get text => throw _privateConstructorUsedError;

  /// True when the author is a supplier account (tiers or MTC principal)
  /// rather than a client — drives the "Fournisseur" badge in the UI.
  bool get isSupplier => throw _privateConstructorUsedError;

  /// Null for a top-level comment; the top-level comment's id for a reply.
  String? get parentId => throw _privateConstructorUsedError;

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
    String authorId,
    String authorName,
    DateTime createdAt,
    String text,
    bool isSupplier,
    String? parentId,
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
    Object? authorId = null,
    Object? authorName = null,
    Object? createdAt = null,
    Object? text = null,
    Object? isSupplier = null,
    Object? parentId = freezed,
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
    String authorId,
    String authorName,
    DateTime createdAt,
    String text,
    bool isSupplier,
    String? parentId,
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
    Object? authorId = null,
    Object? authorName = null,
    Object? createdAt = null,
    Object? text = null,
    Object? isSupplier = null,
    Object? parentId = freezed,
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
      ),
    );
  }
}

/// @nodoc

class _$ProductCommentImpl implements _ProductComment {
  const _$ProductCommentImpl({
    required this.id,
    required this.productId,
    required this.authorId,
    required this.authorName,
    required this.createdAt,
    required this.text,
    this.isSupplier = false,
    this.parentId,
  });

  @override
  final String id;
  @override
  final String productId;
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

  @override
  String toString() {
    return 'ProductComment(id: $id, productId: $productId, authorId: $authorId, authorName: $authorName, createdAt: $createdAt, text: $text, isSupplier: $isSupplier, parentId: $parentId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ProductCommentImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.productId, productId) ||
                other.productId == productId) &&
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
                other.parentId == parentId));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    productId,
    authorId,
    authorName,
    createdAt,
    text,
    isSupplier,
    parentId,
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
}

abstract class _ProductComment implements ProductComment {
  const factory _ProductComment({
    required final String id,
    required final String productId,
    required final String authorId,
    required final String authorName,
    required final DateTime createdAt,
    required final String text,
    final bool isSupplier,
    final String? parentId,
  }) = _$ProductCommentImpl;

  @override
  String get id;
  @override
  String get productId;
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

  /// Create a copy of ProductComment
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ProductCommentImplCopyWith<_$ProductCommentImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
