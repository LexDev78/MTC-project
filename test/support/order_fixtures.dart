import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:mtc_app/features/delivery/domain/entities/courier_delivery.dart';
import 'package:mtc_app/features/delivery/domain/entities/courier_history.dart';
import 'package:mtc_app/features/delivery/presentation/providers/courier_history_providers.dart';
import 'package:mtc_app/features/delivery/presentation/providers/delivery_providers.dart';
import 'package:mtc_app/features/orders/domain/entities/fulfillment.dart';
import 'package:mtc_app/features/orders/domain/entities/order.dart';
import 'package:mtc_app/features/orders/domain/entities/order_status.dart';
import 'package:mtc_app/features/orders/domain/entities/payment.dart';
import 'package:mtc_app/features/orders/presentation/providers/order_providers.dart';
import 'package:mtc_app/features/promo_codes/presentation/providers/promo_code_providers.dart';
import 'package:mtc_app/features/ratings/presentation/providers/review_providers.dart';

import 'shop_fixtures.dart';

/// Des commandes de démonstration, une par situation que l'écran doit
/// savoir montrer : livrée (avis et note du livreur), en route (QR de
/// remise, suivi), en attente (annulable, prioritaire, message à la
/// boutique) et annulée par la boutique, retirée en point relais.
///
/// Datées par rapport à aujourd'hui, pour que les filtres de période
/// rendent les mêmes comptes quel que soit le jour du test : sur 30 jours,
/// toutes sauf l'annulée (il y a 60 jours).

final _produits = {for (final p in catalogueDemo()) p.id: p};

OrderItem article(
  String produit,
  int quantite, {
  int? prix,
  String? variante,
  String? varianteId,
}) {
  final p = _produits[produit]!;
  return OrderItem(
    productId: p.id,
    productNameSnapshot: p.name,
    unitPriceFcfaSnapshot: prix ?? p.priceFcfa,
    quantity: quantite,
    variantId: varianteId,
    variantNameSnapshot: variante,
  );
}

int _sousTotal(List<OrderItem> articles) =>
    articles.fold(0, (s, a) => s + a.unitPriceFcfaSnapshot * a.quantity);

OrderSupplierGroup groupe(
  String id,
  String boutique,
  List<OrderItem> articles, {
  required OrderStatus statut,
  DeliveryMode mode = DeliveryMode.mtcDelivery,
  int frais = 1500,
  String? motif,
  CancelledBy? annuleePar,
}) => OrderSupplierGroup(
  id: id,
  supplierId: 'f-$boutique',
  supplierName: boutique,
  items: articles,
  deliveryMode: mode,
  deliveryFeeFcfa: frais,
  subtotalFcfa: _sousTotal(articles),
  status: statut,
  cancellationReason: motif,
  cancelledBy: annuleePar,
);

Order commande({
  required String id,
  required List<OrderSupplierGroup> groupes,
  required OrderStatus statut,
  required DateTime passeeLe,
  int prioritaire = 0,
  FulfillmentMethod retrait = FulfillmentMethod.homeDelivery,
  PaymentStatus paiement = PaymentStatus.pendingOnDelivery,
  MobileMoneyProvider? operateur,
  String? message,
}) {
  final pointRelais = retrait == FulfillmentMethod.pickupPoint;
  return Order(
    id: id,
    clientId: 'client-awa',
    clientDisplayNameSnapshot: 'Awa Traoré',
    supplierGroups: groupes,
    status: statut,
    placedAt: passeeLe,
    totalFcfa:
        groupes.fold<int>(0, (s, g) => s + g.subtotalFcfa + g.deliveryFeeFcfa) +
        prioritaire,
    deliveryCity: 'Bamako',
    // Ce que le serveur rend au client : tout (`client_contact`, `0120`).
    clientContact: OrderContact(
      phone: '+223 70 12 34 56',
      addressLabel: pointRelais ? 'Point relais Hippodrome' : 'Maison',
      addressDetails: pointRelais
          ? 'Avenue Cheick Zayed, à côté de la pharmacie'
          : 'Rue 312, porte 18, Badalabougou',
      latitude: 12.62,
      longitude: -7.98,
    ),
    fulfillmentMethod: retrait,
    deliveryDate: pointRelais ? null : DateTime.utc(2026, 10, 22),
    deliveryTimeSlotLabel: pointRelais ? null : '08:00 – 12:00',
    isPriority: prioritaire > 0,
    priorityFeeFcfa: prioritaire,
    supplierMessageType: message == null
        ? SupplierMessageType.none
        : SupplierMessageType.text,
    supplierMessageText: message,
    paymentMethod: paiement == PaymentStatus.paid
        ? PaymentMethod.now
        : PaymentMethod.onDelivery,
    paymentStatus: paiement,
    mobileMoneyProvider: operateur,
  );
}

