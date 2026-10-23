import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:mtc_app/features/orders/presentation/screens/order_cancel_screen.dart';
import 'package:mtc_app/features/orders/presentation/screens/order_detail_screen.dart';
import 'package:mtc_app/features/orders/presentation/screens/order_list_screen.dart';
import 'package:mtc_app/features/orders/presentation/widgets/order_cards.dart';
import 'package:mtc_app/features/ratings/presentation/screens/submit_review_screen.dart';
import 'package:mtc_app/features/tracking/domain/entities/delivery_tracking.dart';
import 'package:mtc_app/features/tracking/presentation/providers/tracking_providers.dart';
import 'package:mtc_app/features/tracking/presentation/screens/live_tracking_screen.dart';
import 'package:mtc_app/features/tracking/presentation/widgets/eta_banner.dart';

import 'package:mtc_app/features/orders/presentation/providers/order_history_filter.dart';

import '../support/order_fixtures.dart';
import '../support/shop_capture.dart';

Future<void> _toucher(WidgetTester tester, String texte) async {
  await tester.tap(find.text(texte).first);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

DeliveryTracking _trajet({required TrackingStatus statut}) => DeliveryTracking(
  orderId: 'cmd',
  groupId: 'g',
  origin: const LatLng(12.6392, -8.0029),
  destination: const LatLng(12.6492, -7.9929),
  current: const LatLng(12.6442, -7.9979),
  route: const [],
  progressRatio: statut == TrackingStatus.delivered ? 1 : 0.45,
  etaMinutes: 12,
  status: statut,
);

void main() {
  capturerEcran(
    'commandes',
    () => const OrderListScreen(),
    overrides: donneesCommandes,
  );
  capturerEcran(
    'commandes_recherche',
    () => const OrderListScreen(),
    overrides: donneesCommandes,
    hauteur: 1100,
    geste: (tester) async {
      await tester.enterText(find.byType(TextField), 'miel');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    },
  );
  capturerEcran(
    'commandes_filtre',
    () => const OrderListScreen(),
    overrides: donneesCommandes,
    geste: (tester) async {
      await tester.tap(find.byTooltip('Filtrer par période'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await _toucher(tester, '30 derniers jours');
    },
  );
  capturerEcran(
    'commandes_30_jours',
    () => const OrderListScreen(),
    overrides: () => [
      ...donneesCommandes(),
      orderPeriodProvider.overrideWith((ref) => OrderPeriod.last30Days),
    ],
  );
  capturerEcran(
    'commandes_vide',
    () => const OrderListScreen(),
    overrides: () => donneesCommandes(commandes: const []),
  );
  capturerEcran(
    'commandes_livrees',
    () =>
        const OrdersByCategoryScreen(category: OrderHistoryCategory.delivered),
    overrides: donneesCommandes,
  );
  capturerEcran(
    'commandes_en_preparation_vide',
    () =>
        const OrdersByCategoryScreen(category: OrderHistoryCategory.preparing),
    overrides: () => donneesCommandes(commandes: [commandeLivree]),
  );
  capturerEcran(
    'commande_livree',
    () => OrderDetailScreen(orderId: commandeLivree.id),
    overrides: donneesCommandes,
    hauteur: 1800,
  );
  capturerEcran(
    'commande_livree_livreur_note',
    () => OrderDetailScreen(orderId: commandeLivree.id),
    overrides: () => [...donneesCommandes(), livreurDejaNote()],
    hauteur: 1500,
  );
  capturerEcran(
    'commande_en_route',
    () => OrderDetailScreen(orderId: commandeEnRoute.id),
    overrides: donneesCommandes,
    hauteur: 1700,
  );
  capturerEcran(
    'commande_en_attente',
    () => OrderDetailScreen(orderId: commandeEnAttente.id),
    overrides: donneesCommandes,
    hauteur: 1100,
  );
  capturerEcran(
    'commande_annulee',
    () => OrderDetailScreen(orderId: commandeAnnulee.id),
    overrides: donneesCommandes,
  );
  capturerEcran(
    'annuler_commande',
    () => OrderCancelScreen(orderId: commandeEnAttente.id, groupId: 'g-riz'),
    overrides: donneesCommandes,
    hauteur: 1000,
    geste: (tester) => _toucher(tester, 'Autre raison'),
  );
  capturerEcran(
    'annuler_commande_trop_tard',
    () => OrderCancelScreen(orderId: commandeEnRoute.id, groupId: 'g-kita'),
    overrides: donneesCommandes,
  );
  // Le bandeau du suivi, seul : la carte charge ses tuiles sur le réseau.
  capturerEcran(
    'suivi_bandeau',
    () => Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            EtaBanner(tracking: _trajet(statut: TrackingStatus.inTransit)),
            EtaBanner(tracking: _trajet(statut: TrackingStatus.delivered)),
          ],
        ),
      ),
    ),
  );
  capturerEcran(
    'suivi_indisponible',
    () => const LiveTrackingScreen(orderId: 'cmd'),
    overrides: () => [
      trackingParamsProvider('cmd').overrideWith(
        (ref) async => (
          groupId: 'g',
          origin: const LatLng(12.6392, -8.0029),
          destination: const LatLng(12.6492, -7.9929),
          isMtcDelivery: false,
        ),
      ),
    ],
  );
  capturerEcran(
    'avis_formulaire',
    () => SubmitReviewScreen(orderId: commandeLivree.id, groupId: 'g-bogolan'),
    overrides: donneesCommandes,
    geste: (tester) => _toucher(tester, 'Envoyer l\'avis'),
  );
  capturerEcran(
    'avis_deja_publie',
    () => SubmitReviewScreen(orderId: commandeLivree.id, groupId: 'g-mopti'),
    overrides: donneesCommandes,
  );
}
