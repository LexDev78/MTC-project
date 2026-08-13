import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';
import 'package:mtc_app/features/profile/presentation/providers/profile_providers.dart';

import '../../domain/entities/fulfillment.dart';
import '../../domain/entities/order_status.dart';
import '../../domain/entities/payment.dart';
import '../controllers/checkout_controller.dart';
import '../providers/checkout_providers.dart';
import '../widgets/delivery_mode_selector.dart';
import '../widgets/fulfillment_method_selector.dart';
import '../widgets/home_delivery_form.dart';
import '../widgets/mobile_money_payment_sheet.dart';
import '../widgets/payment_method_selector.dart';
import '../widgets/pickup_point_picker.dart';

class CheckoutScreen extends ConsumerWidget {
  const CheckoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(checkoutGroupsProvider);
    final address = ref.watch(defaultAddressProvider);
    final checkoutState = ref.watch(checkoutControllerProvider);
    final fulfillmentMethod = ref.watch(fulfillmentMethodProvider);
    final isPriority =
        fulfillmentMethod == FulfillmentMethod.homeDelivery &&
        ref.watch(isPriorityOrderProvider);
    final scheme = Theme.of(context).colorScheme;

    // Computed here (not just inside the body's AsyncValueWidget) so the
    // bottom action bar's payment step can know the amount to charge too.
    final groupsForTotals = groupsAsync.valueOrNull ?? const [];
    final subtotal = groupsForTotals.fold<int>(
      0,
      (sum, g) => sum + g.subtotalFcfa,
    );
    final deliveryFees = groupsForTotals.fold<int>(0, (sum, g) {
      final bool isMtc;
      if (fulfillmentMethod == FulfillmentMethod.pickupPoint) {
        // MTC always fetches the parcel from the supplier and brings it to
        // the pickup point — there's no "supplier delivers it themselves"
        // option once the client isn't receiving it at their own address.
        isMtc = g.allowsMtcDelivery;
      } else {
        final chosen = ref.watch(deliveryModeChoiceProvider(g.supplierId));
        isMtc =
            chosen == DeliveryMode.mtcDelivery ||
            (chosen == null && !g.allowsSelfDelivery);
      }
      return sum + (isMtc ? g.mtcDeliveryFeeFcfa : 0);
    });
    final priorityFee = isPriority ? priorityOrderFeeFcfa : 0;
    final total = subtotal + deliveryFees + priorityFee;

    return Scaffold(
      appBar: AppBar(title: const Text('Commande')),
      body: AsyncValueWidget(
        value: groupsAsync,
        data: (groups) {
          if (groups.isEmpty) {
            return const MtcEmptyState(
              icon: Icons.shopping_cart_outlined,
              title: 'Votre panier est vide',
            );
          }

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              const FulfillmentMethodSelector(),
              const SizedBox(height: AppSpacing.lg),
              if (fulfillmentMethod == FulfillmentMethod.pickupPoint)
                const PickupPointPicker()
              else ...[
                Text(
                  'Adresse de livraison',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.location_on_outlined),
                    title: Text(address?.label ?? 'Aucune adresse'),
                    subtitle: Text(
                      address != null
                          ? '${address.details}, ${address.city}'
                          : 'Ajoutez-en une pour continuer',
                    ),
                    trailing: TextButton(
                      onPressed: () =>
                          context.push(AppRoutes.clientProfileEdit),
                      child: const Text('Changer'),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const HomeDeliveryForm(),
              ],
              const SizedBox(height: AppSpacing.lg),
              for (final group in groups) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.supplierName,
                          style: Theme.of(context).textTheme.titleSmall,
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
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ),
                                CurrencyText(
                                  item.unitPriceFcfaSnapshot * item.quantity,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        if (fulfillmentMethod ==
                            FulfillmentMethod.homeDelivery) ...[
                          const Divider(),
                          DeliveryModeSelector(group: group),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              Text('Paiement', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              const PaymentMethodSelector(),
              if (ref.watch(paymentMethodProvider) == PaymentMethod.now) ...[
                const SizedBox(height: AppSpacing.sm),
                _MobileMoneyStatusRow(
                  provider: ref.watch(mobileMoneyProviderChoiceProvider),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              _TotalsCard(
                subtotal: subtotal,
                deliveryFees: deliveryFees,
                priorityFee: priorityFee,
                total: total,
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: groupsAsync.valueOrNull?.isNotEmpty == true
          ? Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: scheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: MtcPrimaryButton(
                  label: fulfillmentMethod == FulfillmentMethod.homeDelivery &&
                          ref.watch(paymentMethodProvider) == PaymentMethod.now &&
                          ref.watch(mobileMoneyProviderChoiceProvider) == null
                      ? 'Payer et commander'
                      : 'Confirmer la commande',
                  isLoading: checkoutState.isLoading,
                  onPressed: () async {
                    if (ref.read(paymentMethodProvider) == PaymentMethod.now &&
                        ref.read(mobileMoneyProviderChoiceProvider) == null) {
                      final paid = await showMobileMoneyPaymentSheet(
                        context,
                        amountFcfa: total,
                      );
                      if (!paid) return;
                      if (!context.mounted) return;
                    }
                    final success = await ref
                        .read(checkoutControllerProvider.notifier)
                        .placeOrder();
                    if (!context.mounted) return;
                    if (success) {
                      final order = ref
                          .read(checkoutControllerProvider)
                          .valueOrNull;
                      if (order != null) {
                        context.pushReplacement(
                          AppRoutes.orderDetail(order.id),
                        );
                      }
                    } else {
                      final error = ref.read(checkoutControllerProvider).error;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            error?.toString() ?? 'Une erreur est survenue',
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
            )
          : null,
    );
  }
}

/// Small confirmation/prompt line under the payment selector — shows
/// whether the mocked Mobile Money payment already went through, or that
/// it's still pending so tapping "Payer et commander" will ask for it.
class _MobileMoneyStatusRow extends StatelessWidget {
  const _MobileMoneyStatusRow({required this.provider});

  final MobileMoneyProvider? provider;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (provider == null) {
      return Text(
        'Le paiement vous sera demandé à la confirmation.',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      );
    }
    return Row(
      children: [
        Icon(Icons.check_circle_rounded, size: 16, color: scheme.primary),
        const SizedBox(width: AppSpacing.xs),
        Text(
          'Payé via ${provider!.label}',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: scheme.primary),
        ),
      ],
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({
    required this.subtotal,
    required this.deliveryFees,
    required this.priorityFee,
    required this.total,
  });

  final int subtotal;
  final int deliveryFees;
  final int priorityFee;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            _TotalsRow(label: 'Sous-total', amountFcfa: subtotal),
            _TotalsRow(label: 'Livraison', amountFcfa: deliveryFees),
            if (priorityFee > 0)
              _TotalsRow(label: 'Commande prioritaire', amountFcfa: priorityFee),
            const Divider(),
            _TotalsRow(label: 'Total', amountFcfa: total, emphasize: true),
          ],
        ),
      ),
    );
  }
}

class _TotalsRow extends StatelessWidget {
  const _TotalsRow({
    required this.label,
    required this.amountFcfa,
    this.emphasize = false,
  });

  final String label;
  final int amountFcfa;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final style = emphasize
        ? Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          CurrencyText(amountFcfa, style: style),
        ],
      ),
    );
  }
}
