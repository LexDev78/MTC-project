import '../entities/address.dart';

abstract interface class AddressRepository {
  Stream<List<Address>> watchAddresses(String userId);

  Future<Address> addAddress({
    required String userId,
    required String label,
    required String city,
    required String details,
    required double latitude,
    required double longitude,
  });

  /// Repose le point d'une adresse sur la carte.
  ///
  /// Le seul chemin de correction qui existait était de supprimer puis
  /// recréer — ce que personne ne fait. Les adresses créées avant le
  /// sélecteur portent donc toujours les coordonnées du centre de leur
  /// ville, et c'est là que les livreurs se rendent (`0079`).
  Future<void> updatePosition({
    required String addressId,
    required double latitude,
    required double longitude,
  });

  Future<void> removeAddress({
    required String userId,
    required String addressId,
  });
}
