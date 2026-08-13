import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';

import '../../domain/entities/fulfillment.dart';
import '../providers/checkout_providers.dart';

/// Lets the client pick which mocked MTC agency they'll collect the order
/// from — same "list of options, radio-select one" shape as
/// [DeliveryModeSelector], scoped to the whole order instead of one
/// supplier group.
class PickupPointPicker extends ConsumerWidget {
  const PickupPointPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final points = ref.watch(pickupPointsProvider);
    final selected = ref.watch(selectedPickupPointProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: RadioGroup<PickupPoint>(
          groupValue: selected,
          onChanged: (point) =>
              ref.read(selectedPickupPointProvider.notifier).state = point,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choisissez un point de retrait',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              for (final point in points)
                RadioListTile<PickupPoint>(
                  contentPadding: EdgeInsets.zero,
                  value: point,
                  title: Text(point.name),
                  subtitle: Text('${point.address}, ${point.city}'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
