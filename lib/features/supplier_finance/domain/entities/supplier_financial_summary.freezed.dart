// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'supplier_financial_summary.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$SupplierFinancialSummary {
  int get grossFcfa => throw _privateConstructorUsedError;
  int get commissionFcfa => throw _privateConstructorUsedError;
  int get netFcfa => throw _privateConstructorUsedError;

  /// Sum of every payout not `rejected` (`requested`/`processing`/`paid`
  /// all reserve funds against the balance — only a rejection releases
  /// them back).
  int get paidOutFcfa => throw _privateConstructorUsedError;

  /// `netFcfa - paidOutFcfa` — what's left to request as a new payout.
  int get availableFcfa => throw _privateConstructorUsedError;

  /// Create a copy of SupplierFinancialSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SupplierFinancialSummaryCopyWith<SupplierFinancialSummary> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SupplierFinancialSummaryCopyWith<$Res> {
  factory $SupplierFinancialSummaryCopyWith(
    SupplierFinancialSummary value,
    $Res Function(SupplierFinancialSummary) then,
  ) = _$SupplierFinancialSummaryCopyWithImpl<$Res, SupplierFinancialSummary>;
  @useResult
  $Res call({
    int grossFcfa,
    int commissionFcfa,
    int netFcfa,
    int paidOutFcfa,
    int availableFcfa,
  });
}

/// @nodoc
class _$SupplierFinancialSummaryCopyWithImpl<
  $Res,
  $Val extends SupplierFinancialSummary
>
    implements $SupplierFinancialSummaryCopyWith<$Res> {
  _$SupplierFinancialSummaryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SupplierFinancialSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? grossFcfa = null,
    Object? commissionFcfa = null,
    Object? netFcfa = null,
    Object? paidOutFcfa = null,
    Object? availableFcfa = null,
  }) {
    return _then(
      _value.copyWith(
            grossFcfa: null == grossFcfa
                ? _value.grossFcfa
                : grossFcfa // ignore: cast_nullable_to_non_nullable
                      as int,
            commissionFcfa: null == commissionFcfa
                ? _value.commissionFcfa
                : commissionFcfa // ignore: cast_nullable_to_non_nullable
                      as int,
            netFcfa: null == netFcfa
                ? _value.netFcfa
                : netFcfa // ignore: cast_nullable_to_non_nullable
                      as int,
            paidOutFcfa: null == paidOutFcfa
                ? _value.paidOutFcfa
                : paidOutFcfa // ignore: cast_nullable_to_non_nullable
                      as int,
            availableFcfa: null == availableFcfa
                ? _value.availableFcfa
                : availableFcfa // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SupplierFinancialSummaryImplCopyWith<$Res>
    implements $SupplierFinancialSummaryCopyWith<$Res> {
  factory _$$SupplierFinancialSummaryImplCopyWith(
    _$SupplierFinancialSummaryImpl value,
    $Res Function(_$SupplierFinancialSummaryImpl) then,
  ) = __$$SupplierFinancialSummaryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int grossFcfa,
    int commissionFcfa,
    int netFcfa,
    int paidOutFcfa,
    int availableFcfa,
  });
}

/// @nodoc
class __$$SupplierFinancialSummaryImplCopyWithImpl<$Res>
    extends
        _$SupplierFinancialSummaryCopyWithImpl<
          $Res,
          _$SupplierFinancialSummaryImpl
        >
    implements _$$SupplierFinancialSummaryImplCopyWith<$Res> {
  __$$SupplierFinancialSummaryImplCopyWithImpl(
    _$SupplierFinancialSummaryImpl _value,
    $Res Function(_$SupplierFinancialSummaryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SupplierFinancialSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? grossFcfa = null,
    Object? commissionFcfa = null,
    Object? netFcfa = null,
    Object? paidOutFcfa = null,
    Object? availableFcfa = null,
  }) {
    return _then(
      _$SupplierFinancialSummaryImpl(
        grossFcfa: null == grossFcfa
            ? _value.grossFcfa
            : grossFcfa // ignore: cast_nullable_to_non_nullable
                  as int,
        commissionFcfa: null == commissionFcfa
            ? _value.commissionFcfa
            : commissionFcfa // ignore: cast_nullable_to_non_nullable
                  as int,
        netFcfa: null == netFcfa
            ? _value.netFcfa
            : netFcfa // ignore: cast_nullable_to_non_nullable
                  as int,
        paidOutFcfa: null == paidOutFcfa
            ? _value.paidOutFcfa
            : paidOutFcfa // ignore: cast_nullable_to_non_nullable
                  as int,
        availableFcfa: null == availableFcfa
            ? _value.availableFcfa
            : availableFcfa // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc

class _$SupplierFinancialSummaryImpl implements _SupplierFinancialSummary {
  const _$SupplierFinancialSummaryImpl({
    required this.grossFcfa,
    required this.commissionFcfa,
    required this.netFcfa,
    required this.paidOutFcfa,
    required this.availableFcfa,
  });

  @override
  final int grossFcfa;
  @override
  final int commissionFcfa;
  @override
  final int netFcfa;

  /// Sum of every payout not `rejected` (`requested`/`processing`/`paid`
  /// all reserve funds against the balance — only a rejection releases
  /// them back).
  @override
  final int paidOutFcfa;

  /// `netFcfa - paidOutFcfa` — what's left to request as a new payout.
  @override
  final int availableFcfa;

  @override
  String toString() {
    return 'SupplierFinancialSummary(grossFcfa: $grossFcfa, commissionFcfa: $commissionFcfa, netFcfa: $netFcfa, paidOutFcfa: $paidOutFcfa, availableFcfa: $availableFcfa)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SupplierFinancialSummaryImpl &&
            (identical(other.grossFcfa, grossFcfa) ||
                other.grossFcfa == grossFcfa) &&
            (identical(other.commissionFcfa, commissionFcfa) ||
                other.commissionFcfa == commissionFcfa) &&
            (identical(other.netFcfa, netFcfa) || other.netFcfa == netFcfa) &&
            (identical(other.paidOutFcfa, paidOutFcfa) ||
                other.paidOutFcfa == paidOutFcfa) &&
            (identical(other.availableFcfa, availableFcfa) ||
                other.availableFcfa == availableFcfa));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    grossFcfa,
    commissionFcfa,
    netFcfa,
    paidOutFcfa,
    availableFcfa,
  );

  /// Create a copy of SupplierFinancialSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SupplierFinancialSummaryImplCopyWith<_$SupplierFinancialSummaryImpl>
  get copyWith =>
      __$$SupplierFinancialSummaryImplCopyWithImpl<
        _$SupplierFinancialSummaryImpl
      >(this, _$identity);
}

abstract class _SupplierFinancialSummary implements SupplierFinancialSummary {
  const factory _SupplierFinancialSummary({
    required final int grossFcfa,
    required final int commissionFcfa,
    required final int netFcfa,
    required final int paidOutFcfa,
    required final int availableFcfa,
  }) = _$SupplierFinancialSummaryImpl;

  @override
  int get grossFcfa;
  @override
  int get commissionFcfa;
  @override
  int get netFcfa;

  /// Sum of every payout not `rejected` (`requested`/`processing`/`paid`
  /// all reserve funds against the balance — only a rejection releases
  /// them back).
  @override
  int get paidOutFcfa;

  /// `netFcfa - paidOutFcfa` — what's left to request as a new payout.
  @override
  int get availableFcfa;

  /// Create a copy of SupplierFinancialSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SupplierFinancialSummaryImplCopyWith<_$SupplierFinancialSummaryImpl>
  get copyWith => throw _privateConstructorUsedError;
}
