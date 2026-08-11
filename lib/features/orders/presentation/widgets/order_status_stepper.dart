import 'package:flutter/material.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';

import '../../domain/entities/order_status.dart';

const _steps = [
  OrderStatus.pending,
  OrderStatus.confirmed,
  OrderStatus.preparing,
  OrderStatus.inTransit,
  OrderStatus.delivered,
];

class OrderStatusStepper extends StatelessWidget {
  const OrderStatusStepper({super.key, required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (status == OrderStatus.cancelled) {
      return Row(
        children: [
          Icon(Icons.cancel_rounded, color: scheme.error, size: 18),
          const SizedBox(width: AppSpacing.xs),
          Text('Commande annulée', style: TextStyle(color: scheme.error)),
        ],
      );
    }

    final currentIndex = _steps.indexOf(status);

    return Row(
      children: [
        for (var i = 0; i < _steps.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i <= currentIndex
                        ? scheme.primary
                        : scheme.surfaceContainerHighest,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _steps[i].label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: i == currentIndex
                        ? FontWeight.w700
                        : FontWeight.w400,
                    color: i <= currentIndex
                        ? scheme.onSurface
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (i < _steps.length - 1)
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                height: 2,
                margin: const EdgeInsets.only(bottom: 16),
                color: i < currentIndex
                    ? scheme.primary
                    : scheme.surfaceContainerHighest,
              ),
            ),
        ],
      ],
    );
  }
}
