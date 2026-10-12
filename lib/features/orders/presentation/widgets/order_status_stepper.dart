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

/// Glyphs already used for the same concept elsewhere in this app
/// (`eta_banner.dart`'s delivered/in-transit icons, `order_detail_screen.dart`'s
/// "Suivre la livraison"/paid-status icons, `order_item_row.dart`'s package
/// icon) — kept local to this widget since it's the only place that needs a
/// full one-icon-per-status mapping.
extension _OrderStatusIcon on OrderStatus {
  IconData get icon => switch (this) {
    OrderStatus.pending => Icons.schedule_rounded,
    OrderStatus.confirmed => Icons.check_circle_outline_rounded,
    OrderStatus.preparing => Icons.inventory_2_outlined,
    OrderStatus.inTransit => Icons.local_shipping_rounded,
    OrderStatus.delivered => Icons.check_circle_rounded,
    OrderStatus.cancelled => Icons.cancel_rounded,
  };
}

/// The order's progress through [_steps] — an icon per stage rather than a
/// word, so it reads at a glance instead of needing translation/reading time;
/// the step's actual name is still available as text via the status badge
/// shown elsewhere on the same screen (`group.status.label`).
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (var i = 0; i < _steps.length; i++) ...[
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StepIcon(
                  icon: _steps[i].icon,
                  reached: i <= currentIndex,
                  current: i == currentIndex,
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

class _StepIcon extends StatelessWidget {
  const _StepIcon({
    required this.icon,
    required this.reached,
    required this.current,
  });

  final IconData icon;
  final bool reached;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = current ? 34.0 : 28.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: reached ? scheme.primary : scheme.surfaceContainerHighest,
        border: current ? Border.all(color: scheme.primary, width: 2) : null,
      ),
      child: Icon(
        icon,
        size: current ? 20 : 16,
        color: reached ? scheme.onPrimary : scheme.onSurfaceVariant,
      ),
    );
  }
}
