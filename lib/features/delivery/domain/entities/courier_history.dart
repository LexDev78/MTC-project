import 'package:freezed_annotation/freezed_annotation.dart';

import 'courier_delivery.dart';

part 'courier_history.freezed.dart';

/// De quel côté d'une course vient une note.
///
/// Les deux ne jugent pas la même chose : le fournisseur a vu le retrait, le
/// client a vu la remise. Le livreur voit donc l'origine de chaque note,
/// mais jamais qui l'a écrite (`fetch_my_courier_ratings`, `0059`).
enum CourierRaterRole {
  client,
  supplier;

  static CourierRaterRole fromRow(String value) =>
      value == 'supplier' ? CourierRaterRole.supplier : CourierRaterRole.client;

  String get label => switch (this) {
    CourierRaterRole.client => 'Client',
    CourierRaterRole.supplier => 'Fournisseur',
  };
}

/// Une course terminée, telle que le livreur la retrouve dans son
/// historique.
///
/// Volontairement amnésique : ni nom de client, ni téléphone, ni adresse de
/// livraison, ni nom de fournisseur. Le livreur a eu ces informations
/// pendant la course, il n'a pas à les conserver après. Ce qui reste suffit
/// à reconnaître un trajet et à vérifier ce qu'il a gagné.
///
/// Ce n'est pas un filtre d'affichage : la lecture elle-même
/// (`fetch_courier_delivery_history`, `0060`) ne remonte pas jusqu'à ces
/// champs.
@freezed
class CourierHistoryEntry with _$CourierHistoryEntry {
  const factory CourierHistoryEntry({
    required String deliveryId,

    /// Référence courte, citable au support sans lire 36 caractères.
    required String reference,
    required DeliveryStatus status,
    required String pickupCity,
    required String dropoffCity,
    required int itemCount,
    required int deliveryFeeFcfa,
    DateTime? acceptedAt,
    DateTime? pickedUpAt,
    DateTime? deliveredAt,

    /// Notes reçues pour cette course, côté par côté — `null` quand ce côté
    /// n'a pas noté.
    int? clientStars,
    int? supplierStars,
  }) = _CourierHistoryEntry;
}

extension CourierHistoryEntryX on CourierHistoryEntry {
  /// La date qui situe la course : celle de la remise, ou à défaut celle de
  /// la prise en charge (une course annulée n'a pas été remise).
  DateTime? get happenedAt => deliveredAt ?? acceptedAt;

  bool get hasRating => clientStars != null || supplierStars != null;
}

/// Le cumul d'activité du livreur, en une lecture (`fetch_courier_stats`).
@freezed
class CourierStats with _$CourierStats {
  const factory CourierStats({
    required int deliveredCount,
    required int deliveredFeesFcfa,
    required int monthDeliveredCount,
    required int monthFeesFcfa,
    required int cancelledCount,
    required double ratingAverage,
    required int ratingCount,
  }) = _CourierStats;
}

/// Une note reçue, telle que le livreur la lit : les étoiles, le mot laissé,
/// le côté d'où ça vient. Pas d'auteur — la colonne n'est pas renvoyée.
@freezed
class CourierRating with _$CourierRating {
  const factory CourierRating({
    required int stars,
    required CourierRaterRole raterRole,
    required DateTime createdAt,
    required String deliveryId,
    String? comment,
  }) = _CourierRating;
}

/// La note que l'utilisateur courant a déjà donnée sur une course, pour que
/// l'écran affiche « vous avez mis 4 étoiles » au lieu d'un formulaire
/// vierge qui laisserait croire que rien n'a été envoyé.
@freezed
class MyDeliveryRating with _$MyDeliveryRating {
  const factory MyDeliveryRating({required int stars, String? comment}) =
      _MyDeliveryRating;
}
