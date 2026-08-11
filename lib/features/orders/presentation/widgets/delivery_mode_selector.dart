import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/core/widgets/core_widgets.dart';

import '../../domain/entities/order_status.dart';
import '../providers/checkout_providers.dart';

class DeliveryModeSelector extends ConsumerWidget {
  const DeliveryModeSelector({super.key, required this.group});

  final CheckoutGroupView group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected =
        ref.watch(deliveryModeChoiceProvider(group.supplierId)) ??
        (group.allowsSelfDelivery
            ? DeliveryMode.selfDelivery
            : DeliveryMode.mtcDelivery);

    return RadioGroup<DeliveryMode>(
      groupValue: selected,
      onChanged: (mode) =>
          ref
                  .read(deliveryModeChoiceProvider(group.supplierId).notifier)
                  .state =
              mode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (group.allowsSelfDelivery)
            const RadioListTile<DeliveryMode>(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: DeliveryMode.selfDelivery,
              title: Text('Livraison par le fournisseur'),
              subtitle: Text('Gratuit'),
            ),
          if (group.allowsMtcDelivery)
            RadioListTile<DeliveryMode>(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: DeliveryMode.mtcDelivery,
              title: const Text('Livraison MTC'),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: CurrencyText(
                  group.mtcDeliveryFeeFcfa,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
