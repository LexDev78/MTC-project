// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'product_review.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

ProductReview _$ProductReviewFromJson(Map<String, dynamic> json) {
  return _ProductReview.fromJson(json);
}

/// @nodoc
mixin _$ProductReview {
  String get id => throw _privateConstructorUsedError;
  int get stars => throw _privateConstructorUsedError;
  String get comment => throw _privateConstructorUsedError;

  /// Le titre de l'avis (`0119`), facultatif : une ligne qui résume.
  String? get title => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  String get authorName => throw _privateConstructorUsedError;

  /// Photos de l'acheteur — ce qui fait la valeur d'un avis, par
  /// différence avec les photos du vendeur.
  List<String> get imagePaths => throw _privateConstructorUsedError;
  String? get videoPath => throw _privateConstructorUsedError;
  String? get supplierReply => throw _privateConstructorUsedError;
  DateTime? get supplierRepliedAt => throw _privateConstructorUsedError;
  List<ReviewComment> get comments => throw _privateConstructorUsedError;

  /// Serializes this ProductReview to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ProductReview
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ProductReviewCopyWith<ProductReview> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ProductReviewCopyWith<$Res> {
  factory $ProductReviewCopyWith(
    ProductReview value,
    $Res Function(ProductReview) then,
  ) = _$ProductReviewCopyWithImpl<$Res, ProductReview>;
  @useResult
  $Res call({
    String id,
    int stars,
    String comment,
    String? title,
    DateTime createdAt,
    String authorName,
    List<String> imagePaths,
    String? videoPath,
    String? supplierReply,
    DateTime? supplierRepliedAt,
    List<ReviewComment> comments,
  });
}

/// @nodoc
class _$ProductReviewCopyWithImpl<$Res, $Val extends ProductReview>
    implements $ProductReviewCopyWith<$Res> {
  _$ProductReviewCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ProductReview
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? stars = null,
    Object? comment = null,
    Object? title = freezed,
    Object? createdAt = null,
    Object? authorName = null,
    Object? imagePaths = null,
    Object? videoPath = freezed,
    Object? supplierReply = freezed,
    Object? supplierRepliedAt = freezed,
    Object? comments = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            stars: null == stars
                ? _value.stars
                : stars // ignore: cast_nullable_to_non_nullable
                      as int,
            comment: null == comment
                ? _value.comment
                : comment // ignore: cast_nullable_to_non_nullable
                      as String,
            title: freezed == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String?,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            authorName: null == authorName
                ? _value.authorName
                : authorName // ignore: cast_nullable_to_non_nullable
                      as String,
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
            comments: null == comments
                ? _value.comments
                : comments // ignore: cast_nullable_to_non_nullable
                      as List<ReviewComment>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ProductReviewImplCopyWith<$Res>
    implements $ProductReviewCopyWith<$Res> {
  factory _$$ProductReviewImplCopyWith(
    _$ProductReviewImpl value,
    $Res Function(_$ProductReviewImpl) then,
  ) = __$$ProductReviewImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    int stars,
    String comment,
    String? title,
    DateTime createdAt,
    String authorName,
    List<String> imagePaths,
    String? videoPath,
    String? supplierReply,
    DateTime? supplierRepliedAt,
    List<ReviewComment> comments,
  });
}

