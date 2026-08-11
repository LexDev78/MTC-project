import 'package:flutter/material.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';

import '../../domain/entities/delivery_tracking.dart';

class EtaBanner extends StatelessWidget {
  const EtaBanner({super.key, required this.tracking});

  final DeliveryTracking tracking;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final delivered = tracking.status == TrackingStatus.delivered;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      color: scheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                delivered
                    ? Icons.check_circle_rounded
                    : Icons.local_shipping_rounded,
                color: scheme.primary,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                delivered
                    ? 'Livré !'
                    : 'Arrivée estimée : ${tracking.etaMinutes} min',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
            child: LinearProgressIndicator(
              value: tracking.progressRatio,
              minHeight: 6,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}
