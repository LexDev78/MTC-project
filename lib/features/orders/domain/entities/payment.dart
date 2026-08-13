/// When the client pays for the order — mocked, no real payment gateway is
/// wired up. [now] simulates a Mobile Money confirmation at checkout time;
/// [onDelivery] is cash (or Mobile Money) collected by the courier/agency.
enum PaymentMethod {
  now,
  onDelivery;

  String get label => switch (this) {
    PaymentMethod.now => 'Maintenant',
    PaymentMethod.onDelivery => 'À la livraison',
  };
}

enum PaymentStatus {
  paid,
  pendingOnDelivery;

  String get label => switch (this) {
    PaymentStatus.paid => 'Payé',
    PaymentStatus.pendingOnDelivery => 'À payer à la livraison',
  };
}

/// The two Mobile Money operators covering Mali — offered when
/// [PaymentMethod.now] is chosen.
enum MobileMoneyProvider {
  orangeMoney,
  moovMoney;

  String get label => switch (this) {
    MobileMoneyProvider.orangeMoney => 'Orange Money',
    MobileMoneyProvider.moovMoney => 'Moov Money',
  };
}
