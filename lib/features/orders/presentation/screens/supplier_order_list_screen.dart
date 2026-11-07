import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/utils/date_formatter.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';
import 'package:mtc_app/features/suppliers/presentation/providers/operating_supplier_providers.dart';

import '../../domain/entities/order_status.dart';
import '../providers/supplier_order_providers.dart';

/// "Commandes" tab of `SupplierShell` — shared by both supplier roles via
/// `operatingSupplierIdProvider`. Every tile only ever shows *this*
/// supplier's own group of a given order — see `SupplierOrderView`.
class SupplierOrderListScreen extends ConsumerWidget {
  const SupplierOrderListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supplierId = ref.watch(operatingSupplierIdProvider);
    if (supplierId == null) {
      return const Scaffold(body: MtcLoadingView());
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Commandes')),
      body: Column(
        children: [
          _StatusFilterRow(supplierId: supplierId),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: AsyncValueWidget(
              value: ref.watch(supplierOrdersProvider(supplierId)),
              data: (orders) {
                final filter = ref.watch(
                  myOrdersStatusFilterProvider(supplierId),
                );
                final filtered = filter == null
                    ? orders
                    : orders.where((o) => o.myGroup.status == filter).toList();

                if (filtered.isEmpty) {
                  return const MtcEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'Aucune commande',
                    subtitle: 'Vos commandes clients apparaîtront ici.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) =>
                      _SupplierOrderTile(view: filtered[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusFilterRow extends ConsumerWidget {
  const _StatusFilterRow({required this.supplierId});

  final String supplierId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(myOrdersStatusFilterProvider(supplierId));

    Widget chip(String label, OrderStatus? status) {
      return Padding(
        padding: const EdgeInsets.only(right: AppSpacing.xs),
        child: ChoiceChip(
          label: Text(label),
          selected: selected == status,
          onSelected: (_) => ref
              .read(myOrdersStatusFilterProvider(supplierId).notifier)
              .state = status,
        ),
      );
    }

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        children: [
          chip('Toutes', null),
          for (final status in OrderStatus.values) chip(status.label, status),
        ],
      ),
    );
  }
}

class _SupplierOrderTile extends ConsumerWidget {
  const _SupplierOrderTile({required this.view});

  final SupplierOrderView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final itemCount = view.myGroup.items.fold<int>(
      0,
      (sum, i) => sum + i.quantity,
    );

    return Card(
      child: InkWell(
        onTap: () => context.push(
          '${ref.read(supplierRoutePrefixProvider)}/orders/${view.orderId}',
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      view.clientDisplayNameSnapshot,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  RoleBadge(
                    label: view.myGroup.status.label,
                    color: _statusColor(view.myGroup.status, scheme),
                    icon: Icons.circle,
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                DateFormatter.relative(view.placedAt),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$itemCount article(s)',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  CurrencyText(
                    view.myGroup.subtotalFcfa,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(OrderStatus status, ColorScheme scheme) {
    return switch (status) {
      OrderStatus.pending => scheme.tertiary,
      OrderStatus.confirmed || OrderStatus.preparing => scheme.secondary,
      OrderStatus.inTransit => scheme.primary,
      OrderStatus.delivered => scheme.primary,
      OrderStatus.cancelled => scheme.error,
    };
  }
}
