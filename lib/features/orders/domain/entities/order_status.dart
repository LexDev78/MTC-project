enum OrderStatus {
  pending,
  confirmed,
  preparing,
  inTransit,
  delivered,
  cancelled;

  String get label => switch (this) {
    OrderStatus.pending => 'En attente',
    OrderStatus.confirmed => 'Confirmée',
    OrderStatus.preparing => 'En préparation',
    OrderStatus.inTransit => 'En livraison',
    OrderStatus.delivered => 'Livrée',
    OrderStatus.cancelled => 'Annulée',
  };
}

/// Who delivers a given supplier's part of the order — the supplier
/// themselves, or MTC on their behalf for a fee.
enum DeliveryMode { selfDelivery, mtcDelivery }
