import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';

import '../../domain/entities/order_status.dart';
import '../providers/checkout_providers.dart';

/// Only ever shown for [FulfillmentMethod.homeDelivery] — in pickup-point
/// mode there's no "supplier delivers it themselves" choice, since MTC
/// always fetches the parcel and brings it to the point (see
/// `CheckoutScreen`, which doesn't render this widget in that mode).
class DeliveryModeSelector extends ConsumerWidget {
  const DeliveryModeSelector({super.key, required this.group});

  final CheckoutGroupView group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final selected =
        ref.watch(deliveryModeChoiceProvider(group.supplierId)) ??
        (group.allowsSelfDelivery
            ? DeliveryMode.selfDelivery
            : DeliveryMode.mtcDelivery);
    // Still a single choice under the hood — checkboxes are just the
    // requested widget instead of radio buttons. Only togglable when both
    // modes are actually available; with just one, it's shown checked and
    // locked since there's nothing to switch to.
    final bothAvailable = group.allowsSelfDelivery && group.allowsMtcDelivery;

    void select(DeliveryMode mode) {
      ref.read(deliveryModeChoiceProvider(group.supplierId).notifier).state =
          mode;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (group.allowsSelfDelivery) ...[
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: selected == DeliveryMode.selfDelivery,
            onChanged: bothAvailable
                ? (checked) => select(
                    checked == true
                        ? DeliveryMode.selfDelivery
                        : DeliveryMode.mtcDelivery,
                  )
                : null,
            title: const Text('Livraison par le fournisseur'),
            subtitle: const Text('Gratuit'),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(
              'Le fournisseur vous contactera pour la livraison et les frais inclus.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
        if (group.allowsMtcDelivery)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: selected == DeliveryMode.mtcDelivery,
            onChanged: bothAvailable
                ? (checked) => select(
                    checked == true
                        ? DeliveryMode.mtcDelivery
                        : DeliveryMode.selfDelivery,
                  )
                : null,
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
    );
  }
}
