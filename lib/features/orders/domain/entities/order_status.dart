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

/// Who cancelled a supplier group — only ever [supplier] today (the client
/// has no cancellation flow yet, and MTC-initiated cancellation isn't
/// modeled), kept as a full enum rather than a bare flag so both are easy
/// to add later without another migration.
enum CancelledBy {
  client,
  supplier,
  mtc;

  String get label => switch (this) {
    CancelledBy.client => 'le client',
    CancelledBy.supplier => 'le fournisseur',
    CancelledBy.mtc => 'MTC',
  };
}
