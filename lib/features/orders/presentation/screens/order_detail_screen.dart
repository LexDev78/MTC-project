import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/utils/date_formatter.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';

import '../../domain/entities/order.dart';
import '../../domain/entities/order_status.dart';
import '../providers/order_providers.dart';
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

class _OrderDetailBody extends StatelessWidget {
  const _OrderDetailBody({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

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
            leading: const Icon(Icons.location_on_outlined),
            title: Text(order.deliveryAddressLabel),
            subtitle: Text('${order.deliveryDetails}, ${order.deliveryCity}'),
          ),
        ),
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
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${item.quantity} × ${item.productNameSnapshot}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          CurrencyText(
                            item.unitPriceFcfaSnapshot * item.quantity,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
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
                  const SizedBox(height: AppSpacing.md),
                  if (group.status == OrderStatus.inTransit)
                    OutlinedButton.icon(
                      onPressed: () =>
                          context.push(AppRoutes.orderTrack(order.id)),
                      icon: const Icon(Icons.local_shipping_outlined),
                      label: const Text('Suivre la livraison'),
                    ),
                  if (group.status == OrderStatus.delivered)
                    OutlinedButton.icon(
                      onPressed: () =>
                          context.push(AppRoutes.orderReview(order.id)),
                      icon: const Icon(Icons.star_outline_rounded),
                      label: const Text('Laisser un avis'),
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total', style: Theme.of(context).textTheme.titleMedium),
                CurrencyText(
                  order.totalFcfa,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