/// @nodoc
class __$$ProductReviewImplCopyWithImpl<$Res>
    extends _$ProductReviewCopyWithImpl<$Res, _$ProductReviewImpl>
    implements _$$ProductReviewImplCopyWith<$Res> {
  __$$ProductReviewImplCopyWithImpl(
    _$ProductReviewImpl _value,
    $Res Function(_$ProductReviewImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ProductReview
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? stars = null,
    Object? comment = null,
    Object? title = freezed,
    Object? createdAt = null,
    Object? authorName = null,
    Object? imagePaths = null,
    Object? videoPath = freezed,
    Object? supplierReply = freezed,
    Object? supplierRepliedAt = freezed,
    Object? comments = null,
  }) {
    return _then(
      _$ProductReviewImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        stars: null == stars
            ? _value.stars
            : stars // ignore: cast_nullable_to_non_nullable
                  as int,
        comment: null == comment
            ? _value.comment
            : comment // ignore: cast_nullable_to_non_nullable
                  as String,
        title: freezed == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String?,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        authorName: null == authorName
            ? _value.authorName
            : authorName // ignore: cast_nullable_to_non_nullable
                  as String,
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
        comments: null == comments
            ? _value._comments
            : comments // ignore: cast_nullable_to_non_nullable
                  as List<ReviewComment>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ProductReviewImpl implements _ProductReview {
  const _$ProductReviewImpl({
    required this.id,
    required this.stars,
    required this.comment,
    this.title,
    required this.createdAt,
    required this.authorName,
    final List<String> imagePaths = const [],
    this.videoPath,
    this.supplierReply,
    this.supplierRepliedAt,
    final List<ReviewComment> comments = const [],
  }) : _imagePaths = imagePaths,
       _comments = comments;

  factory _$ProductReviewImpl.fromJson(Map<String, dynamic> json) =>
      _$$ProductReviewImplFromJson(json);

  @override
  final String id;
  @override
  final int stars;
  @override
  final String comment;

  /// Le titre de l'avis (`0119`), facultatif : une ligne qui résume.
  @override
  final String? title;
  @override
  final DateTime createdAt;
  @override
  final String authorName;

  /// Photos de l'acheteur — ce qui fait la valeur d'un avis, par
  /// différence avec les photos du vendeur.
  final List<String> _imagePaths;

  /// Photos de l'acheteur — ce qui fait la valeur d'un avis, par
  /// différence avec les photos du vendeur.
  @override
  @JsonKey()
  List<String> get imagePaths {
    if (_imagePaths is EqualUnmodifiableListView) return _imagePaths;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_imagePaths);
  }

  @override
  final String? videoPath;
  @override
  final String? supplierReply;
  @override
  final DateTime? supplierRepliedAt;
  final List<ReviewComment> _comments;
  @override
  @JsonKey()
  List<ReviewComment> get comments {
    if (_comments is EqualUnmodifiableListView) return _comments;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_comments);
  }

  @override
  String toString() {
    return 'ProductReview(id: $id, stars: $stars, comment: $comment, title: $title, createdAt: $createdAt, authorName: $authorName, imagePaths: $imagePaths, videoPath: $videoPath, supplierReply: $supplierReply, supplierRepliedAt: $supplierRepliedAt, comments: $comments)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ProductReviewImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.stars, stars) || other.stars == stars) &&
            (identical(other.comment, comment) || other.comment == comment) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.authorName, authorName) ||
                other.authorName == authorName) &&
            const DeepCollectionEquality().equals(
              other._imagePaths,
              _imagePaths,
            ) &&
            (identical(other.videoPath, videoPath) ||
                other.videoPath == videoPath) &&
            (identical(other.supplierReply, supplierReply) ||
                other.supplierReply == supplierReply) &&
            (identical(other.supplierRepliedAt, supplierRepliedAt) ||
                other.supplierRepliedAt == supplierRepliedAt) &&
            const DeepCollectionEquality().equals(other._comments, _comments));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    stars,
    comment,
    title,
    createdAt,
    authorName,
    const DeepCollectionEquality().hash(_imagePaths),
    videoPath,
    supplierReply,
    supplierRepliedAt,
    const DeepCollectionEquality().hash(_comments),
  );

  /// Create a copy of ProductReview
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ProductReviewImplCopyWith<_$ProductReviewImpl> get copyWith =>
      __$$ProductReviewImplCopyWithImpl<_$ProductReviewImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ProductReviewImplToJson(this);
  }
}

abstract class _ProductReview implements ProductReview {
  const factory _ProductReview({
    required final String id,
    required final int stars,
    required final String comment,
    final String? title,
    required final DateTime createdAt,
    required final String authorName,
    final List<String> imagePaths,
    final String? videoPath,
    final String? supplierReply,
    final DateTime? supplierRepliedAt,
    final List<ReviewComment> comments,
  }) = _$ProductReviewImpl;

