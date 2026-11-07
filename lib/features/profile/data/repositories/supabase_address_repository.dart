import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mtc_app/core/error/exceptions.dart';

import '../../domain/entities/address.dart';
import '../../domain/repositories/address_repository.dart';
import '../datasources/supabase_address_datasource.dart';

class SupabaseAddressRepository implements AddressRepository {
  SupabaseAddressRepository(this._datasource);

  final SupabaseAddressDatasource _datasource;

  @override
  Stream<List<Address>> watchAddresses(String userId) {
    return _datasource
        .watchForUser(userId)
        .map((rows) => rows.map(Address.fromJson).toList());
  }

  @override
  Future<Address> addAddress({
    required String userId,
    required String label,
    required String city,
    required String details,
    required double latitude,
    required double longitude,
  }) async {
    final row = await _datasource.add({
      'user_id': userId,
      'label': label,
      'city': city,
      'details': details,
      'latitude': latitude,
      'longitude': longitude,
    });
    return Address.fromJson(row);
  }

  @override
  Future<void> updatePosition({
    required String addressId,
    required double latitude,
    required double longitude,
  }) {
    return _datasource.updatePosition(
      addressId: addressId,
      latitude: latitude,
      longitude: longitude,
    );
  }

  @override
  Future<void> removeAddress({
    required String userId,
    required String addressId,
  }) {
    return _datasource.remove(addressId);
  }

  @override
  Future<void> setDefaultAddress(String? addressId) async {
    try {
      await _datasource.setDefault(addressId);
    } on PostgrestException catch (e) {
      // « Adresse introuvable. » : rédigé pour l'utilisateur côté serveur.
      throw ValidationException(e.message);
    }
  }
}
