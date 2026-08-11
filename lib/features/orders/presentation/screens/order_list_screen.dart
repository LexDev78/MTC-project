import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';

import '../providers/order_providers.dart';
import '../widgets/order_list_tile.dart';

class OrderListScreen extends ConsumerWidget {
  const OrderListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersForUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mes commandes')),
      body: AsyncValueWidget(
        value: ordersAsync,
        data: (orders) {
          if (orders.isEmpty) {
            return const MtcEmptyState(
              icon: Icons.receipt_long_outlined,
              title: "Vous n'avez pas encore de commande",
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: orders.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) =>
                OrderListTile(order: orders[index]),
          );
        },
      ),
    );
  }
}
