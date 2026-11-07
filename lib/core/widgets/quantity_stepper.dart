import 'package:flutter/material.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';

class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.quantity,
    required this.onChanged,
    this.minQuantity = 0,
    this.maxQuantity,
  });

  final int quantity;
  final void Function(int quantity) onChanged;

  /// Decrementing below this value is disabled. Defaults to 0 (no floor),
  /// matching cart behavior where reaching 0 removes the line item.
  final int minQuantity;

  /// Incrementing above this value is disabled. `null` means unconstrained.
  final int? maxQuantity;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    const buttonConstraints = BoxConstraints.tightFor(width: 26, height: 26);

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove_rounded, size: 14),
            iconSize: 14,
            padding: EdgeInsets.zero,
            constraints: buttonConstraints,
            onPressed: quantity > minQuantity
                ? () => onChanged(quantity - 1)
                : null,
          ),
          SizedBox(
            width: 20,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded, size: 14),
            iconSize: 14,
            padding: EdgeInsets.zero,
            constraints: buttonConstraints,
            onPressed: maxQuantity == null || quantity < maxQuantity!
                ? () => onChanged(quantity + 1)
                : null,
          ),
        ],
      ),
    );
  }
}
