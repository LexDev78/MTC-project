import '../entities/courier_delivery.dart';
import '../entities/courier_dossier.dart';
import '../entities/courier_history.dart';

/// Ce dont l'app livreur a besoin, sans rien savoir de Supabase.
abstract class DeliveryRepository {
  /// Courses proposées à ce livreur ou déjà acceptées par lui, poussées en
  /// temps réel.
  Stream<List<CourierDelivery>> watchForCourier(String courierId);

  /// Prend la course. Échoue si elle n'est plus proposée à ce livreur ou si
  /// la fenêtre de réponse est passée — la vérification est côté serveur
  /// (`accept_delivery`), jamais ici.
  Future<void> accept(String deliveryId);

  Future<void> decline(String deliveryId);

  /// Repasse au livreur suivant les courses laissées sans réponse.
  Future<void> reofferExpired();

  /// Accuse une étape en présentant le code scanné. Renvoie le nouveau
  /// statut. Échoue si la course n'est pas la sienne, si elle n'attend aucun
  /// scan, ou si le code est faux ou déjà utilisé — le serveur ne dit pas
  /// lequel des trois.
  Future<DeliveryStatus> scan({
    required String deliveryId,
    required String code,
  });

  /// Le code à montrer, s'il y en a un pour cet utilisateur et qu'il n'est
  /// pas encore consommé.
  Future<String?> fetchCode({
    required String deliveryId,
    required DeliveryCodeKind kind,
  });

  /// Course d'un groupe fournisseur, vue depuis la commande.
  Future<({String id, DeliveryStatus status})?> fetchByGroup(
    String supplierGroupId,
  );

  /// Transmet la position courante du livreur en service.
  Future<void> pushPosition({
    required double latitude,
    required double longitude,
  });

  /// Livreurs en attente de validation (staff).
  Future<List<PendingCourier>> fetchPendingCouriers();

  /// Valide ou refuse une inscription. Un refus doit être motivé — la règle
  /// est posée côté serveur (`review_courier`), pas ici. Une validation
  /// réclame en plus un dossier déposé : on ne valide pas un livreur dont on
  /// n'a vu aucune pièce (`0105`).
  Future<void> reviewCourier({
    required String courierId,
    required bool approve,
    String? reason,
  });

  /// Le dossier du livreur en session : ses pièces, son moyen de transport,
  /// et la date de dépôt s'il l'a déposé.
  Future<CourierDossier> fetchMyDossier(String courierId);

  /// Enregistre une pièce **déjà envoyée** dans le bucket privé. Remplace
  /// celle du même type, le cas échéant.
  Future<void> saveDocument({
    required String courierId,
    required CourierDocumentType type,
    required String filePath,
  });

  Future<void> removeDocument({required String documentId});

  /// Dépose le dossier pour examen. Échoue si une pièce exigée par le moyen
  /// de transport manque, ou si le dossier est déjà entre les mains du staff.
  Future<void> submitDossier({
    required CourierVehicleType vehicleType,
    String? vehicleLabel,
  });

  /// Courses terminées, sans les identités du client ni du fournisseur.
  Future<List<CourierHistoryEntry>> fetchHistory({int limit, int offset});

  /// Cumul d'activité : courses livrées, frais perçus, note moyenne.
  Future<CourierStats> fetchStats();

  /// Notes reçues, sans leurs auteurs.
  Future<List<CourierRating>> fetchMyRatings({int limit, int offset});

  /// Note une course livrée. Le rôle de l'appelant (client ou fournisseur)
  /// est déduit côté serveur, pas transmis d'ici.
  Future<void> rateCourier({
    required String deliveryId,
    required int stars,
    String? comment,
  });

  /// La note déjà donnée par l'utilisateur courant sur cette course.
  Future<MyDeliveryRating?> fetchMyRatingForDelivery(String deliveryId);

  Future<void> setOnline({
    required String courierId,
    required bool isOnline,
    double? latitude,
    double? longitude,
  });
}
