// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'review.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Review _$ReviewFromJson(Map<String, dynamic> json) {
  return _Review.fromJson(json);
}

/// @nodoc
mixin _$Review {
  String get id => throw _privateConstructorUsedError;
  String get orderId => throw _privateConstructorUsedError;
  String get supplierGroupId => throw _privateConstructorUsedError;
  String get clientId => throw _privateConstructorUsedError;
  String get supplierId => throw _privateConstructorUsedError;
  int get stars => throw _privateConstructorUsedError;
  String get comment => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;

  /// Photos et vidéo de l'acheteur (`0061`). Le fournisseur les voit dans
  /// sa gestion des avis : un reproche illustré se traite autrement qu'un
  /// reproche décrit.
  List<String> get imagePaths => throw _privateConstructorUsedError;
  String? get videoPath => throw _privateConstructorUsedError;

  /// The supplier's public reply to this review, if they've written one —
  /// re-calling `ReviewRepository.reply` edits it in place rather than
  /// appending a second one.
  String? get supplierReply => throw _privateConstructorUsedError;
  DateTime? get supplierRepliedAt => throw _privateConstructorUsedError;

  /// Serializes this Review to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Review
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ReviewCopyWith<Review> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ReviewCopyWith<$Res> {
  factory $ReviewCopyWith(Review value, $Res Function(Review) then) =
      _$ReviewCopyWithImpl<$Res, Review>;
  @useResult
  $Res call({
    String id,
    String orderId,
    String supplierGroupId,
    String clientId,
    String supplierId,
    int stars,
    String comment,
    DateTime createdAt,
    List<String> imagePaths,
    String? videoPath,
    String? supplierReply,
    DateTime? supplierRepliedAt,
  });
}

/// @nodoc
class _$ReviewCopyWithImpl<$Res, $Val extends Review>
    implements $ReviewCopyWith<$Res> {
  _$ReviewCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Review
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? orderId = null,
    Object? supplierGroupId = null,
    Object? clientId = null,
    Object? supplierId = null,
    Object? stars = null,
    Object? comment = null,
    Object? createdAt = null,
    Object? imagePaths = null,
    Object? videoPath = freezed,
    Object? supplierReply = freezed,
    Object? supplierRepliedAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            orderId: null == orderId
                ? _value.orderId
                : orderId // ignore: cast_nullable_to_non_nullable
                      as String,
            supplierGroupId: null == supplierGroupId
                ? _value.supplierGroupId
                : supplierGroupId // ignore: cast_nullable_to_non_nullable
                      as String,
            clientId: null == clientId
                ? _value.clientId
                : clientId // ignore: cast_nullable_to_non_nullable
                      as String,
            supplierId: null == supplierId
                ? _value.supplierId
                : supplierId // ignore: cast_nullable_to_non_nullable
                      as String,
            stars: null == stars
                ? _value.stars
                : stars // ignore: cast_nullable_to_non_nullable
                      as int,
            comment: null == comment
                ? _value.comment
                : comment // ignore: cast_nullable_to_non_nullable
                      as String,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            imagePaths: null == imagePaths
                ? _value.imagePaths
                : imagePaths // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            videoPath: freezed == videoPath
                ? _value.videoPath
                : videoPath // ignore: cast_nullable_to_non_nullable
                      as String?,
            supplierReply: freezed == supplierReply
                ? _value.supplierReply
                : supplierReply // ignore: cast_nullable_to_non_nullable
                      as String?,
            supplierRepliedAt: freezed == supplierRepliedAt
                ? _value.supplierRepliedAt
                : supplierRepliedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ReviewImplCopyWith<$Res> implements $ReviewCopyWith<$Res> {
  factory _$$ReviewImplCopyWith(
    _$ReviewImpl value,
    $Res Function(_$ReviewImpl) then,
  ) = __$$ReviewImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String orderId,
    String supplierGroupId,
    String clientId,
    String supplierId,
    int stars,
    String comment,
    DateTime createdAt,
    List<String> imagePaths,
    String? videoPath,
    String? supplierReply,
    DateTime? supplierRepliedAt,
  });
}

