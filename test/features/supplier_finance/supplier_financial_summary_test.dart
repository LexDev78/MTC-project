import 'package:flutter_test/flutter_test.dart';

import 'package:mtc_app/features/supplier_finance/domain/entities/supplier_financial_summary.dart';

/// La règle du solde vit en base (`supplier_ledger`, `0131`) et s'y
/// vérifie (`supabase/snippets/verif_0131.sql`). Ici, seulement ce que
/// l'app en fait : lire la réponse sans rien perdre, et dire une dette
/// comme une dette.
void main() {
  test('lit chaque case du grand livre telle que le serveur la rend', () {
    final resume = SupplierFinancialSummary.fromRow({
      'gross_fcfa': 170000,
      'collected_by_mtc_fcfa': 30000,
      'collected_by_supplier_fcfa': 30000,
      'awaiting_payment_fcfa': 110000,
      'commission_rate_percent': 10,
      'commission_on_mtc_fcfa': 3000,
      'commission_owed_fcfa': 3000,
      'commission_fcfa': 6000,
      'net_fcfa': 24000,
      'paid_out_fcfa': 5000,
      'available_fcfa': 19000,
    });

    expect(resume.grossFcfa, 170000);
    expect(resume.collectedByMtcFcfa, 30000);
    expect(resume.collectedBySupplierFcfa, 30000);
    expect(resume.awaitingPaymentFcfa, 110000);
    expect(resume.commissionRatePercent, 10);
    expect(resume.commissionFcfa, 6000);
    expect(resume.commissionOwedFcfa, 3000);
    expect(resume.netFcfa, 24000);
    expect(resume.paidOutFcfa, 5000);
    expect(resume.availableFcfa, 19000);
    expect(resume.owedToMtcFcfa, 0);
  });

  test('un solde négatif est une commission due à MTC, pas un disponible', () {
    // Une boutique qui n'a vendu qu'en livrant elle-même, payée en
    // espèces : l'argent est chez elle, elle doit 10 % à MTC.
    final resume = SupplierFinancialSummary.fromRow({
      'gross_fcfa': 100000,
      'collected_by_supplier_fcfa': 100000,
      'commission_rate_percent': 10,
      'commission_owed_fcfa': 10000,
      'commission_fcfa': 10000,
      'net_fcfa': -10000,
      'available_fcfa': -10000,
    });

    expect(resume.availableFcfa, -10000);
    expect(resume.owedToMtcFcfa, 10000);
  });

  test("une clé absente vaut zéro : un grand livre vide n'est pas une "
      'erreur', () {
    final resume = SupplierFinancialSummary.fromRow(const {});

    expect(resume.grossFcfa, 0);
    expect(resume.availableFcfa, 0);
    expect(resume.commissionRatePercent, 0);
    expect(resume.owedToMtcFcfa, 0);
  });

  test('accepte les nombres que PostgREST rend en flottant', () {
    // `round(...)` en SQL rend un `numeric`, que le JSON peut porter avec
    // une décimale.
    final resume = SupplierFinancialSummary.fromRow({
      'commission_fcfa': 2500.0,
      'commission_rate_percent': 7.5,
      'available_fcfa': 12500.0,
    });

    expect(resume.commissionFcfa, 2500);
    expect(resume.commissionRatePercent, 7.5);
    expect(resume.availableFcfa, 12500);
  });
}
