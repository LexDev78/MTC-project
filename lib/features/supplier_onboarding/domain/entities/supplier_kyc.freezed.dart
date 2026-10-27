// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'supplier_kyc.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

SupplierDocument _$SupplierDocumentFromJson(Map<String, dynamic> json) {
  return _SupplierDocument.fromJson(json);
}

/// @nodoc
mixin _$SupplierDocument {
  String get id => throw _privateConstructorUsedError;
  SupplierDocumentType get type => throw _privateConstructorUsedError;
  String get filePath => throw _privateConstructorUsedError;
  DateTime get uploadedAt => throw _privateConstructorUsedError;

  /// Serializes this SupplierDocument to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SupplierDocument
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SupplierDocumentCopyWith<SupplierDocument> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SupplierDocumentCopyWith<$Res> {
  factory $SupplierDocumentCopyWith(
    SupplierDocument value,
    $Res Function(SupplierDocument) then,
  ) = _$SupplierDocumentCopyWithImpl<$Res, SupplierDocument>;
  @useResult
  $Res call({
    String id,
    SupplierDocumentType type,
    String filePath,
    DateTime uploadedAt,
  });
}

/// @nodoc
class _$SupplierDocumentCopyWithImpl<$Res, $Val extends SupplierDocument>
    implements $SupplierDocumentCopyWith<$Res> {
  _$SupplierDocumentCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SupplierDocument
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
                      as SupplierDocumentType,
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
abstract class _$$SupplierDocumentImplCopyWith<$Res>
    implements $SupplierDocumentCopyWith<$Res> {
  factory _$$SupplierDocumentImplCopyWith(
    _$SupplierDocumentImpl value,
    $Res Function(_$SupplierDocumentImpl) then,
  ) = __$$SupplierDocumentImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    SupplierDocumentType type,
    String filePath,
    DateTime uploadedAt,
  });
}

