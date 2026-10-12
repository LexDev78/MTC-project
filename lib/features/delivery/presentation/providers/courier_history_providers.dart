import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/courier_history.dart';
import 'delivery_providers.dart';

/// Historique des courses terminées du livreur connecté.
///
/// Une requête ponctuelle et non un flux : une course **terminée** ne change
/// plus. Le seul événement qui touche cet écran est l'arrivée d'une nouvelle
/// course finie, et le livreur vient de la finir — il n'a pas besoin qu'on
/// la lui pousse.
final courierHistoryProvider = FutureProvider<List<CourierHistoryEntry>>((ref) {
  return ref.watch(deliveryRepositoryProvider).fetchHistory();
});

final courierStatsProvider = FutureProvider<CourierStats>((ref) {
  return ref.watch(deliveryRepositoryProvider).fetchStats();
});

/// Notes reçues par le livreur connecté, sans leurs auteurs.
final courierRatingsProvider = FutureProvider<List<CourierRating>>((ref) {
  return ref.watch(deliveryRepositoryProvider).fetchMyRatings();
});

/// La note que l'utilisateur courant a déjà déposée sur une course.
///
/// `null` signifie « pas encore noté », pas « interdit de noter » : la
/// distinction est faite par la RPC d'écriture, qui refusera une course qui
/// n'est pas la sienne.
final myDeliveryRatingProvider =
    FutureProvider.family<MyDeliveryRating?, String>((ref, deliveryId) {
      return ref
          .watch(deliveryRepositoryProvider)
          .fetchMyRatingForDelivery(deliveryId);
    });
