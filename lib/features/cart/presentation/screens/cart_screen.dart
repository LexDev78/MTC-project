import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';

import 'package:mtc_app/features/orders/presentation/providers/checkout_providers.dart';

import '../controllers/cart_controller.dart';
import '../providers/cart_providers.dart';
import '../widgets/cart_line_item.dart';
import '../widgets/cart_summary_bar.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vider le panier ?'),
        content: const Text('Tous les articles seront retirés du panier.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Vider'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(cartControllerProvider.notifier).clearCart();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(cartItemsProvider);
    final hasItems = itemsAsync.valueOrNull?.isNotEmpty == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panier'),
        actions: [
          if (hasItems)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Vider le panier',
              onPressed: () => _confirmClear(context, ref),
            ),
        ],
      ),
      body: AsyncValueWidget(
        value: itemsAsync,
        data: (items) {
          if (items.isEmpty) {
            return const MtcEmptyState(
              icon: Icons.shopping_cart_outlined,
              title: 'Votre panier est vide',
              subtitle: 'Parcourez le catalogue pour ajouter des produits.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) => CartLineItem(item: items[index]),
          );
        },
      ),
      bottomNavigationBar: hasItems
          ? CartSummaryBar(
              onCheckout: () {
                // Clears any single-item "Acheter" override left over from
                // an abandoned buy-now attempt — this is the real cart, so
                // checkout must build its groups from every item in it, not
                // just whichever product was last tapped "Acheter" on.
                ref.read(buyNowItemProvider.notifier).state = null;
                context.push(AppRoutes.clientCheckout);
              },
            )
          : null,
    );
  }
}