  factory _ProductReview.fromJson(Map<String, dynamic> json) =
      _$ProductReviewImpl.fromJson;

  @override
  String get id;
  @override
  int get stars;
  @override
  String get comment;

  /// Le titre de l'avis (`0119`), facultatif : une ligne qui résume.
  @override
  String? get title;
  @override
  DateTime get createdAt;
  @override
  String get authorName;

  /// Photos de l'acheteur — ce qui fait la valeur d'un avis, par
  /// différence avec les photos du vendeur.
  @override
  List<String> get imagePaths;
  @override
  String? get videoPath;
  @override
  String? get supplierReply;
  @override
  DateTime? get supplierRepliedAt;
  @override
  List<ReviewComment> get comments;

  /// Create a copy of ProductReview
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ProductReviewImplCopyWith<_$ProductReviewImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ReviewComment _$ReviewCommentFromJson(Map<String, dynamic> json) {
  return _ReviewComment.fromJson(json);
}

/// @nodoc
mixin _$ReviewComment {
  String get id => throw _privateConstructorUsedError;
  String get body => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  String get authorName => throw _privateConstructorUsedError;

  /// Calculé à l'écriture, pas déclaré par l'auteur : un commentaire du
  /// vendeur ne se lit pas comme celui d'un acheteur.
  bool get authorIsSupplier => throw _privateConstructorUsedError;
  List<String> get imagePaths => throw _privateConstructorUsedError;
  String? get videoPath => throw _privateConstructorUsedError;

  /// Serializes this ReviewComment to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ReviewComment
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ReviewCommentCopyWith<ReviewComment> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ReviewCommentCopyWith<$Res> {
  factory $ReviewCommentCopyWith(
    ReviewComment value,
    $Res Function(ReviewComment) then,
  ) = _$ReviewCommentCopyWithImpl<$Res, ReviewComment>;
  @useResult
  $Res call({
    String id,
    String body,
    DateTime createdAt,
    String authorName,
    bool authorIsSupplier,
    List<String> imagePaths,
    String? videoPath,
  });
}

/// @nodoc
class _$ReviewCommentCopyWithImpl<$Res, $Val extends ReviewComment>
    implements $ReviewCommentCopyWith<$Res> {
  _$ReviewCommentCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ReviewComment
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? body = null,
    Object? createdAt = null,
    Object? authorName = null,
    Object? authorIsSupplier = null,
    Object? imagePaths = null,
    Object? videoPath = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            body: null == body
                ? _value.body
                : body // ignore: cast_nullable_to_non_nullable
                      as String,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            authorName: null == authorName
                ? _value.authorName
                : authorName // ignore: cast_nullable_to_non_nullable
                      as String,
            authorIsSupplier: null == authorIsSupplier
                ? _value.authorIsSupplier
                : authorIsSupplier // ignore: cast_nullable_to_non_nullable
                      as bool,
            imagePaths: null == imagePaths
                ? _value.imagePaths
                : imagePaths // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            videoPath: freezed == videoPath
                ? _value.videoPath
                : videoPath // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ReviewCommentImplCopyWith<$Res>
    implements $ReviewCommentCopyWith<$Res> {
  factory _$$ReviewCommentImplCopyWith(
    _$ReviewCommentImpl value,
    $Res Function(_$ReviewCommentImpl) then,
  ) = __$$ReviewCommentImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String body,
    DateTime createdAt,
    String authorName,
    bool authorIsSupplier,
    List<String> imagePaths,
    String? videoPath,
  });
}

/// @nodoc
class __$$ReviewCommentImplCopyWithImpl<$Res>
    extends _$ReviewCommentCopyWithImpl<$Res, _$ReviewCommentImpl>
    implements _$$ReviewCommentImplCopyWith<$Res> {
  __$$ReviewCommentImplCopyWithImpl(
    _$ReviewCommentImpl _value,
    $Res Function(_$ReviewCommentImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ReviewComment
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? body = null,
    Object? createdAt = null,
    Object? authorName = null,
    Object? authorIsSupplier = null,
    Object? imagePaths = null,
    Object? videoPath = freezed,
  }) {
    return _then(
      _$ReviewCommentImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        body: null == body
            ? _value.body
            : body // ignore: cast_nullable_to_non_nullable
                  as String,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        authorName: null == authorName
            ? _value.authorName
            : authorName // ignore: cast_nullable_to_non_nullable
                  as String,
        authorIsSupplier: null == authorIsSupplier
            ? _value.authorIsSupplier
            : authorIsSupplier // ignore: cast_nullable_to_non_nullable
                  as bool,
        imagePaths: null == imagePaths
            ? _value._imagePaths
            : imagePaths // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        videoPath: freezed == videoPath
            ? _value.videoPath
            : videoPath // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ReviewCommentImpl implements _ReviewComment {
  const _$ReviewCommentImpl({
    required this.id,
    required this.body,
    required this.createdAt,
    required this.authorName,
    this.authorIsSupplier = false,
    final List<String> imagePaths = const [],
    this.videoPath,
  }) : _imagePaths = imagePaths;

  factory _$ReviewCommentImpl.fromJson(Map<String, dynamic> json) =>
      _$$ReviewCommentImplFromJson(json);

  @override
  final String id;
  @override
  final String body;
  @override
  final DateTime createdAt;
  @override
  final String authorName;

  /// Calculé à l'écriture, pas déclaré par l'auteur : un commentaire du
  /// vendeur ne se lit pas comme celui d'un acheteur.
  @override
  @JsonKey()
  final bool authorIsSupplier;
  final List<String> _imagePaths;
  @override
  @JsonKey()
  List<String> get imagePaths {
    if (_imagePaths is EqualUnmodifiableListView) return _imagePaths;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_imagePaths);
  }

  @override
  final String? videoPath;

  @override
  String toString() {
    return 'ReviewComment(id: $id, body: $body, createdAt: $createdAt, authorName: $authorName, authorIsSupplier: $authorIsSupplier, imagePaths: $imagePaths, videoPath: $videoPath)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ReviewCommentImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.body, body) || other.body == body) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.authorName, authorName) ||
                other.authorName == authorName) &&
            (identical(other.authorIsSupplier, authorIsSupplier) ||
                other.authorIsSupplier == authorIsSupplier) &&
            const DeepCollectionEquality().equals(
              other._imagePaths,
              _imagePaths,
            ) &&
            (identical(other.videoPath, videoPath) ||
                other.videoPath == videoPath));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    body,
    createdAt,
    authorName,
    authorIsSupplier,
    const DeepCollectionEquality().hash(_imagePaths),
    videoPath,
  );

