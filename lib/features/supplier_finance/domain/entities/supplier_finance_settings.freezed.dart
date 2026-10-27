// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'supplier_finance_settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

SupplierFinanceSettings _$SupplierFinanceSettingsFromJson(
  Map<String, dynamic> json,
) {
  return _SupplierFinanceSettings.fromJson(json);
}

/// @nodoc
mixin _$SupplierFinanceSettings {
  String get supplierId => throw _privateConstructorUsedError;
  double get commissionRatePercent => throw _privateConstructorUsedError;

  /// Serializes this SupplierFinanceSettings to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SupplierFinanceSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SupplierFinanceSettingsCopyWith<SupplierFinanceSettings> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SupplierFinanceSettingsCopyWith<$Res> {
  factory $SupplierFinanceSettingsCopyWith(
    SupplierFinanceSettings value,
    $Res Function(SupplierFinanceSettings) then,
  ) = _$SupplierFinanceSettingsCopyWithImpl<$Res, SupplierFinanceSettings>;
  @useResult
  $Res call({String supplierId, double commissionRatePercent});
}

/// @nodoc
class _$SupplierFinanceSettingsCopyWithImpl<
  $Res,
  $Val extends SupplierFinanceSettings
>
    implements $SupplierFinanceSettingsCopyWith<$Res> {
  _$SupplierFinanceSettingsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SupplierFinanceSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? supplierId = null, Object? commissionRatePercent = null}) {
    return _then(
      _value.copyWith(
            supplierId: null == supplierId
                ? _value.supplierId
                : supplierId // ignore: cast_nullable_to_non_nullable
                      as String,
            commissionRatePercent: null == commissionRatePercent
                ? _value.commissionRatePercent
                : commissionRatePercent // ignore: cast_nullable_to_non_nullable
                      as double,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SupplierFinanceSettingsImplCopyWith<$Res>
    implements $SupplierFinanceSettingsCopyWith<$Res> {
  factory _$$SupplierFinanceSettingsImplCopyWith(
    _$SupplierFinanceSettingsImpl value,
    $Res Function(_$SupplierFinanceSettingsImpl) then,
  ) = __$$SupplierFinanceSettingsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String supplierId, double commissionRatePercent});
}

/// @nodoc
class __$$SupplierFinanceSettingsImplCopyWithImpl<$Res>
    extends
        _$SupplierFinanceSettingsCopyWithImpl<
          $Res,
          _$SupplierFinanceSettingsImpl
        >
    implements _$$SupplierFinanceSettingsImplCopyWith<$Res> {
  __$$SupplierFinanceSettingsImplCopyWithImpl(
    _$SupplierFinanceSettingsImpl _value,
    $Res Function(_$SupplierFinanceSettingsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SupplierFinanceSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? supplierId = null, Object? commissionRatePercent = null}) {
    return _then(
      _$SupplierFinanceSettingsImpl(
        supplierId: null == supplierId
            ? _value.supplierId
            : supplierId // ignore: cast_nullable_to_non_nullable
                  as String,
        commissionRatePercent: null == commissionRatePercent
            ? _value.commissionRatePercent
            : commissionRatePercent // ignore: cast_nullable_to_non_nullable
                  as double,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SupplierFinanceSettingsImpl implements _SupplierFinanceSettings {
  const _$SupplierFinanceSettingsImpl({
    required this.supplierId,
    required this.commissionRatePercent,
  });

  factory _$SupplierFinanceSettingsImpl.fromJson(Map<String, dynamic> json) =>
      _$$SupplierFinanceSettingsImplFromJson(json);

  @override
  final String supplierId;
  @override
  final double commissionRatePercent;

  @override
  String toString() {
    return 'SupplierFinanceSettings(supplierId: $supplierId, commissionRatePercent: $commissionRatePercent)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SupplierFinanceSettingsImpl &&
            (identical(other.supplierId, supplierId) ||
                other.supplierId == supplierId) &&
            (identical(other.commissionRatePercent, commissionRatePercent) ||
                other.commissionRatePercent == commissionRatePercent));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, supplierId, commissionRatePercent);

  /// Create a copy of SupplierFinanceSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SupplierFinanceSettingsImplCopyWith<_$SupplierFinanceSettingsImpl>
  get copyWith =>
      __$$SupplierFinanceSettingsImplCopyWithImpl<
        _$SupplierFinanceSettingsImpl
      >(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SupplierFinanceSettingsImplToJson(this);
  }
}

abstract class _SupplierFinanceSettings implements SupplierFinanceSettings {
  const factory _SupplierFinanceSettings({
    required final String supplierId,
    required final double commissionRatePercent,
  }) = _$SupplierFinanceSettingsImpl;

  factory _SupplierFinanceSettings.fromJson(Map<String, dynamic> json) =
      _$SupplierFinanceSettingsImpl.fromJson;

  @override
  String get supplierId;
  @override
  double get commissionRatePercent;

  /// Create a copy of SupplierFinanceSettings
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SupplierFinanceSettingsImplCopyWith<_$SupplierFinanceSettingsImpl>
  get copyWith => throw _privateConstructorUsedError;
}
