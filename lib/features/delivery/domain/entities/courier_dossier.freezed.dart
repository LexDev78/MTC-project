// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'courier_dossier.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$CourierDocument {
  String get id => throw _privateConstructorUsedError;
  CourierDocumentType get type => throw _privateConstructorUsedError;
  String get filePath => throw _privateConstructorUsedError;
  DateTime get uploadedAt => throw _privateConstructorUsedError;

  /// Create a copy of CourierDocument
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CourierDocumentCopyWith<CourierDocument> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CourierDocumentCopyWith<$Res> {
  factory $CourierDocumentCopyWith(
    CourierDocument value,
    $Res Function(CourierDocument) then,
  ) = _$CourierDocumentCopyWithImpl<$Res, CourierDocument>;
  @useResult
  $Res call({
    String id,
    CourierDocumentType type,
    String filePath,
    DateTime uploadedAt,
  });
}

/// @nodoc
class _$CourierDocumentCopyWithImpl<$Res, $Val extends CourierDocument>
    implements $CourierDocumentCopyWith<$Res> {
  _$CourierDocumentCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CourierDocument
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? filePath = null,
    Object? uploadedAt = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            type: null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                      as CourierDocumentType,
            filePath: null == filePath
                ? _value.filePath
                : filePath // ignore: cast_nullable_to_non_nullable
                      as String,
            uploadedAt: null == uploadedAt
                ? _value.uploadedAt
                : uploadedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$CourierDocumentImplCopyWith<$Res>
    implements $CourierDocumentCopyWith<$Res> {
  factory _$$CourierDocumentImplCopyWith(
    _$CourierDocumentImpl value,
    $Res Function(_$CourierDocumentImpl) then,
  ) = __$$CourierDocumentImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    CourierDocumentType type,
    String filePath,
    DateTime uploadedAt,
  });
}

