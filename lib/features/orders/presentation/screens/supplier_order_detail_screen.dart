import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/features/delivery/domain/entities/courier_delivery.dart';
import 'package:mtc_app/features/delivery/presentation/providers/delivery_providers.dart';
import 'package:mtc_app/features/delivery/presentation/widgets/delivery_code_qr.dart';
import 'package:mtc_app/core/utils/date_formatter.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';
import 'package:mtc_app/features/chat/presentation/screens/chat_thread_screen.dart'
    show ChatProductAttachment;
import 'package:mtc_app/features/suppliers/presentation/providers/operating_supplier_providers.dart';

import '../../domain/entities/order.dart';
import '../../domain/entities/order_status.dart';
import '../../domain/order_status_transitions.dart';
import '../controllers/supplier_order_controller.dart';
import '../providers/supplier_order_providers.dart';
import '../widgets/order_item_row.dart';

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
        .updateStatus(
          orderId: view.orderId,
          groupId: view.myGroup.id,
          status: status,
          clientId: view.clientId,
          supplierName: view.myGroup.supplierName,
        );
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
        .cancel(
          orderId: view.orderId,
          groupId: view.myGroup.id,
          reason: reason,
          clientId: view.clientId,
          supplierName: view.myGroup.supplierName,
        );
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
        .contactClient(
          clientId: view.clientId,
          clientDisplayNameSnapshot: view.clientDisplayNameSnapshot,
        );
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

  Future<void> _contactClientAboutItem(
    BuildContext context,
    WidgetRef ref,
    OrderItem item,
  ) async {
    final result = await ref
        .read(supplierOrderControllerProvider.notifier)
        .contactClientAboutItem(
          clientId: view.clientId,
          clientDisplayNameSnapshot: view.clientDisplayNameSnapshot,
          item: item,
        );
    if (!context.mounted) return;
    if (result.conversationId == null) {
      final error = ref.read(supplierOrderControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error?.toString() ?? 'Une erreur est survenue')),
      );
      return;
    }
    final product = result.product;
    unawaited(
      context.push(
        '${ref.read(supplierRoutePrefixProvider)}/messages/${result.conversationId}',
        // `product` is best-effort (see `contactClientAboutItem`'s doc
        // comment) — `null` still opens the conversation, just without an
        // attachment, rather than blocking navigation on it.
        extra: product == null
            ? null
            : ChatProductAttachment(product: product, variant: result.variant),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final group = view.myGroup;
    final state = ref.watch(supplierOrderControllerProvider);

    // Une livraison MTC se clôt par le scan du client, pas par un bouton :
    // le fournisseur ne constate pas l'arrivée du colis, et la preuve existe
    // ailleurs (`0054_mtc_delivery_closed_by_scan.sql`, qui refuse aussi
    // l'appel direct). Il garde la remise au livreur — « En livraison » —
    // qui est bien son geste à lui.
    final closedByCourier = group.deliveryMode == DeliveryMode.mtcDelivery;
    final nextStatuses = OrderStatus.values.where(
      (s) =>
          s != OrderStatus.cancelled &&
          isValidTransition(group.status, s) &&
          !(closedByCourier && s == OrderStatus.delivered),
    );
    final canCancel = isValidTransition(group.status, OrderStatus.cancelled);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (closedByCourier && group.status == OrderStatus.inTransit)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Row(
              children: [
                Icon(Icons.qr_code_rounded, color: scheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Un livreur MTC s\'en charge. La commande passera en '
                    '« Livrée » quand le client aura scanné son code de remise.',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
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
                  OrderItemRow(
                    productId: item.productId,
                    productNameSnapshot: item.productNameSnapshot,
                    unitPriceFcfaSnapshot: item.unitPriceFcfaSnapshot,
                    quantity: item.quantity,
                    variantId: item.variantId,
                    variantNameSnapshot: item.variantNameSnapshot,
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 20,
                      ),
                      tooltip: 'Contacter à propos de cet article',
                      visualDensity: VisualDensity.compact,
                      onPressed: state.isLoading
                          ? null
                          : () => _contactClientAboutItem(context, ref, item),
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
                if (group.deliveryMode == DeliveryMode.mtcDelivery) ...[
                  const SizedBox(height: AppSpacing.md),
                  _PickupCode(groupId: group.id),
                ],
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

/// QR de retrait, présenté au livreur qui vient chercher le colis.
///
/// N'apparaît qu'une fois la commande confiée à MTC — avant, il n'y a pas de
/// course, donc pas de code. Disparaît une fois scanné : un QR qui reste
/// affiché après coup laisse croire qu'il reste quelque chose à faire.
class _PickupCode extends ConsumerWidget {
  const _PickupCode({required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final delivery = ref.watch(deliveryForGroupProvider(groupId)).valueOrNull;
    if (delivery == null) return const SizedBox.shrink();
    if (delivery.status == DeliveryStatus.pickedUp ||
        delivery.status == DeliveryStatus.delivered) {
      return const SizedBox.shrink();
    }

    return DeliveryCodeQr(
      deliveryId: delivery.id,
      kind: DeliveryCodeKind.pickup,
      title: 'Code de retrait',
      instruction:
          'À montrer au livreur quand il vient chercher la commande. '
          'Il ne peut pas la récupérer sans ce scan.',
    );
  }
}
