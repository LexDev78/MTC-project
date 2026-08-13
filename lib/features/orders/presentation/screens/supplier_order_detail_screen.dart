import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/utils/date_formatter.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';
import 'package:mtc_app/features/suppliers/presentation/providers/operating_supplier_providers.dart';

import '../../domain/entities/order_status.dart';
import '../../domain/order_status_transitions.dart';
import '../controllers/supplier_order_controller.dart';
import '../providers/supplier_order_providers.dart';

/// One order, scoped to the operating supplier's own group — reached from
/// `SupplierOrderListScreen`. Never renders another supplier's items/prices
/// from the same order (see `SupplierOrderView`).
class SupplierOrderDetailScreen extends ConsumerWidget {
  const SupplierOrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supplierId = ref.watch(operatingSupplierIdProvider);
    if (supplierId == null) {
      return const Scaffold(body: MtcLoadingView());
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Détail de la commande')),
      body: AsyncValueWidget(
        value: ref.watch(
          supplierOrderDetailProvider((orderId: orderId, supplierId: supplierId)),
        ),
        data: (view) => _OrderDetailBody(view: view),
      ),
    );
  }
}

class _OrderDetailBody extends ConsumerWidget {
  const _OrderDetailBody({required this.view});

  final SupplierOrderView view;

  Future<void> _changeStatus(
    BuildContext context,
    WidgetRef ref,
    OrderStatus status,
  ) async {
    final success = await ref
        .read(supplierOrderControllerProvider.notifier)
        .updateStatus(orderId: view.orderId, groupId: view.myGroup.id, status: status);
    if (!success && context.mounted) {
      final error = ref.read(supplierOrderControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error?.toString() ?? 'Une erreur est survenue')),
      );
    }
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Refuser cette commande ?'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Expliquez pourquoi vous refusez cette commande…',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Refuser la commande'),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty || !context.mounted) return;

    final success = await ref
        .read(supplierOrderControllerProvider.notifier)
        .cancel(orderId: view.orderId, groupId: view.myGroup.id, reason: reason);
    if (!success && context.mounted) {
      final error = ref.read(supplierOrderControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error?.toString() ?? 'Une erreur est survenue')),
      );
    }
  }

  Future<void> _contactClient(BuildContext context, WidgetRef ref) async {
    final conversationId = await ref
        .read(supplierOrderControllerProvider.notifier)
        .contactClient(clientId: view.clientId);
    if (!context.mounted) return;
    if (conversationId == null) {
      final error = ref.read(supplierOrderControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error?.toString() ?? 'Une erreur est survenue')),
      );
      return;
    }
    unawaited(
      context.push(
        '${ref.read(supplierRoutePrefixProvider)}/messages/$conversationId',
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final group = view.myGroup;
    final state = ref.watch(supplierOrderControllerProvider);

    final nextStatuses = OrderStatus.values.where(
      (s) => s != OrderStatus.cancelled && isValidTransition(group.status, s),
    );
    final canCancel = isValidTransition(group.status, OrderStatus.cancelled);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                group.status.label,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            RoleBadge(label: group.status.label, color: scheme.primary),
          ],
        ),
        if (group.status == OrderStatus.cancelled &&
            group.cancellationReason != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: scheme.errorContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Text(
              'Refusée par ${group.cancelledBy?.label ?? 'le fournisseur'} : '
              '${group.cancellationReason}',
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Text(
          DateFormatter.formatDateTime(view.placedAt),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.lg),
        Card(
          child: ListTile(
            leading: const Icon(Icons.person_outline_rounded),
            title: Text(view.clientDisplayNameSnapshot),
            subtitle: Text(view.clientPhoneSnapshot),
            trailing: IconButton(
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              tooltip: 'Contacter le client',
              onPressed: state.isLoading
                  ? null
                  : () => _contactClient(context, ref),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: ListTile(
            leading: const Icon(Icons.location_on_outlined),
            title: Text(view.deliveryAddressLabel),
            subtitle: Text('${view.deliveryDetails}, ${view.deliveryCity}'),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Articles', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final item in group.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${item.quantity} × ${item.productNameSnapshot}',
                          ),
                        ),
                        CurrencyText(item.unitPriceFcfaSnapshot * item.quantity),
                      ],
                    ),
                  ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Livraison'),
                    CurrencyText(group.deliveryFeeFcfa),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Sous-total', style: Theme.of(context).textTheme.titleSmall),
                    CurrencyText(
                      group.subtotalFcfa,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (nextStatuses.isNotEmpty || canCancel) ...[
          const SizedBox(height: AppSpacing.xl),
          for (final status in nextStatuses)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: MtcPrimaryButton(
                label: 'Marquer ${status.label.toLowerCase()}',
                isLoading: state.isLoading,
                onPressed: () => _changeStatus(context, ref, status),
              ),
            ),
          if (canCancel)
            OutlinedButton(
              onPressed: state.isLoading ? null : () => _cancel(context, ref),
              child: const Text('Refuser la commande'),
            ),
        ],
      ],
    );
  }
}
