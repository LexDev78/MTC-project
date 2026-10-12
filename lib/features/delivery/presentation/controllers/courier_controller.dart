import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/core/mock_data/malian_locations.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';

import '../../domain/entities/courier_delivery.dart';
import '../../domain/repositories/delivery_repository.dart';
import '../providers/delivery_providers.dart';

/// Actions du livreur : prise de service, acceptation, refus.
///
/// Chaque écriture passe par une RPC vérifiée côté serveur (voir
/// `0046_couriers_and_deliveries.sql`) : ce contrôleur ne décide de rien, il
/// transmet et rapporte l'échec. Un refus serveur — course déjà prise,
/// fenêtre expirée — remonte tel quel dans [state] pour que l'écran affiche
/// le vrai motif plutôt qu'un message inventé ici.
class CourierController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Prise ou fin de service.
  ///
  /// Une course n'est proposée qu'à un livreur dont la position est connue
  /// (`offer_delivery_to_next_courier`). Tant que la géolocalisation réelle
  /// n'est pas branchée (étape 3), on transmet les coordonnées de sa ville :
  /// c'est faux à l'échelle d'une rue, mais exact à celle qui sert
  /// aujourd'hui — classer des livreurs entre Bamako et Sikasso.
  Future<bool> setOnline(bool isOnline) async {
    final courier = ref.read(currentCourierProvider);
    if (courier == null) return false;

    final city = MalianCity.values
        .where((c) => c.label == courier.city)
        .firstOrNull;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(deliveryRepositoryProvider)
          .setOnline(
            courierId: courier.id,
            isOnline: isOnline,
            latitude: isOnline ? city?.coordinates.latitude : null,
            longitude: isOnline ? city?.coordinates.longitude : null,
          );
      // La fiche livreur est portée par `currentUserProvider` : sans ça,
      // l'interrupteur reviendrait à sa position précédente au prochain
      // rebuild.
      ref.invalidate(currentUserProvider);
    });
    return !state.hasError;
  }

  Future<bool> accept(String deliveryId) => _run(
    (repository) => repository.accept(deliveryId),
  );

  Future<bool> decline(String deliveryId) => _run(
    (repository) => repository.decline(deliveryId),
  );

  /// Présente un code scanné. Renvoie le nouveau statut, ou `null` si le
  /// serveur a refusé — le motif reste dans [state] pour que l'écran
  /// l'affiche tel quel plutôt que d'en inventer un.
  Future<DeliveryStatus?> scan({
    required String deliveryId,
    required String code,
  }) async {
    state = const AsyncLoading();
    DeliveryStatus? status;
    state = await AsyncValue.guard(() async {
      status = await ref
          .read(deliveryRepositoryProvider)
          .scan(deliveryId: deliveryId, code: code);
    });
    return state.hasError ? null : status;
  }

  /// Repasse au suivant les courses restées sans réponse. Appelée à
  /// l'ouverture de la liste — c'est ce qui tient lieu de planificateur.
  Future<void> reofferExpired() async {
    await AsyncValue.guard(
      () => ref.read(deliveryRepositoryProvider).reofferExpired(),
    );
  }

  Future<bool> _run(Future<void> Function(DeliveryRepository repository) action) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => action(ref.read(deliveryRepositoryProvider)),
    );
    return !state.hasError;
  }
}

final courierControllerProvider =
    AsyncNotifierProvider<CourierController, void>(CourierController.new);
