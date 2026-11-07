/// Le grand livre d'une boutique, tel que le serveur le tient
/// (`supplier_ledger`, `0131`). Jamais recalculé dans l'app.
///
/// La règle tient en une phrase : une boutique ne retire que l'argent que
/// MTC a réellement reçu. Chaque vente livrée se range selon qui l'a
/// encaissée — MTC (paiement en ligne confirmé, ou livreur MTC payé à la
/// porte), la boutique elle-même (elle a livré et encaissé), ou personne
/// encore (paiement en ligne que MTC n'a pas confirmé).
///
/// Elle vivait en Dart (`compute_financial_summary.dart`) en même temps que
/// dans la garde des retraits, en SQL. Deux copies d'une règle qui dit au
/// fournisseur combien il peut retirer : la première comptait toute vente
/// « livrée », y compris celles que la boutique avait encaissées elle-même,
/// et c'est par là qu'une fausse commande ouvrait un versement.
class SupplierFinancialSummary {
  const SupplierFinancialSummary({
    required this.grossFcfa,
    required this.collectedByMtcFcfa,
    required this.collectedBySupplierFcfa,
    required this.awaitingPaymentFcfa,
    required this.commissionRatePercent,
    required this.commissionFcfa,
    required this.commissionOwedFcfa,
    required this.netFcfa,
    required this.paidOutFcfa,
    required this.availableFcfa,
  });

  /// Lit la réponse de `fetch_my_finance_summary` (ou le champ `finance` de
  /// `fetch_supplier_dashboard_stats`). Une clé absente vaut zéro : un
  /// grand livre vide n'est pas une erreur.
  factory SupplierFinancialSummary.fromRow(Map<String, dynamic> row) {
    int lire(String cle) => (row[cle] as num?)?.toInt() ?? 0;
    return SupplierFinancialSummary(
      grossFcfa: lire('gross_fcfa'),
      collectedByMtcFcfa: lire('collected_by_mtc_fcfa'),
      collectedBySupplierFcfa: lire('collected_by_supplier_fcfa'),
      awaitingPaymentFcfa: lire('awaiting_payment_fcfa'),
      commissionRatePercent:
          (row['commission_rate_percent'] as num?)?.toDouble() ?? 0,
      commissionFcfa: lire('commission_fcfa'),
      commissionOwedFcfa: lire('commission_owed_fcfa'),
      netFcfa: lire('net_fcfa'),
      paidOutFcfa: lire('paid_out_fcfa'),
      availableFcfa: lire('available_fcfa'),
    );
  }

  /// Toutes les ventes livrées, hors frais de livraison, quel que soit celui
  /// qui a encaissé. Le chiffre d'affaires, pas le solde.
  final int grossFcfa;

  /// Ventes dont MTC tient l'argent : c'est le seul argent qui se retire.
  final int collectedByMtcFcfa;

  /// Ventes livrées et encaissées par la boutique elle-même. L'argent est
  /// déjà chez elle ; seule sa commission compte ici, à son débit.
  final int collectedBySupplierFcfa;

  /// Ventes payées en ligne dont MTC n'a pas encore confirmé la réception.
  /// Elles ne comptent ni pour ni contre tant qu'elles le restent.
  final int awaitingPaymentFcfa;

  /// 0 pour la boutique MTC : elle ne se prend pas de commission.
  final double commissionRatePercent;

  /// Commission de MTC sur toutes les ventes encaissées, par MTC comme par
  /// la boutique.
  final int commissionFcfa;

  /// La part de [commissionFcfa] due sur ce que la boutique a encaissé
  /// elle-même.
  final int commissionOwedFcfa;

  /// Ce que MTC doit à la boutique avant les retraits : ce qu'il a encaissé
  /// pour elle, moins toute la commission.
  final int netFcfa;

  /// Retraits non refusés — demandés, en cours ou payés : tous réservent
  /// leur montant.
  final int paidOutFcfa;

  /// [netFcfa] moins [paidOutFcfa]. Négatif quand la boutique doit sa
  /// commission à MTC : aucun retrait n'est alors possible.
  final int availableFcfa;

  /// La commission que la boutique doit encore à MTC, une fois déduit tout
  /// ce que MTC lui doit.
  int get owedToMtcFcfa => availableFcfa < 0 ? -availableFcfa : 0;
}