/// @nodoc
class __$$SupplierDocumentImplCopyWithImpl<$Res>
    extends _$SupplierDocumentCopyWithImpl<$Res, _$SupplierDocumentImpl>
    implements _$$SupplierDocumentImplCopyWith<$Res> {
  __$$SupplierDocumentImplCopyWithImpl(
    _$SupplierDocumentImpl _value,
    $Res Function(_$SupplierDocumentImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SupplierDocument
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
      _$SupplierDocumentImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        type: null == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as SupplierDocumentType,
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
@JsonSerializable()
class _$SupplierDocumentImpl implements _SupplierDocument {
  const _$SupplierDocumentImpl({
    required this.id,
    required this.type,
    required this.filePath,
    required this.uploadedAt,
  });

  factory _$SupplierDocumentImpl.fromJson(Map<String, dynamic> json) =>
      _$$SupplierDocumentImplFromJson(json);

  @override
  final String id;
  @override
  final SupplierDocumentType type;
  @override
  final String filePath;
  @override
  final DateTime uploadedAt;

  @override
  String toString() {
    return 'SupplierDocument(id: $id, type: $type, filePath: $filePath, uploadedAt: $uploadedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SupplierDocumentImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.filePath, filePath) ||
                other.filePath == filePath) &&
            (identical(other.uploadedAt, uploadedAt) ||
                other.uploadedAt == uploadedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, type, filePath, uploadedAt);

  /// Create a copy of SupplierDocument
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SupplierDocumentImplCopyWith<_$SupplierDocumentImpl> get copyWith =>
      __$$SupplierDocumentImplCopyWithImpl<_$SupplierDocumentImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$SupplierDocumentImplToJson(this);
  }
}

abstract class _SupplierDocument implements SupplierDocument {
  const factory _SupplierDocument({
    required final String id,
    required final SupplierDocumentType type,
    required final String filePath,
    required final DateTime uploadedAt,
  }) = _$SupplierDocumentImpl;

  factory _SupplierDocument.fromJson(Map<String, dynamic> json) =
      _$SupplierDocumentImpl.fromJson;

  @override
  String get id;
  @override
  SupplierDocumentType get type;
  @override
  String get filePath;
  @override
  DateTime get uploadedAt;

  /// Create a copy of SupplierDocument
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SupplierDocumentImplCopyWith<_$SupplierDocumentImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$DataProcessingConsent {
  bool get accepted => throw _privateConstructorUsedError;
  DateTime get acceptedAt => throw _privateConstructorUsedError;
  String get policyVersion => throw _privateConstructorUsedError;

  /// Create a copy of DataProcessingConsent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DataProcessingConsentCopyWith<DataProcessingConsent> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DataProcessingConsentCopyWith<$Res> {
  factory $DataProcessingConsentCopyWith(
    DataProcessingConsent value,
    $Res Function(DataProcessingConsent) then,
  ) = _$DataProcessingConsentCopyWithImpl<$Res, DataProcessingConsent>;
  @useResult
  $Res call({bool accepted, DateTime acceptedAt, String policyVersion});
}

/// @nodoc
class _$DataProcessingConsentCopyWithImpl<
  $Res,
  $Val extends DataProcessingConsent
>
    implements $DataProcessingConsentCopyWith<$Res> {
  _$DataProcessingConsentCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DataProcessingConsent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? accepted = null,
    Object? acceptedAt = null,
    Object? policyVersion = null,
  }) {
    return _then(
      _value.copyWith(
            accepted: null == accepted
                ? _value.accepted
                : accepted // ignore: cast_nullable_to_non_nullable
                      as bool,
            acceptedAt: null == acceptedAt
                ? _value.acceptedAt
                : acceptedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            policyVersion: null == policyVersion
                ? _value.policyVersion
                : policyVersion // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$DataProcessingConsentImplCopyWith<$Res>
    implements $DataProcessingConsentCopyWith<$Res> {
  factory _$$DataProcessingConsentImplCopyWith(
    _$DataProcessingConsentImpl value,
    $Res Function(_$DataProcessingConsentImpl) then,
  ) = __$$DataProcessingConsentImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({bool accepted, DateTime acceptedAt, String policyVersion});
}

/// @nodoc
class __$$DataProcessingConsentImplCopyWithImpl<$Res>
    extends
        _$DataProcessingConsentCopyWithImpl<$Res, _$DataProcessingConsentImpl>
    implements _$$DataProcessingConsentImplCopyWith<$Res> {
  __$$DataProcessingConsentImplCopyWithImpl(
    _$DataProcessingConsentImpl _value,
    $Res Function(_$DataProcessingConsentImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DataProcessingConsent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? accepted = null,
    Object? acceptedAt = null,
    Object? policyVersion = null,
  }) {
    return _then(
      _$DataProcessingConsentImpl(
        accepted: null == accepted
            ? _value.accepted
            : accepted // ignore: cast_nullable_to_non_nullable
                  as bool,
        acceptedAt: null == acceptedAt
            ? _value.acceptedAt
            : acceptedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        policyVersion: null == policyVersion
            ? _value.policyVersion
            : policyVersion // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$DataProcessingConsentImpl implements _DataProcessingConsent {
  const _$DataProcessingConsentImpl({
    required this.accepted,
    required this.acceptedAt,
    required this.policyVersion,
  });

  @override
  final bool accepted;
  @override
  final DateTime acceptedAt;
  @override
  final String policyVersion;

  @override
  String toString() {
    return 'DataProcessingConsent(accepted: $accepted, acceptedAt: $acceptedAt, policyVersion: $policyVersion)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DataProcessingConsentImpl &&
            (identical(other.accepted, accepted) ||
                other.accepted == accepted) &&
            (identical(other.acceptedAt, acceptedAt) ||
                other.acceptedAt == acceptedAt) &&
            (identical(other.policyVersion, policyVersion) ||
                other.policyVersion == policyVersion));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, accepted, acceptedAt, policyVersion);

  /// Create a copy of DataProcessingConsent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DataProcessingConsentImplCopyWith<_$DataProcessingConsentImpl>
  get copyWith =>
      __$$DataProcessingConsentImplCopyWithImpl<_$DataProcessingConsentImpl>(
        this,
        _$identity,
      );
}

abstract class _DataProcessingConsent implements DataProcessingConsent {
  const factory _DataProcessingConsent({
    required final bool accepted,
    required final DateTime acceptedAt,
    required final String policyVersion,
  }) = _$DataProcessingConsentImpl;

  @override
  bool get accepted;
  @override
  DateTime get acceptedAt;
  @override
  String get policyVersion;

  /// Create a copy of DataProcessingConsent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DataProcessingConsentImplCopyWith<_$DataProcessingConsentImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$SupplierKyc {
  String get id => throw _privateConstructorUsedError;
  String get supplierId => throw _privateConstructorUsedError;
  KycReviewStatus get status => throw _privateConstructorUsedError;
  List<SupplierDocument> get documents => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime? get submittedAt => throw _privateConstructorUsedError;
  DateTime? get reviewedAt => throw _privateConstructorUsedError;
  String? get reviewedByStaffId => throw _privateConstructorUsedError;
  String? get rejectionReason => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
      String id,
      String supplierId,
      KycReviewStatus status,
      List<SupplierDocument> documents,
      DateTime createdAt,
      DateTime? submittedAt,
      DateTime? reviewedAt,
      String? reviewedByStaffId,
      String? rejectionReason,
      String? rccmNumber,
      String? taxId,
      String? legalRepresentativeName,
      String? registeredAddress,
    )
    company,
    required TResult Function(
      String id,
      String supplierId,
      KycReviewStatus status,
      List<SupplierDocument> documents,
      DateTime createdAt,
      DateTime? submittedAt,
      DateTime? reviewedAt,
      String? reviewedByStaffId,
      String? rejectionReason,
      DataProcessingConsent? consent,
    )
    individual,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
      String id,
      String supplierId,
      KycReviewStatus status,
      List<SupplierDocument> documents,
      DateTime createdAt,
      DateTime? submittedAt,
      DateTime? reviewedAt,
      String? reviewedByStaffId,
      String? rejectionReason,
      String? rccmNumber,
      String? taxId,
      String? legalRepresentativeName,
      String? registeredAddress,
    )?
    company,
    TResult? Function(
      String id,
      String supplierId,
      KycReviewStatus status,
      List<SupplierDocument> documents,
      DateTime createdAt,
      DateTime? submittedAt,
      DateTime? reviewedAt,
      String? reviewedByStaffId,
      String? rejectionReason,
      DataProcessingConsent? consent,
    )?
    individual,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
      String id,
      String supplierId,
      KycReviewStatus status,
      List<SupplierDocument> documents,
      DateTime createdAt,
      DateTime? submittedAt,
      DateTime? reviewedAt,
      String? reviewedByStaffId,
      String? rejectionReason,
      String? rccmNumber,
      String? taxId,
      String? legalRepresentativeName,
      String? registeredAddress,
    )?
    company,
    TResult Function(
      String id,
      String supplierId,
      KycReviewStatus status,
      List<SupplierDocument> documents,
      DateTime createdAt,
      DateTime? submittedAt,
      DateTime? reviewedAt,
      String? reviewedByStaffId,
      String? rejectionReason,
      DataProcessingConsent? consent,
    )?
    individual,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(SupplierKycCompany value) company,
    required TResult Function(SupplierKycIndividual value) individual,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(SupplierKycCompany value)? company,
    TResult? Function(SupplierKycIndividual value)? individual,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(SupplierKycCompany value)? company,
    TResult Function(SupplierKycIndividual value)? individual,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;

  /// Create a copy of SupplierKyc
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SupplierKycCopyWith<SupplierKyc> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SupplierKycCopyWith<$Res> {
  factory $SupplierKycCopyWith(
    SupplierKyc value,
    $Res Function(SupplierKyc) then,
  ) = _$SupplierKycCopyWithImpl<$Res, SupplierKyc>;
  @useResult
  $Res call({
    String id,
    String supplierId,
    KycReviewStatus status,
    List<SupplierDocument> documents,
    DateTime createdAt,
    DateTime? submittedAt,
    DateTime? reviewedAt,
    String? reviewedByStaffId,
    String? rejectionReason,
  });
}

/// @nodoc
class _$SupplierKycCopyWithImpl<$Res, $Val extends SupplierKyc>
    implements $SupplierKycCopyWith<$Res> {
  _$SupplierKycCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SupplierKyc
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? supplierId = null,
    Object? status = null,
    Object? documents = null,
    Object? createdAt = null,
    Object? submittedAt = freezed,
    Object? reviewedAt = freezed,
    Object? reviewedByStaffId = freezed,
    Object? rejectionReason = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            supplierId: null == supplierId
                ? _value.supplierId
                : supplierId // ignore: cast_nullable_to_non_nullable
                      as String,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as KycReviewStatus,
            documents: null == documents
                ? _value.documents
                : documents // ignore: cast_nullable_to_non_nullable
                      as List<SupplierDocument>,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            submittedAt: freezed == submittedAt
                ? _value.submittedAt
                : submittedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            reviewedAt: freezed == reviewedAt
                ? _value.reviewedAt
                : reviewedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            reviewedByStaffId: freezed == reviewedByStaffId
                ? _value.reviewedByStaffId
                : reviewedByStaffId // ignore: cast_nullable_to_non_nullable
                      as String?,
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
abstract class _$$SupplierKycCompanyImplCopyWith<$Res>
    implements $SupplierKycCopyWith<$Res> {
  factory _$$SupplierKycCompanyImplCopyWith(
    _$SupplierKycCompanyImpl value,
    $Res Function(_$SupplierKycCompanyImpl) then,
  ) = __$$SupplierKycCompanyImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String supplierId,
    KycReviewStatus status,
    List<SupplierDocument> documents,
    DateTime createdAt,
    DateTime? submittedAt,
    DateTime? reviewedAt,
    String? reviewedByStaffId,
    String? rejectionReason,
    String? rccmNumber,
    String? taxId,
    String? legalRepresentativeName,
    String? registeredAddress,
  });
}

/// @nodoc
class __$$SupplierKycCompanyImplCopyWithImpl<$Res>
    extends _$SupplierKycCopyWithImpl<$Res, _$SupplierKycCompanyImpl>
    implements _$$SupplierKycCompanyImplCopyWith<$Res> {
  __$$SupplierKycCompanyImplCopyWithImpl(
    _$SupplierKycCompanyImpl _value,
    $Res Function(_$SupplierKycCompanyImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SupplierKyc
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? supplierId = null,
    Object? status = null,
    Object? documents = null,
    Object? createdAt = null,
    Object? submittedAt = freezed,
    Object? reviewedAt = freezed,
    Object? reviewedByStaffId = freezed,
    Object? rejectionReason = freezed,
    Object? rccmNumber = freezed,
    Object? taxId = freezed,
    Object? legalRepresentativeName = freezed,
    Object? registeredAddress = freezed,
  }) {
    return _then(
      _$SupplierKycCompanyImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        supplierId: null == supplierId
            ? _value.supplierId
            : supplierId // ignore: cast_nullable_to_non_nullable
                  as String,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as KycReviewStatus,
        documents: null == documents
            ? _value._documents
            : documents // ignore: cast_nullable_to_non_nullable
                  as List<SupplierDocument>,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        submittedAt: freezed == submittedAt
            ? _value.submittedAt
            : submittedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        reviewedAt: freezed == reviewedAt
            ? _value.reviewedAt
            : reviewedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        reviewedByStaffId: freezed == reviewedByStaffId
            ? _value.reviewedByStaffId
            : reviewedByStaffId // ignore: cast_nullable_to_non_nullable
                  as String?,
        rejectionReason: freezed == rejectionReason
            ? _value.rejectionReason
            : rejectionReason // ignore: cast_nullable_to_non_nullable
                  as String?,
        rccmNumber: freezed == rccmNumber
            ? _value.rccmNumber
            : rccmNumber // ignore: cast_nullable_to_non_nullable
                  as String?,
        taxId: freezed == taxId
            ? _value.taxId
            : taxId // ignore: cast_nullable_to_non_nullable
                  as String?,
        legalRepresentativeName: freezed == legalRepresentativeName
            ? _value.legalRepresentativeName
            : legalRepresentativeName // ignore: cast_nullable_to_non_nullable
                  as String?,
        registeredAddress: freezed == registeredAddress
            ? _value.registeredAddress
            : registeredAddress // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc

class _$SupplierKycCompanyImpl implements SupplierKycCompany {
  const _$SupplierKycCompanyImpl({
    required this.id,
    required this.supplierId,
    required this.status,
    required final List<SupplierDocument> documents,
    required this.createdAt,
    this.submittedAt,
    this.reviewedAt,
    this.reviewedByStaffId,
    this.rejectionReason,
    this.rccmNumber,
    this.taxId,
    this.legalRepresentativeName,
    this.registeredAddress,
  }) : _documents = documents;

  @override
  final String id;
  @override
  final String supplierId;
  @override
  final KycReviewStatus status;
  final List<SupplierDocument> _documents;
  @override
  List<SupplierDocument> get documents {
    if (_documents is EqualUnmodifiableListView) return _documents;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_documents);
  }

  @override
  final DateTime createdAt;
  @override
  final DateTime? submittedAt;
  @override
  final DateTime? reviewedAt;
  @override
  final String? reviewedByStaffId;
  @override
  final String? rejectionReason;
  @override
  final String? rccmNumber;
  @override
  final String? taxId;
  @override
  final String? legalRepresentativeName;
  @override
  final String? registeredAddress;

  @override
  String toString() {
    return 'SupplierKyc.company(id: $id, supplierId: $supplierId, status: $status, documents: $documents, createdAt: $createdAt, submittedAt: $submittedAt, reviewedAt: $reviewedAt, reviewedByStaffId: $reviewedByStaffId, rejectionReason: $rejectionReason, rccmNumber: $rccmNumber, taxId: $taxId, legalRepresentativeName: $legalRepresentativeName, registeredAddress: $registeredAddress)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SupplierKycCompanyImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.supplierId, supplierId) ||
                other.supplierId == supplierId) &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(
              other._documents,
              _documents,
            ) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.submittedAt, submittedAt) ||
                other.submittedAt == submittedAt) &&
            (identical(other.reviewedAt, reviewedAt) ||
                other.reviewedAt == reviewedAt) &&
            (identical(other.reviewedByStaffId, reviewedByStaffId) ||
                other.reviewedByStaffId == reviewedByStaffId) &&
            (identical(other.rejectionReason, rejectionReason) ||
                other.rejectionReason == rejectionReason) &&
            (identical(other.rccmNumber, rccmNumber) ||
                other.rccmNumber == rccmNumber) &&
            (identical(other.taxId, taxId) || other.taxId == taxId) &&
            (identical(
                  other.legalRepresentativeName,
                  legalRepresentativeName,
                ) ||
                other.legalRepresentativeName == legalRepresentativeName) &&
            (identical(other.registeredAddress, registeredAddress) ||
                other.registeredAddress == registeredAddress));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    supplierId,
    status,
    const DeepCollectionEquality().hash(_documents),
    createdAt,
    submittedAt,
    reviewedAt,
    reviewedByStaffId,
    rejectionReason,
    rccmNumber,
    taxId,
    legalRepresentativeName,
    registeredAddress,
  );

  /// Create a copy of SupplierKyc
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SupplierKycCompanyImplCopyWith<_$SupplierKycCompanyImpl> get copyWith =>
      __$$SupplierKycCompanyImplCopyWithImpl<_$SupplierKycCompanyImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
      String id,
      String supplierId,
      KycReviewStatus status,
      List<SupplierDocument> documents,
      DateTime createdAt,
      DateTime? submittedAt,
      DateTime? reviewedAt,
      String? reviewedByStaffId,
      String? rejectionReason,
      String? rccmNumber,
      String? taxId,
      String? legalRepresentativeName,
      String? registeredAddress,
    )
    company,
    required TResult Function(
      String id,
      String supplierId,
      KycReviewStatus status,
      List<SupplierDocument> documents,
      DateTime createdAt,
      DateTime? submittedAt,
      DateTime? reviewedAt,
      String? reviewedByStaffId,
      String? rejectionReason,
      DataProcessingConsent? consent,
    )
    individual,
  }) {
    return company(
      id,
      supplierId,
      status,
      documents,
      createdAt,
      submittedAt,
      reviewedAt,
      reviewedByStaffId,
      rejectionReason,
      rccmNumber,
      taxId,
      legalRepresentativeName,
      registeredAddress,
    );
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
      String id,
      String supplierId,
      KycReviewStatus status,
      List<SupplierDocument> documents,
      DateTime createdAt,
      DateTime? submittedAt,
      DateTime? reviewedAt,
      String? reviewedByStaffId,
      String? rejectionReason,
      String? rccmNumber,
      String? taxId,
      String? legalRepresentativeName,
      String? registeredAddress,
    )?
    company,
    TResult? Function(
      String id,
      String supplierId,
      KycReviewStatus status,
      List<SupplierDocument> documents,
      DateTime createdAt,
      DateTime? submittedAt,
      DateTime? reviewedAt,
      String? reviewedByStaffId,
      String? rejectionReason,
      DataProcessingConsent? consent,
    )?
    individual,
  }) {
    return company?.call(
      id,
      supplierId,
      status,
      documents,
      createdAt,
      submittedAt,
      reviewedAt,
      reviewedByStaffId,
      rejectionReason,
      rccmNumber,
      taxId,
      legalRepresentativeName,
      registeredAddress,
    );
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
      String id,
      String supplierId,
      KycReviewStatus status,
      List<SupplierDocument> documents,
      DateTime createdAt,
      DateTime? submittedAt,
      DateTime? reviewedAt,
      String? reviewedByStaffId,
      String? rejectionReason,
      String? rccmNumber,
      String? taxId,
      String? legalRepresentativeName,
      String? registeredAddress,
    )?
    company,
    TResult Function(
      String id,
      String supplierId,
      KycReviewStatus status,
      List<SupplierDocument> documents,
      DateTime createdAt,
      DateTime? submittedAt,
      DateTime? reviewedAt,
      String? reviewedByStaffId,
      String? rejectionReason,
      DataProcessingConsent? consent,
    )?
    individual,
    required TResult orElse(),
  }) {
    if (company != null) {
      return company(
        id,
        supplierId,
        status,
        documents,
        createdAt,
        submittedAt,
        reviewedAt,
        reviewedByStaffId,
        rejectionReason,
        rccmNumber,
        taxId,
        legalRepresentativeName,
        registeredAddress,
      );
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(SupplierKycCompany value) company,
    required TResult Function(SupplierKycIndividual value) individual,
  }) {
    return company(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(SupplierKycCompany value)? company,
    TResult? Function(SupplierKycIndividual value)? individual,
  }) {
    return company?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(SupplierKycCompany value)? company,
    TResult Function(SupplierKycIndividual value)? individual,
    required TResult orElse(),
  }) {
    if (company != null) {
      return company(this);
    }
    return orElse();
  }
}

