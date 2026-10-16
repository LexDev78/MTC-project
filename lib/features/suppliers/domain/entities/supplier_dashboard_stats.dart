/// Ce que le fournisseur voit en ouvrant son application.
///
/// Un modèle de **lecture**, assemblé à la main depuis
/// `fetch_supplier_dashboard_stats` (`0092`) — une requête qui compte côté
/// serveur plutôt que de transmettre toutes les commandes pour les
/// additionner sur le téléphone.
///
/// Ne porte ni commission, ni net, ni solde : ces trois-là suivent une règle
/// métier qui vit dans `compute_financial_summary.dart`, et l'écran la lui
/// demande plutôt que de la refaire.
class SupplierDashboardStats {
  const SupplierDashboardStats({
    required this.productsTotal,
    required this.productsActive,
    required this.viewsTotal,
    required this.ordersTotal,
    required this.ordersDelivered,
    required this.ordersInProgress,
    required this.grossFcfa,
    required this.grossLast30DaysFcfa,
    required this.grossLast7DaysFcfa,
    required this.paidOutFcfa,
    required this.bestSellers,
  });

  final int productsTotal;
  final int productsActive;

  /// Cumul des vues de toutes les fiches. C'est la mesure de l'attention
  /// reçue, à distinguer des ventes : beaucoup de vues et peu de commandes
  /// dit quelque chose du prix ou des photos.
  final int viewsTotal;

  final int ordersTotal;
  final int ordersDelivered;

  /// Ni livrées ni annulées : ce qu'il reste à traiter.
  final int ordersInProgress;

  /// Chiffre d'affaires des commandes **livrées**, hors frais de livraison.
  final int grossFcfa;
  final int grossLast30DaysFcfa;
  final int grossLast7DaysFcfa;

  /// Somme des retraits non refusés.
  final int paidOutFcfa;

  final List<BestSeller> bestSellers;

  static const empty = SupplierDashboardStats(
    productsTotal: 0,
    productsActive: 0,
    viewsTotal: 0,
    ordersTotal: 0,
    ordersDelivered: 0,
    ordersInProgress: 0,
    grossFcfa: 0,
    grossLast30DaysFcfa: 0,
    grossLast7DaysFcfa: 0,
    paidOutFcfa: 0,
    bestSellers: [],
  );

  factory SupplierDashboardStats.fromRow(Map<String, dynamic> row) {
    int lire(String cle) => (row[cle] as num?)?.toInt() ?? 0;
    return SupplierDashboardStats(
      productsTotal: lire('products_total'),
      productsActive: lire('products_active'),
      viewsTotal: lire('views_total'),
      ordersTotal: lire('orders_total'),
      ordersDelivered: lire('orders_delivered'),
      ordersInProgress: lire('orders_in_progress'),
      grossFcfa: lire('gross_fcfa'),
      grossLast30DaysFcfa: lire('gross_last_30_days_fcfa'),
      grossLast7DaysFcfa: lire('gross_last_7_days_fcfa'),
      paidOutFcfa: lire('paid_out_fcfa'),
      bestSellers: [
        for (final ligne in (row['best_sellers'] as List? ?? const []))
          BestSeller.fromRow(ligne as Map<String, dynamic>),
      ],
    );
  }
}

/// Un article qui part. La question que se pose un commerçant.
class BestSeller {
  const BestSeller({
    required this.name,
    required this.quantity,
    required this.amountFcfa,
  });

  final String name;
  final int quantity;
  final int amountFcfa;

  factory BestSeller.fromRow(Map<String, dynamic> row) => BestSeller(
    name: row['name'] as String? ?? '',
    quantity: (row['quantity'] as num?)?.toInt() ?? 0,
    amountFcfa: (row['amount_fcfa'] as num?)?.toInt() ?? 0,
  );
}