/// @nodoc
class __$$CourierDocumentImplCopyWithImpl<$Res>
    extends _$CourierDocumentCopyWithImpl<$Res, _$CourierDocumentImpl>
    implements _$$CourierDocumentImplCopyWith<$Res> {
  __$$CourierDocumentImplCopyWithImpl(
    _$CourierDocumentImpl _value,
    $Res Function(_$CourierDocumentImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CourierDocument
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? filePath = null,
    Object? uploadedAt = null,
  }) {
    return _then(
      _$CourierDocumentImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        type: null == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as CourierDocumentType,
        filePath: null == filePath
            ? _value.filePath
            : filePath // ignore: cast_nullable_to_non_nullable
                  as String,
        uploadedAt: null == uploadedAt
            ? _value.uploadedAt
            : uploadedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc

class _$CourierDocumentImpl implements _CourierDocument {
  const _$CourierDocumentImpl({
    required this.id,
    required this.type,
    required this.filePath,
    required this.uploadedAt,
  });

  @override
  final String id;
  @override
  final CourierDocumentType type;
  @override
  final String filePath;
  @override
  final DateTime uploadedAt;

  @override
  String toString() {
    return 'CourierDocument(id: $id, type: $type, filePath: $filePath, uploadedAt: $uploadedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CourierDocumentImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.filePath, filePath) ||
                other.filePath == filePath) &&
            (identical(other.uploadedAt, uploadedAt) ||
                other.uploadedAt == uploadedAt));
  }

  @override
  int get hashCode => Object.hash(runtimeType, id, type, filePath, uploadedAt);

  /// Create a copy of CourierDocument
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CourierDocumentImplCopyWith<_$CourierDocumentImpl> get copyWith =>
      __$$CourierDocumentImplCopyWithImpl<_$CourierDocumentImpl>(
        this,
        _$identity,
      );
}

abstract class _CourierDocument implements CourierDocument {
  const factory _CourierDocument({
    required final String id,
    required final CourierDocumentType type,
    required final String filePath,
    required final DateTime uploadedAt,
  }) = _$CourierDocumentImpl;

  @override
  String get id;
  @override
  CourierDocumentType get type;
  @override
  String get filePath;
  @override
  DateTime get uploadedAt;

  /// Create a copy of CourierDocument
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CourierDocumentImplCopyWith<_$CourierDocumentImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$CourierDossier {
  List<CourierDocument> get documents => throw _privateConstructorUsedError;
  CourierVehicleType? get vehicleType => throw _privateConstructorUsedError;
  String? get vehicleLabel => throw _privateConstructorUsedError;

  /// Nul tant que les pièces ne sont pas déposées. C'est cette date, et
  /// non le statut, qui distingue « je n'ai rien envoyé » de « MTC
  /// examine mon dossier » : un refus la remet à nul pour rendre la main
  /// au livreur (`review_courier`, `0105`).
  DateTime? get submittedAt => throw _privateConstructorUsedError;
  String? get rejectionReason => throw _privateConstructorUsedError;

  /// Create a copy of CourierDossier
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CourierDossierCopyWith<CourierDossier> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CourierDossierCopyWith<$Res> {
  factory $CourierDossierCopyWith(
    CourierDossier value,
    $Res Function(CourierDossier) then,
  ) = _$CourierDossierCopyWithImpl<$Res, CourierDossier>;
  @useResult
  $Res call({
    List<CourierDocument> documents,
    CourierVehicleType? vehicleType,
    String? vehicleLabel,
    DateTime? submittedAt,
    String? rejectionReason,
  });
}

/// @nodoc
class _$CourierDossierCopyWithImpl<$Res, $Val extends CourierDossier>
    implements $CourierDossierCopyWith<$Res> {
  _$CourierDossierCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CourierDossier
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? documents = null,
    Object? vehicleType = freezed,
    Object? vehicleLabel = freezed,
    Object? submittedAt = freezed,
    Object? rejectionReason = freezed,
  }) {
    return _then(
      _value.copyWith(
            documents: null == documents
                ? _value.documents
                : documents // ignore: cast_nullable_to_non_nullable
                      as List<CourierDocument>,
            vehicleType: freezed == vehicleType
                ? _value.vehicleType
                : vehicleType // ignore: cast_nullable_to_non_nullable
                      as CourierVehicleType?,
            vehicleLabel: freezed == vehicleLabel
                ? _value.vehicleLabel
                : vehicleLabel // ignore: cast_nullable_to_non_nullable
                      as String?,
            submittedAt: freezed == submittedAt
                ? _value.submittedAt
                : submittedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            rejectionReason: freezed == rejectionReason
                ? _value.rejectionReason
                : rejectionReason // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$CourierDossierImplCopyWith<$Res>
    implements $CourierDossierCopyWith<$Res> {
  factory _$$CourierDossierImplCopyWith(
    _$CourierDossierImpl value,
    $Res Function(_$CourierDossierImpl) then,
  ) = __$$CourierDossierImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    List<CourierDocument> documents,
    CourierVehicleType? vehicleType,
    String? vehicleLabel,
    DateTime? submittedAt,
    String? rejectionReason,
  });
}

/// @nodoc
class __$$CourierDossierImplCopyWithImpl<$Res>
    extends _$CourierDossierCopyWithImpl<$Res, _$CourierDossierImpl>
    implements _$$CourierDossierImplCopyWith<$Res> {
  __$$CourierDossierImplCopyWithImpl(
    _$CourierDossierImpl _value,
    $Res Function(_$CourierDossierImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CourierDossier
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? documents = null,
    Object? vehicleType = freezed,
    Object? vehicleLabel = freezed,
    Object? submittedAt = freezed,
    Object? rejectionReason = freezed,
  }) {
    return _then(
      _$CourierDossierImpl(
        documents: null == documents
            ? _value._documents
            : documents // ignore: cast_nullable_to_non_nullable
                  as List<CourierDocument>,
        vehicleType: freezed == vehicleType
            ? _value.vehicleType
            : vehicleType // ignore: cast_nullable_to_non_nullable
                  as CourierVehicleType?,
        vehicleLabel: freezed == vehicleLabel
            ? _value.vehicleLabel
            : vehicleLabel // ignore: cast_nullable_to_non_nullable
                  as String?,
        submittedAt: freezed == submittedAt
            ? _value.submittedAt
            : submittedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        rejectionReason: freezed == rejectionReason
            ? _value.rejectionReason
            : rejectionReason // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc

class _$CourierDossierImpl implements _CourierDossier {
  const _$CourierDossierImpl({
    required final List<CourierDocument> documents,
    this.vehicleType,
    this.vehicleLabel,
    this.submittedAt,
    this.rejectionReason,
  }) : _documents = documents;

  final List<CourierDocument> _documents;
  @override
  List<CourierDocument> get documents {
    if (_documents is EqualUnmodifiableListView) return _documents;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_documents);
  }

  @override
  final CourierVehicleType? vehicleType;
  @override
  final String? vehicleLabel;

  /// Nul tant que les pièces ne sont pas déposées. C'est cette date, et
  /// non le statut, qui distingue « je n'ai rien envoyé » de « MTC
  /// examine mon dossier » : un refus la remet à nul pour rendre la main
  /// au livreur (`review_courier`, `0105`).
  @override
  final DateTime? submittedAt;
  @override
  final String? rejectionReason;

  @override
  String toString() {
    return 'CourierDossier(documents: $documents, vehicleType: $vehicleType, vehicleLabel: $vehicleLabel, submittedAt: $submittedAt, rejectionReason: $rejectionReason)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CourierDossierImpl &&
            const DeepCollectionEquality().equals(
              other._documents,
              _documents,
            ) &&
            (identical(other.vehicleType, vehicleType) ||
                other.vehicleType == vehicleType) &&
            (identical(other.vehicleLabel, vehicleLabel) ||
                other.vehicleLabel == vehicleLabel) &&
            (identical(other.submittedAt, submittedAt) ||
                other.submittedAt == submittedAt) &&
            (identical(other.rejectionReason, rejectionReason) ||
                other.rejectionReason == rejectionReason));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_documents),
    vehicleType,
    vehicleLabel,
    submittedAt,
    rejectionReason,
  );

  /// Create a copy of CourierDossier
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CourierDossierImplCopyWith<_$CourierDossierImpl> get copyWith =>
      __$$CourierDossierImplCopyWithImpl<_$CourierDossierImpl>(
        this,
        _$identity,
      );
}

abstract class _CourierDossier implements CourierDossier {
  const factory _CourierDossier({
    required final List<CourierDocument> documents,
    final CourierVehicleType? vehicleType,
    final String? vehicleLabel,
    final DateTime? submittedAt,
    final String? rejectionReason,
  }) = _$CourierDossierImpl;

  @override
  List<CourierDocument> get documents;
  @override
  CourierVehicleType? get vehicleType;
  @override
  String? get vehicleLabel;

  /// Nul tant que les pièces ne sont pas déposées. C'est cette date, et
  /// non le statut, qui distingue « je n'ai rien envoyé » de « MTC
  /// examine mon dossier » : un refus la remet à nul pour rendre la main
  /// au livreur (`review_courier`, `0105`).
  @override
  DateTime? get submittedAt;
  @override
  String? get rejectionReason;

  /// Create a copy of CourierDossier
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CourierDossierImplCopyWith<_$CourierDossierImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