abstract class SupplierKycCompany implements SupplierKyc {
  const factory SupplierKycCompany({
    required final String id,
    required final String supplierId,
    required final KycReviewStatus status,
    required final List<SupplierDocument> documents,
    required final DateTime createdAt,
    final DateTime? submittedAt,
    final DateTime? reviewedAt,
    final String? reviewedByStaffId,
    final String? rejectionReason,
    final String? rccmNumber,
    final String? taxId,
    final String? legalRepresentativeName,
    final String? registeredAddress,
  }) = _$SupplierKycCompanyImpl;

  @override
  String get id;
  @override
  String get supplierId;
  @override
  KycReviewStatus get status;
  @override
  List<SupplierDocument> get documents;
  @override
  DateTime get createdAt;
  @override
  DateTime? get submittedAt;
  @override
  DateTime? get reviewedAt;
  @override
  String? get reviewedByStaffId;
  @override
  String? get rejectionReason;
  String? get rccmNumber;
  String? get taxId;
  String? get legalRepresentativeName;
  String? get registeredAddress;

  /// Create a copy of SupplierKyc
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SupplierKycCompanyImplCopyWith<_$SupplierKycCompanyImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$SupplierKycIndividualImplCopyWith<$Res>
    implements $SupplierKycCopyWith<$Res> {
  factory _$$SupplierKycIndividualImplCopyWith(
    _$SupplierKycIndividualImpl value,
    $Res Function(_$SupplierKycIndividualImpl) then,
  ) = __$$SupplierKycIndividualImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String supplierId,
    KycReviewStatus status,
    List<SupplierDocument> documents,
    DateTime createdAt,
    DateTime? submittedAt,
    DateTime? reviewedAt,
    String? reviewedByStaffId,
    String? rejectionReason,
    DataProcessingConsent? consent,
  });

  $DataProcessingConsentCopyWith<$Res>? get consent;
}

