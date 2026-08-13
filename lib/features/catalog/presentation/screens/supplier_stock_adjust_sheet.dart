import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/utils/date_formatter.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';

import '../../domain/entities/product.dart';
import '../../domain/entities/stock_movement.dart';
import '../controllers/supplier_product_controller.dart';
import '../providers/supplier_product_providers.dart';

/// Quick stock correction reachable directly from a row in
/// `SupplierProductListScreen`, for a fast in/out adjustment without
/// opening the full edit form — e.g. right after a delivery arrives or a
/// spot-check finds a discrepancy. Every change still goes through
/// `ProductRepository.adjustStock`, so it shows up in the same movement
/// history the product form's own stock edits do.
class SupplierStockAdjustSheet extends ConsumerStatefulWidget {
  const SupplierStockAdjustSheet({super.key, required this.product});

  final Product product;

  @override
  ConsumerState<SupplierStockAdjustSheet> createState() =>
      _SupplierStockAdjustSheetState();
}

class _SupplierStockAdjustSheetState
    extends ConsumerState<SupplierStockAdjustSheet> {
  final _quantityController = TextEditingController(text: '1');
  final _noteController = TextEditingController();
  bool _isAddition = true;
  StockMovementReason _reason = StockMovementReason.restock;

  static const _availableReasons = [
    StockMovementReason.restock,
    StockMovementReason.returned,
    StockMovementReason.manualAdjustment,
    StockMovementReason.correction,
  ];

  @override
  void dispose() {
    _quantityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final quantity = int.tryParse(_quantityController.text.trim());
    if (quantity == null || quantity <= 0) return;

    final delta = _isAddition ? quantity : -quantity;
    final note = _noteController.text.trim();
    final success = await ref
        .read(supplierProductControllerProvider.notifier)
        .adjustStock(
          productId: widget.product.id,
          quantityDelta: delta,
          reason: _reason,
          note: note.isEmpty ? null : note,
        );

    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop();
    } else {
      final error = ref.read(supplierProductControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error?.toString() ?? 'Une erreur est survenue')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(supplierProductControllerProvider);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.product.name, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${widget.product.stockQuantity} en stock actuellement',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Ajouter')),
                  ButtonSegment(value: false, label: Text('Retirer')),
                ],
                selected: {_isAddition},
                onSelectionChanged: (selection) =>
                    setState(() => _isAddition = selection.first),
              ),
              const SizedBox(height: AppSpacing.md),
              MtcTextField(
                label: 'Quantité',
                controller: _quantityController,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<StockMovementReason>(
                initialValue: _reason,
                decoration: const InputDecoration(labelText: 'Motif'),
                items: [
                  for (final reason in _availableReasons)
                    DropdownMenuItem(value: reason, child: Text(reason.label)),
                ],
                onChanged: (value) => setState(() => _reason = value ?? _reason),
              ),
              const SizedBox(height: AppSpacing.md),
              MtcTextField(
                label: 'Note (optionnel)',
                controller: _noteController,
              ),
              const SizedBox(height: AppSpacing.lg),
              MtcPrimaryButton(
                label: 'Confirmer',
                isLoading: state.isLoading,
                onPressed: _submit,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Historique récent', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              _RecentMovements(productId: widget.product.id),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentMovements extends ConsumerWidget {
  const _RecentMovements({required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movements = ref
        .watch(productStockMovementsProvider(productId))
        .valueOrNull;

    if (movements == null || movements.isEmpty) {
      return Text(
        'Aucun mouvement enregistré.',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (final movement in movements.take(5))
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              children: [
                Icon(
                  movement.quantityDelta >= 0
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: 16,
                  color: movement.quantityDelta >= 0 ? scheme.primary : scheme.error,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    '${movement.quantityDelta > 0 ? '+' : ''}${movement.quantityDelta} · ${movement.reason.label}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Text(
                  DateFormatter.relative(movement.occurredAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
