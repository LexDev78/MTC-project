import 'package:freezed_annotation/freezed_annotation.dart';

/// When the client pays for the order — mocked, no real payment gateway is
/// wired up. [now] simulates a Mobile Money confirmation at checkout time;
/// [onDelivery] is cash (or Mobile Money) collected by the courier/agency.
enum PaymentMethod {
  now,
  @JsonValue('on_delivery')
  onDelivery;

  String get label => switch (this) {
    PaymentMethod.now => 'Maintenant',
    PaymentMethod.onDelivery => 'À la livraison',
  };
}

enum PaymentStatus {
  paid,
  @JsonValue('pending_on_delivery')
  pendingOnDelivery;

  String get label => switch (this) {
    PaymentStatus.paid => 'Payé',
    PaymentStatus.pendingOnDelivery => 'À payer à la livraison',
  };
}

/// The two Mobile Money operators covering Mali — offered when
/// [PaymentMethod.now] is chosen.
enum MobileMoneyProvider {
  @JsonValue('orange_money')
  orangeMoney,
  @JsonValue('moov_money')
  moovMoney;

  String get label => switch (this) {
    MobileMoneyProvider.orangeMoney => 'Orange Money',
    MobileMoneyProvider.moovMoney => 'Moov Money',
  };
}