/// @nodoc
class __$$SupplierKycIndividualImplCopyWithImpl<$Res>
    extends _$SupplierKycCopyWithImpl<$Res, _$SupplierKycIndividualImpl>
    implements _$$SupplierKycIndividualImplCopyWith<$Res> {
  __$$SupplierKycIndividualImplCopyWithImpl(
    _$SupplierKycIndividualImpl _value,
    $Res Function(_$SupplierKycIndividualImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SupplierKyc
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? supplierId = null,
    Object? status = null,
    Object? documents = null,
    Object? createdAt = null,
    Object? submittedAt = freezed,
    Object? reviewedAt = freezed,
    Object? reviewedByStaffId = freezed,
    Object? rejectionReason = freezed,
    Object? consent = freezed,
  }) {
    return _then(
      _$SupplierKycIndividualImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        supplierId: null == supplierId
            ? _value.supplierId
            : supplierId // ignore: cast_nullable_to_non_nullable
                  as String,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as KycReviewStatus,
        documents: null == documents
            ? _value._documents
            : documents // ignore: cast_nullable_to_non_nullable
                  as List<SupplierDocument>,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        submittedAt: freezed == submittedAt
            ? _value.submittedAt
            : submittedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        reviewedAt: freezed == reviewedAt
            ? _value.reviewedAt
            : reviewedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        reviewedByStaffId: freezed == reviewedByStaffId
            ? _value.reviewedByStaffId
            : reviewedByStaffId // ignore: cast_nullable_to_non_nullable
                  as String?,
        rejectionReason: freezed == rejectionReason
            ? _value.rejectionReason
            : rejectionReason // ignore: cast_nullable_to_non_nullable
                  as String?,
        consent: freezed == consent
            ? _value.consent
            : consent // ignore: cast_nullable_to_non_nullable
                  as DataProcessingConsent?,
      ),
    );
  }

  /// Create a copy of SupplierKyc
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $DataProcessingConsentCopyWith<$Res>? get consent {
    if (_value.consent == null) {
      return null;
    }

    return $DataProcessingConsentCopyWith<$Res>(_value.consent!, (value) {
      return _then(_value.copyWith(consent: value));
    });
  }
}

