import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      final coordinates = MalianCity.values
          .firstWhere(
            (c) => c.label.toLowerCase() == supplier.city.toLowerCase(),
            orElse: () => MalianCity.bamako,
          )
          .coordinates;

      await repository.updateStorefront(
        supplierId: supplierId,
        description: description,
        bannerUrl: bannerUrl,
        fullAddress: fullAddress,
        addressLatitude: coordinates.latitude,
        addressLongitude: coordinates.longitude,
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
