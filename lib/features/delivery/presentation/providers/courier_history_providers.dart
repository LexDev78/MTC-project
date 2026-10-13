import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';

import '../../domain/entities/courier_history.dart';
import 'delivery_providers.dart';

/// Historique des courses terminées du livreur connecté.
///
/// Une requête ponctuelle et non un flux : une course **terminée** ne change
/// plus. Le seul événement qui touche cet écran est l'arrivée d'une nouvelle
/// course finie, et le livreur vient de la finir — il n'a pas besoin qu'on
/// la lui pousse.
///
/// `autoDispose` et dépendant du livreur connecté, les deux pour la même
/// raison : sans cela, le résultat survit à une déconnexion. Vu en parcours
/// visuel — un livreur venait de recevoir une note, et son écran affichait
/// encore « aucune note » parce que la réponse vide d'avant la déconnexion
/// était toujours en cache. Sur un téléphone partagé entre deux livreurs,
/// c'est l'historique du précédent que le suivant aurait lu.
final courierHistoryProvider =
    FutureProvider.autoDispose<List<CourierHistoryEntry>>((ref) {
      ref.watch(currentCourierProvider);
      return ref.watch(deliveryRepositoryProvider).fetchHistory();
    });

final courierStatsProvider = FutureProvider.autoDispose<CourierStats>((ref) {
  ref.watch(currentCourierProvider);
  return ref.watch(deliveryRepositoryProvider).fetchStats();
});

/// Notes reçues par le livreur connecté, sans leurs auteurs.
final courierRatingsProvider =
    FutureProvider.autoDispose<List<CourierRating>>((ref) {
      ref.watch(currentCourierProvider);
      return ref.watch(deliveryRepositoryProvider).fetchMyRatings();
    });

/// La note que l'utilisateur courant a déjà déposée sur une course.
///
/// `null` signifie « pas encore noté », pas « interdit de noter » : la
/// distinction est faite par la RPC d'écriture, qui refusera une course qui
/// n'est pas la sienne.
///
/// Dépend de l'utilisateur pour la même raison que ci-dessus : « vous avez
/// mis 4 étoiles » ne doit pas s'afficher au compte suivant.
final myDeliveryRatingProvider =
    FutureProvider.autoDispose.family<MyDeliveryRating?, String>((
      ref,
      deliveryId,
    ) {
      ref.watch(currentUserProvider.select((user) => user.valueOrNull?.id));
      return ref
          .watch(deliveryRepositoryProvider)
          .fetchMyRatingForDelivery(deliveryId);
    });