/// @nodoc

class _$SupplierKycIndividualImpl implements SupplierKycIndividual {
  const _$SupplierKycIndividualImpl({
    required this.id,
    required this.supplierId,
    required this.status,
    required final List<SupplierDocument> documents,
    required this.createdAt,
    this.submittedAt,
    this.reviewedAt,
    this.reviewedByStaffId,
    this.rejectionReason,
    this.consent,
  }) : _documents = documents;

  @override
  final String id;
  @override
  final String supplierId;
  @override
  final KycReviewStatus status;
  final List<SupplierDocument> _documents;
  @override
  List<SupplierDocument> get documents {
    if (_documents is EqualUnmodifiableListView) return _documents;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_documents);
  }

  @override
  final DateTime createdAt;
  @override
  final DateTime? submittedAt;
  @override
  final DateTime? reviewedAt;
  @override
  final String? reviewedByStaffId;
  @override
  final String? rejectionReason;
  @override
  final DataProcessingConsent? consent;

  @override
  String toString() {
    return 'SupplierKyc.individual(id: $id, supplierId: $supplierId, status: $status, documents: $documents, createdAt: $createdAt, submittedAt: $submittedAt, reviewedAt: $reviewedAt, reviewedByStaffId: $reviewedByStaffId, rejectionReason: $rejectionReason, consent: $consent)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SupplierKycIndividualImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.supplierId, supplierId) ||
                other.supplierId == supplierId) &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(
              other._documents,
              _documents,
            ) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.submittedAt, submittedAt) ||
                other.submittedAt == submittedAt) &&
            (identical(other.reviewedAt, reviewedAt) ||
                other.reviewedAt == reviewedAt) &&
            (identical(other.reviewedByStaffId, reviewedByStaffId) ||
                other.reviewedByStaffId == reviewedByStaffId) &&
            (identical(other.rejectionReason, rejectionReason) ||
                other.rejectionReason == rejectionReason) &&
            (identical(other.consent, consent) || other.consent == consent));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    supplierId,
    status,
    const DeepCollectionEquality().hash(_documents),
    createdAt,
    submittedAt,
    reviewedAt,
    reviewedByStaffId,
    rejectionReason,
    consent,
  );

  /// Create a copy of SupplierKyc
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SupplierKycIndividualImplCopyWith<_$SupplierKycIndividualImpl>
  get copyWith =>
      __$$SupplierKycIndividualImplCopyWithImpl<_$SupplierKycIndividualImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
      String id,
      String supplierId,
      KycReviewStatus status,
      List<SupplierDocument> documents,
      DateTime createdAt,
      DateTime? submittedAt,
      DateTime? reviewedAt,
      String? reviewedByStaffId,
      String? rejectionReason,
      String? rccmNumber,
      String? taxId,
      String? legalRepresentativeName,
      String? registeredAddress,
    )
    company,
    required TResult Function(
      String id,
      String supplierId,
      KycReviewStatus status,
      List<SupplierDocument> documents,
      DateTime createdAt,
      DateTime? submittedAt,
      DateTime? reviewedAt,
      String? reviewedByStaffId,
      String? rejectionReason,
      DataProcessingConsent? consent,
    )
    individual,
  }) {
    return individual(
      id,
      supplierId,
      status,
      documents,
      createdAt,
      submittedAt,
      reviewedAt,
      reviewedByStaffId,
      rejectionReason,
      consent,
    );
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
      String id,
      String supplierId,
      KycReviewStatus status,
      List<SupplierDocument> documents,
      DateTime createdAt,
      DateTime? submittedAt,
      DateTime? reviewedAt,
      String? reviewedByStaffId,
      String? rejectionReason,
      String? rccmNumber,
      String? taxId,
      String? legalRepresentativeName,
      String? registeredAddress,
    )?
    company,
    TResult? Function(
      String id,
      String supplierId,
      KycReviewStatus status,
      List<SupplierDocument> documents,
      DateTime createdAt,
      DateTime? submittedAt,
      DateTime? reviewedAt,
      String? reviewedByStaffId,
      String? rejectionReason,
      DataProcessingConsent? consent,
    )?
    individual,
  }) {
    return individual?.call(
      id,
      supplierId,
      status,
      documents,
      createdAt,
      submittedAt,
      reviewedAt,
      reviewedByStaffId,
      rejectionReason,
      consent,
    );
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
      String id,
      String supplierId,
      KycReviewStatus status,
      List<SupplierDocument> documents,
      DateTime createdAt,
      DateTime? submittedAt,
      DateTime? reviewedAt,
      String? reviewedByStaffId,
      String? rejectionReason,
      String? rccmNumber,
      String? taxId,
      String? legalRepresentativeName,
      String? registeredAddress,
    )?
    company,
    TResult Function(
      String id,
      String supplierId,
      KycReviewStatus status,
      List<SupplierDocument> documents,
      DateTime createdAt,
      DateTime? submittedAt,
      DateTime? reviewedAt,
      String? reviewedByStaffId,
      String? rejectionReason,
      DataProcessingConsent? consent,
    )?
    individual,
    required TResult orElse(),
  }) {
    if (individual != null) {
      return individual(
        id,
        supplierId,
        status,
        documents,
        createdAt,
        submittedAt,
        reviewedAt,
        reviewedByStaffId,
        rejectionReason,
        consent,
      );
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(SupplierKycCompany value) company,
    required TResult Function(SupplierKycIndividual value) individual,
  }) {
    return individual(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(SupplierKycCompany value)? company,
    TResult? Function(SupplierKycIndividual value)? individual,
  }) {
    return individual?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(SupplierKycCompany value)? company,
    TResult Function(SupplierKycIndividual value)? individual,
    required TResult orElse(),
  }) {
    if (individual != null) {
      return individual(this);
    }
    return orElse();
  }
}

abstract class SupplierKycIndividual implements SupplierKyc {
  const factory SupplierKycIndividual({
    required final String id,
    required final String supplierId,
    required final KycReviewStatus status,
    required final List<SupplierDocument> documents,
    required final DateTime createdAt,
    final DateTime? submittedAt,
    final DateTime? reviewedAt,
    final String? reviewedByStaffId,
    final String? rejectionReason,
    final DataProcessingConsent? consent,
  }) = _$SupplierKycIndividualImpl;

  @override
  String get id;
  @override
  String get supplierId;
  @override
  KycReviewStatus get status;
  @override
  List<SupplierDocument> get documents;
  @override
  DateTime get createdAt;
  @override
  DateTime? get submittedAt;
  @override
  DateTime? get reviewedAt;
  @override
  String? get reviewedByStaffId;
  @override
  String? get rejectionReason;
  DataProcessingConsent? get consent;

  /// Create a copy of SupplierKyc
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SupplierKycIndividualImplCopyWith<_$SupplierKycIndividualImpl>
  get copyWith => throw _privateConstructorUsedError;
}
