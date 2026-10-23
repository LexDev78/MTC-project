import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/core/shop/shop.dart';
import 'package:mtc_app/core/utils/date_formatter.dart';
import 'package:mtc_app/features/catalog/presentation/providers/catalog_providers.dart';

import '../../domain/entities/order.dart';
import '../../domain/entities/order_status.dart';
import '../../domain/order_reference.dart';

/// Les étapes du suivi en points (`OrderProgress` du kit) pour un état de
/// commande : ce qui est fait en vert, l'étape en cours animée, la suite
/// en gris. Une commande annulée s'arrête sur un point rouge.
///
/// Les cinq libellés du kit (« Ordered, Processing, Packed, Shipped,
/// Delivered ») deviennent les cinq étapes de MTC, courts pour tenir à
/// cinq sur la largeur d'une carte.
List<OrderStep> orderSteps(OrderStatus statut) {
  const libelles = ['Passée', 'Confirmée', 'Préparée', 'En route', 'Livrée'];
  if (statut == OrderStatus.cancelled) {
    return const [
      OrderStep('Passée', OrderStepState.done),
      OrderStep('Annulée', OrderStepState.canceled),
    ];
  }
  final rang = switch (statut) {
    OrderStatus.pending => 0,
    OrderStatus.confirmed => 1,
    OrderStatus.preparing => 2,
    OrderStatus.inTransit => 3,
    OrderStatus.delivered => 4,
    OrderStatus.cancelled => 0,
  };
  return [
    for (var i = 0; i < libelles.length; i++)
      OrderStep(
        libelles[i],
        i < rang || statut == OrderStatus.delivered
            ? OrderStepState.done
            : i == rang
            ? OrderStepState.processing
            : OrderStepState.notDoneYet,
      ),
  ];
}

/// Les rubriques de l'historique (maquette « Orders » du kit) : chacune
/// rassemble des états de commande, avec son icône et la couleur de sa
/// pastille.
///
/// Écrit comme un `switch` exhaustif sur [OrderStatus] : un état ajouté à
/// l'énumération casse la compilation ici, au lieu de faire disparaître
/// les commandes qui le portent de toutes les rubriques.
enum OrderHistoryCategory {
  pending(
    label: 'En attente',
    icon: ShopIcons.clock,
    color: ShopColors.warning,
    emptyTitle: 'Aucune commande en attente',
    emptyMessage:
        'Une commande attend ici que la boutique la confirme. C\'est aussi '
        'le seul moment où vous pouvez encore l\'annuler.',
  ),
  preparing(
    label: 'En préparation',
    icon: ShopIcons.product,
    color: ShopColors.price,
    emptyTitle: 'Aucune commande en préparation',
    emptyMessage:
        'Une commande confirmée par la boutique se prépare ici avant de '
        'partir.',
  ),
  inTransit(
    label: 'En livraison',
    icon: ShopIcons.delivery,
    color: ShopColors.price,
    emptyTitle: 'Aucune commande en route',
    emptyMessage: 'Les commandes en chemin vers vous se suivent ici.',
  ),
  delivered(
    label: 'Livrées',
    icon: ShopIcons.doublecheck,
    color: ShopColors.success,
    emptyTitle: 'Aucune commande livrée',
    emptyMessage:
        'Vos commandes reçues restent ici, pour retrouver un achat passé.',
  ),
  cancelled(
    label: 'Annulées',
    icon: ShopIcons.closeCircle,
    color: ShopColors.error,
    emptyTitle: 'Aucune commande annulée',
    emptyMessage: 'Une commande annulée, par vous ou la boutique, reste ici.',
  );

  const OrderHistoryCategory({
    required this.label,
    required this.icon,
    required this.color,
    required this.emptyTitle,
    required this.emptyMessage,
  });

  final String label;
  final String icon;
  final Color color;
  final String emptyTitle;
  final String emptyMessage;

  static OrderHistoryCategory of(OrderStatus statut) => switch (statut) {
    OrderStatus.pending => OrderHistoryCategory.pending,
    OrderStatus.confirmed ||
    OrderStatus.preparing => OrderHistoryCategory.preparing,
    OrderStatus.inTransit => OrderHistoryCategory.inTransit,
    OrderStatus.delivered => OrderHistoryCategory.delivered,
    OrderStatus.cancelled => OrderHistoryCategory.cancelled,
  };
}

/// Une commande en carte du kit (`OrderStatusCard`) : son numéro, sa date,
/// le suivi en points, puis ses premiers articles. Toucher ouvre la fiche.
class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.order, this.maxItems = 2});

  final Order order;

  /// Au-delà, « et N autres articles » : une carte d'historique ne doit pas
  /// devenir la commande entière.
  final int maxItems;

  @override
  Widget build(BuildContext context) {
    final articles = [for (final g in order.supplierGroups) ...g.items];
    final reste = articles.length - maxItems;
    return OrderStatusCard(
      reference: order.reference,
      placedOn: DateFormatter.formatDayMonthYear(order.placedAt),
      steps: orderSteps(order.status),
      onTap: () => context.push(AppRoutes.orderDetail(order.id)),
      items: [
        for (final article in articles.take(maxItems))
          OrderItemLine(
            item: article,
            boutique: order.supplierGroups
                .firstWhere((g) => g.items.contains(article))
                .supplierName,
          ),
        if (reste > 0)
          Text(
            reste == 1 ? 'et 1 autre article' : 'et $reste autres articles',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
      ],
    );
  }
}

/// Un article commandé, en ligne du kit : la photo de la variante (ou du
/// produit), la boutique, le nom, le prix payé, la quantité.
class OrderItemLine extends ConsumerWidget {
  const OrderItemLine({super.key, required this.item, required this.boutique});

  final OrderItem item;
  final String boutique;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final produit = ref
        .watch(productDetailProvider(item.productId))
        .valueOrNull;
    final variante = produit?.variants.firstWhereOrNull(
      (v) => v.id == item.variantId,
    );
    return ShopProductListItem(
      data: ShopProductData(
        imagePath:
            variante?.imageUrls.firstOrNull ?? produit?.imageUrls.firstOrNull,
        brand: boutique,
        title: item.productNameSnapshot,
        // Le prix figé à la commande : c'est ce qui a été facturé.
        priceFcfa: item.unitPriceFcfaSnapshot,
      ),
      footer: Text(
        [
          if (item.variantNameSnapshot case final nom?) nom,
          'Quantité : ${item.quantity}',
        ].join(' · '),
      ),
    );
  }
}
