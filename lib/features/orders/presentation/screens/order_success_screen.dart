import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/core/shop/shop.dart';
import 'package:mtc_app/core/utils/currency_formatter.dart';

import '../../domain/entities/payment.dart';
import '../../domain/order_reference.dart';
import '../providers/order_providers.dart';

/// Après la commande (maquette « Thanks for your order » du kit) : la fusée,
/// le remerciement, le numéro et le montant, puis « Suivre ma commande ».
///
/// Le montant dit s'il reste à payer : un paiement Mobile Money n'est
/// constaté que par MTC (`mark_order_paid`), et une commande à régler à la
/// livraison ne doit pas se lire comme payée.
class OrderSuccessScreen extends ConsumerWidget {
  const OrderSuccessScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final commande = ref.watch(orderDetailProvider(orderId)).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Commande'),
        // La commande est passée : revenir en arrière ramènerait au
        // paiement d'une commande qui existe déjà.
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Retour à l\'accueil',
          onPressed: () => context.go(AppRoutes.clientHome),
          icon: const ShopIcon(ShopIcons.arrowLeft),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          ShopSizes.screenMargin,
          ShopSizes.padding,
          ShopSizes.screenMargin,
          ShopSizes.screenMargin,
        ),
        children: [
          ShopIllustrationImage(
            ShopIllustration.orderSuccess,
            height: MediaQuery.sizeOf(context).height * 0.3,
          ),
          const SizedBox(height: ShopSizes.padding * 3),
          Text(
            'Merci pour votre commande',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: ShopSizes.padding / 2),
          Text(
            'La boutique la prépare. Vous serez prévenu à chaque étape, '
            'jusqu\'à la livraison.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.textTheme.bodyMedium?.color,
              height: 1.4,
            ),
          ),
          const SizedBox(height: ShopSizes.padding * 2),
          OrderSummaryCard(
            title: 'Détail de la commande',
            rows: [
              SummaryRow(
                label: 'Numéro de commande',
                value: commande?.reference ?? '…',
              ),
              SummaryRow(
                label: commande?.paymentStatus == PaymentStatus.paid
                    ? 'Montant payé'
                    : 'Montant à régler',
                value: commande == null
                    ? '…'
                    : CurrencyFormatter.formatFcfa(commande.totalFcfa),
                valueColor: commande?.paymentStatus == PaymentStatus.paid
                    ? ShopColors.success
                    : null,
              ),
            ],
            totals: const [],
          ),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        label: 'Suivre ma commande',
        icon: const ShopIcon(ShopIcons.trackorder, color: Colors.white),
        onPressed: () =>
            context.pushReplacement(AppRoutes.orderDetail(orderId)),
      ),
    );
  }
}
