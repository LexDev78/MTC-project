import 'package:freezed_annotation/freezed_annotation.dart';

part 'courier_dossier.freezed.dart';

/// Le moyen de transport du livreur, en valeurs closes (`0105`).
///
/// Il remplace l'usage qu'on faisait du texte libre `vehicleLabel` pour
/// deviner la nature du véhicule. Le libellé reste — il dit l'objet
/// (« Djakarta rouge »), que le client reconnaît à sa porte ; le type dit la
/// règle, et c'est la règle qui décide des pièces exigées.
enum CourierVehicleType {
  @JsonValue('on_foot')
  onFoot,
  bicycle,
  motorcycle,
  tricycle,
  car;

  String get label => switch (this) {
    CourierVehicleType.onFoot => 'À pied',
    CourierVehicleType.bicycle => 'Vélo',
    CourierVehicleType.motorcycle => 'Moto',
    CourierVehicleType.tricycle => 'Tricycle',
    CourierVehicleType.car => 'Voiture',
  };

  /// La valeur telle que la base la nomme — `submit_courier_documents` prend
  /// ce texte, pas le libellé affiché.
  String get wireValue => switch (this) {
    CourierVehicleType.onFoot => 'on_foot',
    CourierVehicleType.bicycle => 'bicycle',
    CourierVehicleType.motorcycle => 'motorcycle',
    CourierVehicleType.tricycle => 'tricycle',
    CourierVehicleType.car => 'car',
  };

  /// Vrai pour les véhicules qui réclament un permis et une carte grise.
  bool get isMotorised => switch (this) {
    CourierVehicleType.motorcycle ||
    CourierVehicleType.tricycle ||
    CourierVehicleType.car => true,
    CourierVehicleType.onFoot || CourierVehicleType.bicycle => false,
  };

  /// Les pièces sans lesquelles le serveur refusera le dépôt.
  ///
  /// **Cette liste double celle de `courier_required_documents()` (`0105`)**,
  /// et c'est voulu : l'écran doit afficher les mêmes cases que celles que le
  /// serveur contrôlera, sinon le livreur remplit un formulaire complet pour
  /// se faire refuser. Un test compare les deux listes pour les cinq moyens
  /// de transport — c'est lui qui empêche les deux copies de diverger
  /// (`courier_dossier_test.dart`).
  List<CourierDocumentType> get requiredDocuments => [
    CourierDocumentType.nationalIdFront,
    CourierDocumentType.nationalIdBack,
    if (isMotorised) ...[
      CourierDocumentType.drivingLicence,
      CourierDocumentType.vehicleRegistration,
    ],
  ];
}

/// Une pièce du dossier livreur.
enum CourierDocumentType {
  /// Carte NINA, recto.
  @JsonValue('national_id_front')
  nationalIdFront,

  /// Carte NINA, verso.
  @JsonValue('national_id_back')
  nationalIdBack,

  @JsonValue('driving_licence')
  drivingLicence,

  /// Carte grise.
  @JsonValue('vehicle_registration')
  vehicleRegistration,

  insurance;

  String get label => switch (this) {
    CourierDocumentType.nationalIdFront => 'Pièce d\'identité — recto',
    CourierDocumentType.nationalIdBack => 'Pièce d\'identité — verso',
    CourierDocumentType.drivingLicence => 'Permis de conduire',
    CourierDocumentType.vehicleRegistration => 'Carte grise',
    CourierDocumentType.insurance => 'Attestation d\'assurance',
  };

  String get wireValue => switch (this) {
    CourierDocumentType.nationalIdFront => 'national_id_front',
    CourierDocumentType.nationalIdBack => 'national_id_back',
    CourierDocumentType.drivingLicence => 'driving_licence',
    CourierDocumentType.vehicleRegistration => 'vehicle_registration',
    CourierDocumentType.insurance => 'insurance',
  };

  static CourierDocumentType fromWire(String value) => switch (value) {
    'national_id_front' => CourierDocumentType.nationalIdFront,
    'national_id_back' => CourierDocumentType.nationalIdBack,
    'driving_licence' => CourierDocumentType.drivingLicence,
    'vehicle_registration' => CourierDocumentType.vehicleRegistration,
    'insurance' => CourierDocumentType.insurance,
    _ => throw ArgumentError('Type de pièce inconnu : $value'),
  };
}

/// Un fichier déposé, dans le bucket privé `courier-documents`.
///
/// [filePath] est un chemin **dans le bucket**, jamais un chemin local du
/// téléphone : le fichier est envoyé avant d'être enregistré (voir
/// `CourierDossierController.addDocument`).
@freezed
abstract class CourierDocument with _$CourierDocument {
  const factory CourierDocument({
    required String id,
    required CourierDocumentType type,
    required String filePath,
    required DateTime uploadedAt,
  }) = _CourierDocument;
}

/// L'état du dossier, tel que le livreur le voit.
@freezed
abstract class CourierDossier with _$CourierDossier {
  const factory CourierDossier({
    required List<CourierDocument> documents,
    CourierVehicleType? vehicleType,
    String? vehicleLabel,

    /// Nul tant que les pièces ne sont pas déposées. C'est cette date, et
    /// non le statut, qui distingue « je n'ai rien envoyé » de « MTC
    /// examine mon dossier » : un refus la remet à nul pour rendre la main
    /// au livreur (`review_courier`, `0105`).
    DateTime? submittedAt,
    String? rejectionReason,
  }) = _CourierDossier;
}

extension CourierDossierX on CourierDossier {
  bool get isSubmitted => submittedAt != null;

  CourierDocument? documentOf(CourierDocumentType type) {
    for (final document in documents) {
      if (document.type == type) return document;
    }
    return null;
  }

  /// Les pièces encore attendues pour le moyen de transport choisi. Vide =
  /// le dépôt passera.
  List<CourierDocumentType> missingFor(CourierVehicleType vehicle) => [
    for (final type in vehicle.requiredDocuments)
      if (documentOf(type) == null) type,
  ];
}
