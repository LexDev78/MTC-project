import 'package:flutter/material.dart';

import 'package:mtc_app/core/widgets/core_widgets.dart';

/// "Finances" tab of `SupplierShell` — the financial summary and payout
/// requests land in the finance lot (`supplier_finance/domain` etc. don't
/// exist yet; this stub just reserves the tab).
class SupplierFinanceScreen extends StatelessWidget {
  const SupplierFinanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Finances')),
      body: const MtcComingSoon(
        title: 'Finances — bientôt disponible',
        subtitle: 'Votre solde, vos ventes et vos retraits arriveront ici.',
      ),
    );
  }
}