final commandeLivree = commande(
  id: '8c41f0d2-6b3e-4f7a-9d21-0e5c7a3b9f11',
  statut: OrderStatus.delivered,
  passeeLe: maintenant.subtract(const Duration(days: 20)),
  paiement: PaymentStatus.paid,
  operateur: MobileMoneyProvider.orangeMoney,
  groupes: [
    groupe('g-bogolan', 'Bogolan Bamako', [
      article(
        'bogolan',
        2,
        prix: 12000,
        variante: 'Indigo · 2 m',
        varianteId: 'v-indigo-2',
      ),
    ], statut: OrderStatus.delivered),
    groupe(
      'g-mopti',
      'Atelier de Mopti',
      [article('masque', 1, prix: 22500), article('panier', 2)],
      statut: OrderStatus.delivered,
      mode: DeliveryMode.selfDelivery,
      frais: 0,
    ),
  ],
);

final commandeEnRoute = commande(
  id: 'b7e2a915-3c4d-4e8f-a1b2-c3d4e5f60718',
  statut: OrderStatus.inTransit,
  passeeLe: maintenant.subtract(const Duration(days: 3)),
  message: 'Appelez-moi en arrivant, le portail bleu est fermé à clé.',
  groupes: [
    groupe(
      'g-panneau',
      'MTC Officiel',
      [article('panneau', 1, prix: 55250)],
      statut: OrderStatus.inTransit,
      frais: 2000,
    ),
    groupe(
      'g-kita',
      'Coopérative de Kita',
      [article('miel', 3)],
      statut: OrderStatus.preparing,
      mode: DeliveryMode.selfDelivery,
      frais: 1000,
    ),
  ],
);

final commandeEnAttente = commande(
  id: '2d9a6c0e-7f18-4b3a-8e5d-4c3b2a1f0e9d',
  statut: OrderStatus.pending,
  passeeLe: maintenant.subtract(const Duration(hours: 5)),
  prioritaire: 1000,
  groupes: [
    groupe('g-riz', 'Grenier du Mali', [
      article('riz', 2),
    ], statut: OrderStatus.pending),
  ],
);

final commandeAnnulee = commande(
  id: 'f0a3b8d7-1e2c-4d5f-9a8b-7c6d5e4f3a2b',
  statut: OrderStatus.cancelled,
  passeeLe: maintenant.subtract(const Duration(days: 60)),
  retrait: FulfillmentMethod.pickupPoint,
  groupes: [
    groupe(
      'g-tole',
      'Matériaux Sikasso',
      [article('tole', 1)],
      statut: OrderStatus.cancelled,
      mode: DeliveryMode.selfDelivery,
      frais: 0,
      motif: 'Rupture de stock chez notre fournisseur.',
      annuleePar: CancelledBy.supplier,
    ),
  ],
);

/// Les commandes du client, de la plus récente à la plus ancienne, comme
/// le dépôt les rend.
List<Order> commandesDemo() => [
  commandeEnAttente,
  commandeEnRoute,
  commandeLivree,
  commandeAnnulee,
];

/// Tout ce que les écrans de commande lisent, servi sans base : les
/// commandes, les photos des articles, la course de chaque part livrée par
/// MTC, son QR de remise, la note déjà donnée au livreur et l'état des avis.
List<Override> donneesCommandes({List<Order>? commandes}) {
  final liste = commandes ?? commandesDemo();
  final parId = {for (final c in liste) c.id: c};
  const courses = <String, ({String id, DeliveryStatus status})>{
    'g-bogolan': (id: 'course-bogolan', status: DeliveryStatus.delivered),
    'g-panneau': (id: 'course-panneau', status: DeliveryStatus.pickedUp),
    'g-riz': (id: 'course-riz', status: DeliveryStatus.offered),
  };
  return [
    ordersForUserProvider.overrideWith((ref) => Stream.value(liste)),
    orderDetailProvider.overrideWith((ref, id) => Stream.value(parId[id]!)),
    productDetailProvider.overrideWith((ref, id) async => _produits[id]!),
    deliveryForGroupProvider.overrideWith(
      (ref, groupe) => Stream.value(courses[groupe]),
    ),
    deliveryCodeProvider.overrideWith(
      (ref, cle) async => 'MTC-REMISE-${cle.deliveryId}',
    ),
    myDeliveryRatingProvider.overrideWith((ref, course) async => null),
    canReviewProvider.overrideWith(
      (ref, cle) async => cle.groupId != 'g-mopti',
    ),
    orderPromoCodesProvider.overrideWith(
      (ref, commande) async => commande == commandeLivree.id
          ? const {'g-bogolan': (code: 'BOGOLAN10', discountFcfa: 2400)}
          : const {},
    ),
  ];
}

/// Le livreur de la commande livrée, déjà noté — pour l'état « modifier ».
Override livreurDejaNote() => myDeliveryRatingProvider.overrideWith(
  (ref, course) async => const MyDeliveryRating(stars: 5),
);
