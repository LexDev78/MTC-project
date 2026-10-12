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

  /// Submits the whole editable storefront form at once — `addressLatitude`/
  /// `addressLongitude` are derived from the supplier's existing `city` via
  /// `MalianCity` (same lookup `ManageAddressesScreen` uses for a client
  /// address) rather than typed in, so the form never asks for raw
  /// coordinates.
  Future<bool> updateStorefront({
    required String? description,
    required String? bannerUrl,
    required String? fullAddress,

    /// Le point de retrait posé sur la carte par le fournisseur. `null`
    /// conserve celui déjà enregistré — on ne l'écrase pas avec un repli
    /// quand il n'y a rien de neuf à mettre.
    required LatLng? pickupPoint,
    required List<String> publicPhoneNumbers,
    required List<String> deliveryZones,
    required String? openingHoursLabel,
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

      await repository.updateStorefront(
        supplierId: supplierId,
        description: description,
        bannerUrl: bannerUrl,
        fullAddress: fullAddress,
        addressLatitude: latitude,
        addressLongitude: longitude,
        publicPhoneNumbers: publicPhoneNumbers,
        deliveryZones: deliveryZones,
        openingHoursLabel: openingHoursLabel,
      );
    });

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

    return !state.hasError;
  }
}

final supplierAccountControllerProvider =
    AsyncNotifierProvider<SupplierAccountController, void>(
      SupplierAccountController.new,
    );

/// Centre d'une ville malienne — dernier recours seulement, voir
/// `updateStorefront`.
LatLng _cityCenter(String city) {
  return MalianCity.values
      .firstWhere(
        (c) => c.label.toLowerCase() == city.toLowerCase(),
        orElse: () => MalianCity.bamako,
      )
      .coordinates;
}