  /// Create a copy of ReviewComment
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ReviewCommentImplCopyWith<_$ReviewCommentImpl> get copyWith =>
      __$$ReviewCommentImplCopyWithImpl<_$ReviewCommentImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ReviewCommentImplToJson(this);
  }
}

abstract class _ReviewComment implements ReviewComment {
  const factory _ReviewComment({
    required final String id,
    required final String body,
    required final DateTime createdAt,
    required final String authorName,
    final bool authorIsSupplier,
    final List<String> imagePaths,
    final String? videoPath,
  }) = _$ReviewCommentImpl;

  factory _ReviewComment.fromJson(Map<String, dynamic> json) =
      _$ReviewCommentImpl.fromJson;

  @override
  String get id;
  @override
  String get body;
  @override
  DateTime get createdAt;
  @override
  String get authorName;

  /// Calculé à l'écriture, pas déclaré par l'auteur : un commentaire du
  /// vendeur ne se lit pas comme celui d'un acheteur.
  @override
  bool get authorIsSupplier;
  @override
  List<String> get imagePaths;
  @override
  String? get videoPath;

  /// Create a copy of ReviewComment
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ReviewCommentImplCopyWith<_$ReviewCommentImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$ProductReviewSummary {
  int get reviewCount => throw _privateConstructorUsedError;
  double get ratingAverage => throw _privateConstructorUsedError;

  /// Create a copy of ProductReviewSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ProductReviewSummaryCopyWith<ProductReviewSummary> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ProductReviewSummaryCopyWith<$Res> {
  factory $ProductReviewSummaryCopyWith(
    ProductReviewSummary value,
    $Res Function(ProductReviewSummary) then,
  ) = _$ProductReviewSummaryCopyWithImpl<$Res, ProductReviewSummary>;
  @useResult
  $Res call({int reviewCount, double ratingAverage});
}

/// @nodoc
class _$ProductReviewSummaryCopyWithImpl<
  $Res,
  $Val extends ProductReviewSummary
>
    implements $ProductReviewSummaryCopyWith<$Res> {
  _$ProductReviewSummaryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ProductReviewSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? reviewCount = null, Object? ratingAverage = null}) {
    return _then(
      _value.copyWith(
            reviewCount: null == reviewCount
                ? _value.reviewCount
                : reviewCount // ignore: cast_nullable_to_non_nullable
                      as int,
            ratingAverage: null == ratingAverage
                ? _value.ratingAverage
                : ratingAverage // ignore: cast_nullable_to_non_nullable
                      as double,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ProductReviewSummaryImplCopyWith<$Res>
    implements $ProductReviewSummaryCopyWith<$Res> {
  factory _$$ProductReviewSummaryImplCopyWith(
    _$ProductReviewSummaryImpl value,
    $Res Function(_$ProductReviewSummaryImpl) then,
  ) = __$$ProductReviewSummaryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int reviewCount, double ratingAverage});
}

/// @nodoc
class __$$ProductReviewSummaryImplCopyWithImpl<$Res>
    extends _$ProductReviewSummaryCopyWithImpl<$Res, _$ProductReviewSummaryImpl>
    implements _$$ProductReviewSummaryImplCopyWith<$Res> {
  __$$ProductReviewSummaryImplCopyWithImpl(
    _$ProductReviewSummaryImpl _value,
    $Res Function(_$ProductReviewSummaryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ProductReviewSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? reviewCount = null, Object? ratingAverage = null}) {
    return _then(
      _$ProductReviewSummaryImpl(
        reviewCount: null == reviewCount
            ? _value.reviewCount
            : reviewCount // ignore: cast_nullable_to_non_nullable
                  as int,
        ratingAverage: null == ratingAverage
            ? _value.ratingAverage
            : ratingAverage // ignore: cast_nullable_to_non_nullable
                  as double,
      ),
    );
  }
}

/// @nodoc

class _$ProductReviewSummaryImpl implements _ProductReviewSummary {
  const _$ProductReviewSummaryImpl({
    required this.reviewCount,
    required this.ratingAverage,
  });

  @override
  final int reviewCount;
  @override
  final double ratingAverage;

  @override
  String toString() {
    return 'ProductReviewSummary(reviewCount: $reviewCount, ratingAverage: $ratingAverage)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ProductReviewSummaryImpl &&
            (identical(other.reviewCount, reviewCount) ||
                other.reviewCount == reviewCount) &&
            (identical(other.ratingAverage, ratingAverage) ||
                other.ratingAverage == ratingAverage));
  }

  @override
  int get hashCode => Object.hash(runtimeType, reviewCount, ratingAverage);

  /// Create a copy of ProductReviewSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ProductReviewSummaryImplCopyWith<_$ProductReviewSummaryImpl>
  get copyWith =>
      __$$ProductReviewSummaryImplCopyWithImpl<_$ProductReviewSummaryImpl>(
        this,
        _$identity,
      );
}

abstract class _ProductReviewSummary implements ProductReviewSummary {
  const factory _ProductReviewSummary({
    required final int reviewCount,
    required final double ratingAverage,
  }) = _$ProductReviewSummaryImpl;

  @override
  int get reviewCount;
  @override
  double get ratingAverage;

  /// Create a copy of ProductReviewSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ProductReviewSummaryImplCopyWith<_$ProductReviewSummaryImpl>
  get copyWith => throw _privateConstructorUsedError;
}
