import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'delivery_providers.dart';

/// Pousse la position du livreur tant qu'il est en service.
///
/// Deux usages pour une seule écriture (`push_courier_position`, `0052`) : la
/// fiche du livreur, qui sert à lui proposer les courses les plus proches, et
/// sa course en cours, que le client suit sur la carte.
///
/// **Pendant l'usage de l'app seulement.** La localisation en arrière-plan
/// demande une permission distincte et une justification auprès des magasins
/// d'applications ; tant que le livreur garde l'app ouverte pendant sa
/// tournée — ce qu'il fait, c'est son outil de travail — le suivi est
/// continu.
///
/// [_distanceFilterMeters] plutôt qu'un rythme fixe : un livreur à l'arrêt
/// n'envoie rien, un livreur qui roule envoie à chaque pâté de maisons. Une
/// position par seconde coûterait de la batterie et du forfait pour redire
/// la même chose.
const _distanceFilterMeters = 50;

/// Démarre/arrête le suivi selon que le livreur est en service.
///
/// `keepAlive` implicite : le provider reste monté tant que quelque chose
/// l'écoute, et l'écran livreur l'écoute en permanence.
final courierPositionProvider = StreamProvider<Position?>((ref) {
  final courier = ref.watch(currentCourierProvider);
  if (courier == null || !courier.isOnline) return Stream.value(null);

  final repository = ref.watch(deliveryRepositoryProvider);
  final controller = StreamController<Position?>();
  StreamSubscription<Position>? subscription;

  Future<void> start() async {
    if (!await _ensurePermission()) {
      // Refus de l'utilisateur : on n'insiste pas et on ne pousse rien. Le
      // livreur reste « en service » mais ne recevra pas de course, faute de
      // position — l'écran le dit (voir `CourierHomeScreen`).
      controller.add(null);
      return;
    }

    // Une première position tout de suite, avant de s'abonner au flux : avec
    // un filtre de distance, un livreur **à l'arrêt** qui prend son service
    // peut n'émettre aucun événement avant d'avoir roulé cinquante mètres.
    // Il resterait alors sans position connue, donc sans aucune course
    // proposée, en croyant être en service.
    try {
      final first = await Geolocator.getCurrentPosition();
      controller.add(first);
      unawaited(
        repository
            .pushPosition(
              latitude: first.latitude,
              longitude: first.longitude,
            )
            .catchError((_) {}),
      );
    } catch (_) {
      // Pas de fix immédiat (intérieur, GPS froid) : le flux ci-dessous
      // prendra le relais dès qu'une position arrive.
    }

    subscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: _distanceFilterMeters,
          ),
        ).listen((position) {
          controller.add(position);
          // Erreur réseau ignorée volontairement : la position suivante
          // arrive dans quelques secondes et la remplacera. Faire remonter
          // chaque échec transformerait une perte de réseau passagère en
          // écran d'erreur pendant une tournée.
          unawaited(
            repository
                .pushPosition(
                  latitude: position.latitude,
                  longitude: position.longitude,
                )
                .catchError((_) {}),
          );
        });
  }

  unawaited(start());
  ref.onDispose(() {
    unawaited(subscription?.cancel());
    unawaited(controller.close());
  });

  return controller.stream;
});

/// Demande la permission si besoin, sans jamais forcer.
Future<bool> _ensurePermission() async {
  if (!await Geolocator.isLocationServiceEnabled()) return false;
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  // `deniedForever` ne se rattrape pas depuis l'app : seul un passage par les
  // réglages du téléphone le change, et redemander ici ne ferait qu'afficher
  // un refus immédiat.
  return permission == LocationPermission.always ||
      permission == LocationPermission.whileInUse;
}
