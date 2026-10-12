import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:latlong2/latlong.dart';

part 'courier_delivery.freezed.dart';

/// Où en est une course.
///
/// `offered` couvre deux situations volontairement confondues : proposée à
/// un livreur précis, ou en attente de quelqu'un à qui la proposer (aucun
/// livreur en ligne à proximité). Côté base c'est le même état, seul
/// `offered_to_courier_id` les distingue — un livreur ne voit de toute façon
/// que les courses qui lui sont proposées à lui.
enum DeliveryStatus {
  offered,
  accepted,
  pickedUp,
  delivered,
  cancelled;

  static DeliveryStatus fromRow(String value) => switch (value) {
    'offered' => DeliveryStatus.offered,
    'accepted' => DeliveryStatus.accepted,
    'picked_up' => DeliveryStatus.pickedUp,
    'delivered' => DeliveryStatus.delivered,
    _ => DeliveryStatus.cancelled,
  };

  String get label => switch (this) {
    DeliveryStatus.offered => 'Proposée',
    DeliveryStatus.accepted => 'À récupérer',
    DeliveryStatus.pickedUp => 'En cours de livraison',
    DeliveryStatus.delivered => 'Livrée',
    DeliveryStatus.cancelled => 'Annulée',
  };
}

/// Laquelle des deux étapes un code accuse.
enum DeliveryCodeKind {
  pickup('pickup'),
  delivery('delivery');

  const DeliveryCodeKind(this.wireName);

  final String wireName;
}

@freezed
class DeliveryItem with _$DeliveryItem {
  const factory DeliveryItem({
    required String productName,
    required int quantity,
    String? variantName,
  }) = _DeliveryItem;
}

/// Tout ce qu'un livreur doit avoir sous les yeux pour une course : la
/// marchandise, où la retirer, où la remettre, et qui appeler des deux côtés.
///
/// Assemblée à la main depuis une requête imbriquée (course → commande →
/// groupe fournisseur → fournisseur + lignes) plutôt que désérialisée : les
/// champs viennent de quatre tables et sont ici remis à plat dans l'ordre où
/// le livreur s'en sert, pas dans celui où la base les range.
@freezed
class CourierDelivery with _$CourierDelivery {
  const factory CourierDelivery({
    required String id,
    required String orderId,
    required String supplierGroupId,
    required DeliveryStatus status,

    /// Fin de la fenêtre de réponse quand la course est proposée — passé ce
    /// délai elle part au livreur suivant.
    DateTime? offerExpiresAt,

    // ---- retrait ----------------------------------------------------------
    required String supplierName,
    String? supplierAddress,
    required String supplierCity,
    double? supplierLatitude,
    double? supplierLongitude,
    @Default([]) List<String> supplierPhones,

    // ---- remise -----------------------------------------------------------
    required String clientName,
    required String clientPhone,
    String? clientAlternatePhone,
    required String deliveryAddressLabel,
    required String deliveryCity,

    /// Indications libres saisies par le client (étage, repère, portail…).
    required String deliveryDetails,
    required double deliveryLatitude,
    required double deliveryLongitude,

    // ---- marchandise et argent --------------------------------------------
    @Default([]) List<DeliveryItem> items,
    required int deliveryFeeFcfa,
    required int subtotalFcfa,

    /// Paiement à la livraison : le livreur encaisse. Le distinguer n'est pas
    /// cosmétique — c'est la différence entre remettre un colis et repartir
    /// avec de l'argent.
    required bool collectOnDelivery,
  }) = _CourierDelivery;
}

/// L'étape en cours d'une course : où le livreur doit aller **maintenant**.
///
/// Avant le retrait c'est le fournisseur, après c'est le client. Cette
/// distinction porte tout le reste — la carte, l'itinéraire, le code à
/// scanner — et la déduire du statut en plusieurs endroits finirait par
/// produire des désaccords entre eux.
typedef DeliveryLeg = ({LatLng target, bool isPickup});

extension CourierDeliveryNavigationX on CourierDelivery {
  /// `null` quand il n'y a nulle part où aller : course seulement proposée,
  /// déjà livrée, ou annulée.
  DeliveryLeg? get currentLeg {
    switch (status) {
      case DeliveryStatus.accepted:
        final latitude = supplierLatitude;
        final longitude = supplierLongitude;
        // Un fournisseur sans coordonnées ne peut plus arriver depuis `0050`,
        // mais une course ancienne peut en porter.
        if (latitude == null || longitude == null) return null;
        return (target: LatLng(latitude, longitude), isPickup: true);
      case DeliveryStatus.pickedUp:
        return (
          target: LatLng(deliveryLatitude, deliveryLongitude),
          isPickup: false,
        );
      case DeliveryStatus.offered:
      case DeliveryStatus.delivered:
      case DeliveryStatus.cancelled:
        return null;
    }
  }
}

/// Un livreur en attente de validation, tel que le staff le voit.
///
/// Volontairement pauvre : à ce stade il n'y a pas de dossier à examiner,
/// seulement une identité et une ville. Le jour où des pièces seront
/// demandées, c'est ici qu'elles viendront — pas dans `CourierDelivery`,
/// qui décrit une course et non une personne.
@freezed
class PendingCourier with _$PendingCourier {
  const factory PendingCourier({
    required String id,
    required String displayName,
    required String phoneNumber,
    required String city,
    String? vehicleLabel,
    required DateTime createdAt,
  }) = _PendingCourier;
}
