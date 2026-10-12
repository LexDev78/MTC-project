import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/features/delivery/domain/entities/courier_delivery.dart';
import 'package:mtc_app/features/delivery/presentation/providers/delivery_providers.dart';
import 'package:mtc_app/features/delivery/presentation/providers/courier_history_providers.dart';
import 'package:mtc_app/features/delivery/presentation/widgets/courier_rating_sheet.dart';
import 'package:mtc_app/features/delivery/presentation/widgets/delivery_code_qr.dart';
import 'package:mtc_app/core/utils/date_formatter.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';
import 'package:mtc_app/core/widgets/voice_note_player.dart';

import '../../domain/entities/fulfillment.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/order_status.dart';
import '../../domain/entities/payment.dart';
import '../../domain/order_status_transitions.dart';
import '../controllers/order_controller.dart';
import '../providers/order_providers.dart';
import '../widgets/order_item_row.dart';
import '../widgets/order_status_stepper.dart';

class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderDetailProvider(orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Détail de la commande')),
      body: AsyncValueWidget(
        value: orderAsync,
        data: (order) => _OrderDetailBody(order: order),
      ),
    );
  }
}

class _OrderDetailBody extends ConsumerWidget {
  const _OrderDetailBody({required this.order});

  final Order order;

  Future<void> _cancel(
    BuildContext context,
    WidgetRef ref,
    OrderSupplierGroup group,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler cette commande ?'),
        content: Text(
          'Votre commande auprès de ${group.supplierName} sera annulée. '
          'Cette action est définitive.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Retour'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Annuler la commande'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final success = await ref
        .read(orderControllerProvider.notifier)
        .cancel(orderId: order.id, groupId: group.id);
    if (!success && context.mounted) {
      final error = ref.read(orderControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error?.toString() ?? 'Une erreur est survenue')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final controllerState = ref.watch(orderControllerProvider);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        OrderStatusStepper(status: order.status),
        const SizedBox(height: AppSpacing.lg),
        Text(
          DateFormatter.formatDateTime(order.placedAt),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: ListTile(
            leading: Icon(
              order.fulfillmentMethod == FulfillmentMethod.pickupPoint
                  ? Icons.storefront_outlined
                  : Icons.location_on_outlined,
            ),
            title: Text(order.deliveryAddressLabel),
            subtitle: Text('${order.deliveryDetails}, ${order.deliveryCity}'),
          ),
        ),
        if (order.fulfillmentMethod == FulfillmentMethod.homeDelivery) ...[
          const SizedBox(height: AppSpacing.md),
          _HomeDeliveryDetailsCard(order: order),
        ],
        const SizedBox(height: AppSpacing.md),
        _PaymentCard(order: order),
        const SizedBox(height: AppSpacing.lg),
        for (final group in order.supplierGroups) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          group.supplierName,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      RoleBadge(
                        label: group.status.label,
                        color: scheme.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  for (final item in group.items)
                    OrderItemRow(
                      productId: item.productId,
                      productNameSnapshot: item.productNameSnapshot,
                      unitPriceFcfaSnapshot: item.unitPriceFcfaSnapshot,
                      quantity: item.quantity,
                      variantId: item.variantId,
                      variantNameSnapshot: item.variantNameSnapshot,
                    ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Livraison'),
                      CurrencyText(group.deliveryFeeFcfa),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (group.status == OrderStatus.inTransit)
                    OutlinedButton.icon(
                      onPressed: () =>
                          context.push(AppRoutes.orderTrack(order.id)),
                      icon: const Icon(Icons.local_shipping_outlined),
                      label: const Text('Suivre la livraison'),
                    ),
                  if (group.deliveryMode == DeliveryMode.mtcDelivery)
                    _DeliveryCode(groupId: group.id),
                  if (group.status == OrderStatus.delivered)
                    OutlinedButton.icon(
                      onPressed: () =>
                          context.push(AppRoutes.orderReview(order.id)),
                      icon: const Icon(Icons.star_outline_rounded),
                      label: const Text('Laisser un avis'),
                    ),
                  if (group.status == OrderStatus.delivered &&
                      group.deliveryMode == DeliveryMode.mtcDelivery)
                    _RateCourierButton(groupId: group.id),
                  if (canClientCancel(group.status))
                    OutlinedButton.icon(
                      onPressed: controllerState.isLoading
                          ? null
                          : () => _cancel(context, ref, group),
                      icon: Icon(Icons.cancel_outlined, color: scheme.error),
                      label: Text(
                        'Annuler la commande',
                        style: TextStyle(color: scheme.error),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                if (order.isPriority)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Commande prioritaire'),
                        CurrencyText(order.priorityFeeFcfa),
                      ],
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    CurrencyText(
                      order.totalFcfa,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Phone/comment-for-the-courier/date-slot summary — only rendered for
/// [FulfillmentMethod.homeDelivery] orders, since pickup-point orders don't
/// carry any of these.
class _HomeDeliveryDetailsCard extends StatelessWidget {
  const _HomeDeliveryDetailsCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rows = <Widget>[
      if (order.courierPhone != null && order.courierPhone!.isNotEmpty)
        _InfoRow(icon: Icons.phone_outlined, text: order.courierPhone!),
      if (order.alternatePhone != null && order.alternatePhone!.isNotEmpty)
        _InfoRow(icon: Icons.phone_outlined, text: order.alternatePhone!),
      if (order.deliveryDate != null && order.deliveryTimeSlotLabel != null)
        _InfoRow(
          icon: Icons.event_outlined,
          text:
              '${DateFormatter.formatDayMonth(order.deliveryDate!)} · ${order.deliveryTimeSlotLabel}',
        ),
      if (order.supplierMessageType == SupplierMessageType.text &&
          order.supplierMessageText != null &&
          order.supplierMessageText!.isNotEmpty)
        _InfoRow(
          icon: Icons.chat_bubble_outline_rounded,
          text: order.supplierMessageText!,
        ),
      if (order.supplierMessageType == SupplierMessageType.voice &&
          order.supplierMessageVoicePath != null)
        Row(
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 16,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.xs),
            VoiceNotePlayer(
              path: order.supplierMessageVoicePath!,
              durationSeconds: order.supplierMessageVoiceDurationSeconds,
              compact: true,
              bucket: 'order-messages',
              signed: true,
            ),
          ],
        ),
    ];

    if (rows.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: DefaultTextStyle(
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall!.copyWith(color: scheme.onSurfaceVariant),
                  child: row,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Payment method + status — shown for every order, since it's set
/// regardless of fulfillment method.
class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final paid = order.paymentStatus == PaymentStatus.paid;

    return Card(
      child: ListTile(
        leading: Icon(
          paid ? Icons.check_circle_outline_rounded : Icons.payments_outlined,
          color: paid ? scheme.primary : scheme.onSurfaceVariant,
        ),
        title: Text(
          order.mobileMoneyProvider != null
              ? 'Payé via ${order.mobileMoneyProvider!.label}'
              : order.paymentMethod.label,
        ),
        subtitle: Text(order.paymentStatus.label),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.xs),
        Expanded(child: Text(text)),
      ],
    );
  }
}

/// QR de remise, présenté au livreur à l'arrivée.
///
/// N'apparaît qu'une fois le colis retiré chez le fournisseur : avant, le
/// livreur n'est pas en route et l'afficher plus tôt inviterait à le montrer
/// — ou à le transmettre — hors de la remise elle-même, ce qui est
/// exactement ce que ce code empêche.
class _DeliveryCode extends ConsumerWidget {
  const _DeliveryCode({required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final delivery = ref.watch(deliveryForGroupProvider(groupId)).valueOrNull;
    if (delivery == null || delivery.status != DeliveryStatus.pickedUp) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: DeliveryCodeQr(
        deliveryId: delivery.id,
        kind: DeliveryCodeKind.delivery,
        title: 'Code de remise',
        instruction:
            'À montrer au livreur au moment de recevoir votre commande. '
            'Ne le communiquez à personne d\'autre.',
      ),
    );
  }
}

/// Noter le livreur, une fois la commande remise.
///
/// Distinct de « Laisser un avis », qui juge le **fournisseur** : la
/// marchandise et son acheminement sont deux prestations différentes, et une
/// seule note pour les deux pénaliserait un bon vendeur pour un livreur en
/// retard — ou l'inverse.
///
/// N'apparaît que pour une livraison MTC : sur une livraison assurée par le
/// fournisseur lui-même, il n'y a aucun livreur à noter.
class _RateCourierButton extends ConsumerWidget {
  const _RateCourierButton({required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final delivery = ref.watch(deliveryForGroupProvider(groupId)).valueOrNull;
    // Un groupe livré sans course : commande confiée à MTC et close
    // autrement. Rien à noter.
    if (delivery == null || delivery.status != DeliveryStatus.delivered) {
      return const SizedBox.shrink();
    }
    final existing = ref.watch(myDeliveryRatingProvider(delivery.id)).valueOrNull;

    return OutlinedButton.icon(
      onPressed: () =>
          showCourierRatingSheet(context, deliveryId: delivery.id),
      icon: Icon(
        existing == null
            ? Icons.delivery_dining_outlined
            : Icons.star_rounded,
        color: existing == null ? null : Colors.amber,
      ),
      // Rappeler la note déjà donnée évite de la redonner en croyant que la
      // première n'est pas passée.
      label: Text(
        existing == null
            ? 'Noter le livreur'
            : 'Livreur noté ${existing.stars}/5 — modifier',
      ),
    );
  }
}