/// @nodoc
class __$$ReviewImplCopyWithImpl<$Res>
    extends _$ReviewCopyWithImpl<$Res, _$ReviewImpl>
    implements _$$ReviewImplCopyWith<$Res> {
  __$$ReviewImplCopyWithImpl(
    _$ReviewImpl _value,
    $Res Function(_$ReviewImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Review
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? orderId = null,
    Object? supplierGroupId = null,
    Object? clientId = null,
    Object? supplierId = null,
    Object? stars = null,
    Object? comment = null,
    Object? createdAt = null,
    Object? imagePaths = null,
    Object? videoPath = freezed,
    Object? supplierReply = freezed,
    Object? supplierRepliedAt = freezed,
  }) {
    return _then(
      _$ReviewImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        orderId: null == orderId
            ? _value.orderId
            : orderId // ignore: cast_nullable_to_non_nullable
                  as String,
        supplierGroupId: null == supplierGroupId
            ? _value.supplierGroupId
            : supplierGroupId // ignore: cast_nullable_to_non_nullable
                  as String,
        clientId: null == clientId
            ? _value.clientId
            : clientId // ignore: cast_nullable_to_non_nullable
                  as String,
        supplierId: null == supplierId
            ? _value.supplierId
            : supplierId // ignore: cast_nullable_to_non_nullable
                  as String,
        stars: null == stars
            ? _value.stars
            : stars // ignore: cast_nullable_to_non_nullable
                  as int,
        comment: null == comment
            ? _value.comment
            : comment // ignore: cast_nullable_to_non_nullable
                  as String,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        imagePaths: null == imagePaths
            ? _value._imagePaths
            : imagePaths // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        videoPath: freezed == videoPath
            ? _value.videoPath
            : videoPath // ignore: cast_nullable_to_non_nullable
                  as String?,
        supplierReply: freezed == supplierReply
            ? _value.supplierReply
            : supplierReply // ignore: cast_nullable_to_non_nullable
                  as String?,
        supplierRepliedAt: freezed == supplierRepliedAt
            ? _value.supplierRepliedAt
            : supplierRepliedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ReviewImpl implements _Review {
  const _$ReviewImpl({
    required this.id,
    required this.orderId,
    required this.supplierGroupId,
    required this.clientId,
    required this.supplierId,
    required this.stars,
    required this.comment,
    required this.createdAt,
    final List<String> imagePaths = const [],
    this.videoPath,
    this.supplierReply,
    this.supplierRepliedAt,
  }) : _imagePaths = imagePaths;

  factory _$ReviewImpl.fromJson(Map<String, dynamic> json) =>
      _$$ReviewImplFromJson(json);

  @override
  final String id;
  @override
  final String orderId;
  @override
  final String supplierGroupId;
  @override
  final String clientId;
  @override
  final String supplierId;
  @override
  final int stars;
  @override
  final String comment;
  @override
  final DateTime createdAt;

  /// Photos et vidéo de l'acheteur (`0061`). Le fournisseur les voit dans
  /// sa gestion des avis : un reproche illustré se traite autrement qu'un
  /// reproche décrit.
  final List<String> _imagePaths;

  /// Photos et vidéo de l'acheteur (`0061`). Le fournisseur les voit dans
  /// sa gestion des avis : un reproche illustré se traite autrement qu'un
  /// reproche décrit.
  @override
  @JsonKey()
  List<String> get imagePaths {
    if (_imagePaths is EqualUnmodifiableListView) return _imagePaths;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_imagePaths);
  }

  @override
  final String? videoPath;

  /// The supplier's public reply to this review, if they've written one —
  /// re-calling `ReviewRepository.reply` edits it in place rather than
  /// appending a second one.
  @override
  final String? supplierReply;
  @override
  final DateTime? supplierRepliedAt;

  @override
  String toString() {
    return 'Review(id: $id, orderId: $orderId, supplierGroupId: $supplierGroupId, clientId: $clientId, supplierId: $supplierId, stars: $stars, comment: $comment, createdAt: $createdAt, imagePaths: $imagePaths, videoPath: $videoPath, supplierReply: $supplierReply, supplierRepliedAt: $supplierRepliedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ReviewImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.orderId, orderId) || other.orderId == orderId) &&
            (identical(other.supplierGroupId, supplierGroupId) ||
                other.supplierGroupId == supplierGroupId) &&
            (identical(other.clientId, clientId) ||
                other.clientId == clientId) &&
            (identical(other.supplierId, supplierId) ||
                other.supplierId == supplierId) &&
            (identical(other.stars, stars) || other.stars == stars) &&
            (identical(other.comment, comment) || other.comment == comment) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            const DeepCollectionEquality().equals(
              other._imagePaths,
              _imagePaths,
            ) &&
            (identical(other.videoPath, videoPath) ||
                other.videoPath == videoPath) &&
            (identical(other.supplierReply, supplierReply) ||
                other.supplierReply == supplierReply) &&
            (identical(other.supplierRepliedAt, supplierRepliedAt) ||
                other.supplierRepliedAt == supplierRepliedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    orderId,
    supplierGroupId,
    clientId,
    supplierId,
    stars,
    comment,
    createdAt,
    const DeepCollectionEquality().hash(_imagePaths),
    videoPath,
    supplierReply,
    supplierRepliedAt,
  );

  /// Create a copy of Review
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ReviewImplCopyWith<_$ReviewImpl> get copyWith =>
      __$$ReviewImplCopyWithImpl<_$ReviewImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ReviewImplToJson(this);
  }
}

abstract class _Review implements Review {
  const factory _Review({
    required final String id,
    required final String orderId,
    required final String supplierGroupId,
    required final String clientId,
    required final String supplierId,
    required final int stars,
    required final String comment,
    required final DateTime createdAt,
    final List<String> imagePaths,
    final String? videoPath,
    final String? supplierReply,
    final DateTime? supplierRepliedAt,
  }) = _$ReviewImpl;

  factory _Review.fromJson(Map<String, dynamic> json) = _$ReviewImpl.fromJson;

  @override
  String get id;
  @override
  String get orderId;
  @override
  String get supplierGroupId;
  @override
  String get clientId;
  @override
  String get supplierId;
  @override
  int get stars;
  @override
  String get comment;
  @override
  DateTime get createdAt;

  /// Photos et vidéo de l'acheteur (`0061`). Le fournisseur les voit dans
  /// sa gestion des avis : un reproche illustré se traite autrement qu'un
  /// reproche décrit.
  @override
  List<String> get imagePaths;
  @override
  String? get videoPath;

  /// The supplier's public reply to this review, if they've written one —
  /// re-calling `ReviewRepository.reply` edits it in place rather than
  /// appending a second one.
  @override
  String? get supplierReply;
  @override
  DateTime? get supplierRepliedAt;

  /// Create a copy of Review
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ReviewImplCopyWith<_$ReviewImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
