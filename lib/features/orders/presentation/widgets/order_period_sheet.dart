import 'package:flutter/material.dart';

import 'package:mtc_app/core/shop/shop.dart';

import '../providers/order_history_filter.dart';

/// Le filtre de l'historique des commandes : la période. Rend le choix, ou
/// `null` si la feuille est fermée sans valider.
Future<OrderPeriod?> showOrderPeriodSheet(
  BuildContext context, {
  required OrderPeriod current,
}) => showShopSheet<OrderPeriod>(
  context,
  heightFactor: 0.55,
  child: OrderPeriodSheet(initial: current),
);

class OrderPeriodSheet extends StatefulWidget {
  const OrderPeriodSheet({super.key, required this.initial});

  final OrderPeriod initial;

  @override
  State<OrderPeriodSheet> createState() => _OrderPeriodSheetState();
}

class _OrderPeriodSheetState extends State<OrderPeriodSheet> {
  late OrderPeriod _choix = widget.initial;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          SheetHeader(
            title: 'Filtrer',
            actionLabel: 'Tout effacer',
            onAction: () => setState(() => _choix = OrderPeriod.all),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: ShopSizes.screenMargin,
              ),
              children: [
                const SizedBox(height: ShopSizes.padding / 2),
                Text('Période', style: Theme.of(context).textTheme.titleSmall),
                for (final periode in OrderPeriod.values)
                  ShopRadioTile<OrderPeriod>(
                    title: periode.label,
                    value: periode,
                    groupValue: _choix,
                    onChanged: (v) => setState(() => _choix = v ?? _choix),
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        label: 'Terminé',
        onPressed: () => Navigator.of(context).pop(_choix),
      ),
    );
  }
}
