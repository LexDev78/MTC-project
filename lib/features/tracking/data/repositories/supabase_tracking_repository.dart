import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mtc_app/core/utils/realtime_retry.dart';

import '../../domain/entities/delivery_tracking.dart';
import '../../domain/repositories/tracking_repository.dart';
import '../../domain/route_follower.dart';
import '../datasources/osrm_route_datasource.dart';

/// Suivi réel d'une livraison MTC : la position que le livreur pousse depuis
/// son app (`push_courier_position`, `0052`), poussée au client par Realtime.
///
/// Remplace le simulateur de trajet (`InMemoryTrackingRepository`), qui
/// faisait avancer un point imaginaire entre deux villes. Un faux suivi est
/// pire que pas de suivi : le client s'organise à partir de ce qu'il voit, et
/// sortir attendre un livreur qui n'est pas là lui coûte plus que de ne rien
/// savoir.
///
/// Les commandes livrées par le fournisseur lui-même n'ont pas de course, donc
/// pas de position : le flux ne produit alors rien et l'écran le dit
/// (`LiveTrackingScreen`). C'est préférable à une carte animée inventée.
class SupabaseTrackingRepository implements TrackingRepository {
  SupabaseTrackingRepository(this._client, OsrmRouteDatasource routes)
    : _follower = RouteFollower(routes);

  final SupabaseClient _client;

  /// Décide quand recalculer l'itinéraire : déviation du tracé, ou progression
  /// le long de celui-ci (voir [RouteFollower]).
  final RouteFollower _follower;

  @override
  Stream<DeliveryTracking> watchTrackingForOrder({
    required String orderId,
    required String groupId,
    required LatLng origin,
    required LatLng destination,
  }) {
    return withRealtimeRetry(
      () => _client
          .from('deliveries')
          .stream(primaryKey: ['id'])
          .eq('supplier_group_id', groupId)
          // Deux émissions par mise à jour, et c'est délibéré : d'abord la
          // position avec un tracé en ligne droite, tout de suite ; puis le
          // même état avec l'itinéraire routier quand il arrive.
          //
          // Attendre le routage avant la première émission laissait l'écran
          // sur un chargement tant qu'un service **tiers** n'avait pas
          // répondu — jusqu'à six secondes, et davantage s'il est lent. Le
          // client regardait une roue tourner alors que l'app savait déjà où
          // était son livreur.
          .asyncExpand(
            (rows) => rows.isEmpty
                ? const Stream<DeliveryTracking>.empty()
                : _trackingUpdates(
                    row: rows.first,
                    orderId: orderId,
                    groupId: groupId,
                    origin: origin,
                    destination: destination,
                  ),
          ),
    );
  }

  Stream<DeliveryTracking> _trackingUpdates({
    required Map<String, dynamic> row,
    required String orderId,
    required String groupId,
    required LatLng origin,
    required LatLng destination,
  }) async* {
    final base = _toTracking(
      row: row,
      orderId: orderId,
      groupId: groupId,
      origin: origin,
      destination: destination,
    );
    yield base;

    // Course terminée : plus de trajet à tracer.
    if (base.status == TrackingStatus.delivered) return;

    final road = await _follower.follow(from: base.current, to: destination);
    if (road == null) return;
    yield base.copyWith(
      route: road.points,
      // Le temps rendu par le moteur de routage tient compte des rues
      // réellement empruntables, ce qu'une moyenne à vol d'oiseau ignore.
      etaMinutes: (road.duration.inSeconds / 60).ceil().clamp(1, 240),
    );
  }

  DeliveryTracking _toTracking({
    required Map<String, dynamic> row,
    required String orderId,
    required String groupId,
    required LatLng origin,
    required LatLng destination,
  }) {
    final status = row['status'] as String;
    final latitude = (row['courier_latitude'] as num?)?.toDouble();
    final longitude = (row['courier_longitude'] as num?)?.toDouble();

    // Pas encore de position : le livreur n'a pas démarré, ou la course vient
    // d'être livrée (la position est effacée à ce moment-là, `0052`). On
    // place le repère au point de départ plutôt que nulle part — une carte
    // sans repère se lit comme un bug.
    final current = latitude == null || longitude == null
        ? (status == 'delivered' ? destination : origin)
        : LatLng(latitude, longitude);

    final totalKm = _distance(origin, destination);
    final remainingKm = _distance(current, destination);
    final progress = totalKm == 0
        ? 1.0
        : ((totalKm - remainingKm) / totalKm).clamp(0.0, 1.0);


    return DeliveryTracking(
      orderId: orderId,
      groupId: groupId,
      origin: origin,
      destination: destination,
      current: current,
      // Ligne droite ici ; l'itinéraire par les rues arrive à l'émission
      // suivante (voir `_trackingUpdates`). L'historique du livreur n'est
      // jamais conservé : ce serait un journal de déplacements d'une
      // personne, pour un trait dont personne n'a besoin.
      route: [origin, current, destination],
      progressRatio: progress,
      etaMinutes: _etaMinutes(remainingKm),
      status: switch (status) {
        'delivered' => TrackingStatus.delivered,
        'picked_up' => TrackingStatus.inTransit,
        _ => TrackingStatus.preparing,
      },
    );
  }

  static const _distanceCalculator = Distance();

  double _distance(LatLng from, LatLng to) =>
      _distanceCalculator.as(LengthUnit.Kilometer, from, to);

  /// Repli quand le service de routage ne répond pas : 20 km/h de moyenne à
  /// vol d'oiseau, l'ordre de grandeur d'un deux-roues en ville. Volontaire-
  /// ment grossier — mieux vaut une fourchette honnête qu'une précision que
  /// rien ne soutient.
  int _etaMinutes(double remainingKm) {
    final minutes = (remainingKm / 20 * 60).ceil();
    return minutes.clamp(1, 240);
  }
}
