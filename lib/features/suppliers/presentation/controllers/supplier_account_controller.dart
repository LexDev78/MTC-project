import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:mtc_app/core/mock_data/malian_locations.dart';

import '../providers/operating_supplier_providers.dart';
import '../providers/supplier_providers.dart';

/// Drives storefront-profile edits for the operating supplier (see
/// `operatingSupplierIdProvider` — same controller serves both a
/// fournisseur tiers and MTC staff).
class SupplierAccountController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Jette la fiche en cache après une écriture.
  ///
  /// `supplierDetailProvider` est un `FutureProvider` **sans**
  /// `autoDispose` : sa valeur survit à la navigation, et même à une
  /// déconnexion — le `ProviderScope` est posé à la racine de
  /// l'application et n'est jamais démonté.
  ///
  /// Sans cette invalidation, le fournisseur enregistrait, la base prenait
  /// bien la modification, et l'écran continuait d'afficher l'ancienne
  /// valeur jusqu'au prochain démarrage de l'app. Vu de sa place : « mon
  /// profil se réinitialise ». Deux autres endroits le faisaient déjà
  /// (`review_controller`, `kyc_review_controller`) ; celui qui écrit le
  /// plus souvent l'avait oublié.
  void _refreshCachedProfile(String supplierId) {
    ref.invalidate(supplierDetailProvider(supplierId));
  }

  /// Ce que la boutique montre d'elle-même : nom, bannière, description,
  /// téléphones publics, horaires.
  ///
  /// Le nom est le seul champ obligatoire : une boutique sans nom
  /// n'apparaît nulle part dans le catalogue, et le vide est trop facile à
  /// produire d'un effacement malheureux pour qu'on l'accepte en silence.
  Future<bool> updateStorefront({
    required String businessName,
    required String? description,
    required String? bannerUrl,
    required List<String> publicPhoneNumbers,
    required String? openingHoursLabel,
  }) async {
    final supplierId = ref.read(operatingSupplierIdProvider);
    if (supplierId == null) return false;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(supplierRepositoryProvider)
          .updateStorefront(
            supplierId: supplierId,
            businessName: businessName,
            description: description,
            bannerUrl: bannerUrl,
            publicPhoneNumbers: publicPhoneNumbers,
            openingHoursLabel: openingHoursLabel,
          );
    });

    if (!state.hasError) _refreshCachedProfile(supplierId);
    return !state.hasError;
  }

  /// Où la boutique se trouve, et où elle livre.
  Future<bool> updateLocation({
    required String? fullAddress,

    /// Le point de retrait posé sur la carte par le fournisseur. `null`
    /// conserve celui déjà enregistré — on ne l'écrase pas avec un repli
    /// quand il n'y a rien de neuf à mettre.
    required LatLng? pickupPoint,
    required List<String> deliveryZones,
  }) async {
    final supplierId = ref.read(operatingSupplierIdProvider);
    if (supplierId == null) return false;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(supplierRepositoryProvider);
      final supplier = await repository.getById(supplierId);

      // Ordre de préférence : le point qu'on vient de poser, sinon celui déjà
      // enregistré, et en tout dernier recours le centre de la ville.
      //
      // Ce dernier cas n'existe que pour les boutiques créées avant le
      // sélecteur de carte : il est faux de toute façon — toutes les
      // boutiques d'une même ville s'y retrouvent au même endroit — mais
      // écrire `null` empêcherait le fournisseur d'enregistrer quoi que ce
      // soit d'autre tant qu'il n'a pas placé son repère.
      final latitude =
          pickupPoint?.latitude ??
          supplier.addressLatitude ??
          _cityCenter(supplier.city).latitude;
      final longitude =
          pickupPoint?.longitude ??
          supplier.addressLongitude ??
          _cityCenter(supplier.city).longitude;

      await repository.updateLocation(
        supplierId: supplierId,
        fullAddress: fullAddress,
        addressLatitude: latitude,
        addressLongitude: longitude,
        deliveryZones: deliveryZones,
      );
    });

    if (!state.hasError) _refreshCachedProfile(supplierId);
    return !state.hasError;
  }

  Future<bool> setOpen(bool isOpen) async {
    final supplierId = ref.read(operatingSupplierIdProvider);
    if (supplierId == null) return false;

    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(supplierRepositoryProvider)
          .setOpen(supplierId: supplierId, isOpen: isOpen),
    );

    if (!state.hasError) _refreshCachedProfile(supplierId);
    return !state.hasError;
  }
}

final supplierAccountControllerProvider =
    AsyncNotifierProvider<SupplierAccountController, void>(
      SupplierAccountController.new,
    );

/// Centre d'une ville malienne — dernier recours seulement, voir
/// `updateLocation`.
LatLng _cityCenter(String city) {
  return MalianCity.values
      .firstWhere(
        (c) => c.label.toLowerCase() == city.toLowerCase(),
        orElse: () => MalianCity.bamako,
      )
      .coordinates;
}
