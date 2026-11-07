import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/features/auth/domain/entities/app_user.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';

import '../../data/datasources/supabase_delivery_datasource.dart';
import '../../data/repositories/supabase_delivery_repository.dart';
import '../../domain/entities/courier_delivery.dart';
import '../../domain/entities/courier_dossier.dart';
import '../../domain/repositories/delivery_repository.dart';

final deliveryDatasourceProvider = Provider<SupabaseDeliveryDatasource>((ref) {
  return SupabaseDeliveryDatasource(ref.watch(supabaseClientProvider));
});

final deliveryRepositoryProvider = Provider<DeliveryRepository>((ref) {
  return SupabaseDeliveryRepository(ref.watch(deliveryDatasourceProvider));
});

/// Le livreur connecté, ou `null` si ce n'en est pas un.
final currentCourierProvider = Provider<CourierUser?>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  return user is CourierUser ? user : null;
});

/// Courses du livreur connecté, poussées en temps réel.
final courierDeliveriesProvider = StreamProvider<List<CourierDelivery>>((ref) {
  final courier = ref.watch(currentCourierProvider);
  if (courier == null) return Stream.value(const []);
  return ref.watch(deliveryRepositoryProvider).watchForCourier(courier.id);
});

/// La course en cours, s'il y en a une : un livreur n'en prend qu'une à la
/// fois (`offer_delivery_to_next_courier` ne propose rien à qui en a déjà
/// une), donc c'est bien un singleton et pas une liste.
final activeDeliveryProvider = Provider<CourierDelivery?>((ref) {
  final deliveries = ref.watch(courierDeliveriesProvider).valueOrNull ?? const [];
  for (final delivery in deliveries) {
    if (delivery.status == DeliveryStatus.accepted ||
        delivery.status == DeliveryStatus.pickedUp) {
      return delivery;
    }
  }
  return null;
});

/// Courses proposées, en attente d'une réponse.
final offeredDeliveriesProvider = Provider<List<CourierDelivery>>((ref) {
  final deliveries = ref.watch(courierDeliveriesProvider).valueOrNull ?? const [];
  return [
    for (final d in deliveries)
      if (d.status == DeliveryStatus.offered) d,
  ];
});

/// Le dossier du livreur connecté : ses pièces, son moyen de transport, et
/// l'état du dépôt (`0105`).
///
/// `autoDispose` : il n'intéresse que l'écran du dossier, et il doit être
/// relu à chaque ouverture — une pièce ajoutée depuis un autre appareil, ou
/// un refus prononcé entre-temps, changent ce qu'il faut afficher.
final courierDossierProvider = FutureProvider.autoDispose<CourierDossier>((
  ref,
) async {
  final courier = ref.watch(currentCourierProvider);
  if (courier == null) {
    throw StateError('Aucun compte livreur en session.');
  }
  return ref.watch(deliveryRepositoryProvider).fetchMyDossier(courier.id);
});

/// Inscriptions livreurs en attente, pour le staff.
///
/// Une simple requête plutôt qu'un flux : la file bouge au rythme des
/// inscriptions, pas des secondes, et l'agent qui vient de décider la
/// rafraîchit lui-même (voir `CourierReviewController`).
final pendingCouriersProvider = FutureProvider<List<PendingCourier>>((ref) {
  return ref.watch(deliveryRepositoryProvider).fetchPendingCouriers();
});

typedef DeliveryCodeRef = ({String deliveryId, DeliveryCodeKind kind});

/// Le code à présenter, ou `null` s'il est déjà consommé — ou si l'appelant
/// n'avait pas à le voir, ce que la base ne distingue pas volontairement.
///
/// `autoDispose` : un code de retrait ou de remise n'a pas à rester en
/// mémoire une fois l'écran quitté — ni à être resservi, périmé, à l'écran
/// suivant ou au compte suivant sur le même appareil.
final deliveryCodeProvider = FutureProvider.autoDispose
    .family<String?, DeliveryCodeRef>((ref, params) {
  return ref
      .watch(deliveryRepositoryProvider)
      .fetchCode(deliveryId: params.deliveryId, kind: params.kind);
});

/// La course d'un groupe fournisseur, pour les écrans qui partent de la
/// commande (client et fournisseur) et non de la course.
///
/// Un flux, et `autoDispose`. C'était une lecture unique, gardée pour toute
/// la vie de l'app : constaté le 17/10/2026, la commande ouverte avant le
/// retrait gardait le statut d'alors, et le client ne voyait jamais son QR
/// de remise — pas même en se reconnectant, puisque la valeur lue sous le
/// compte précédent survivait à la déconnexion. Désormais le QR apparaît
/// au moment où le livreur scanne le retrait, et disparaît à la remise.
final deliveryForGroupProvider = StreamProvider.autoDispose
    .family<({String id, DeliveryStatus status})?, String>((
      ref,
      supplierGroupId,
    ) {
      return ref.watch(deliveryRepositoryProvider).watchByGroup(supplierGroupId);
    });
