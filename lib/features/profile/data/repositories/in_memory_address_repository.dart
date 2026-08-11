import 'package:mtc_app/core/utils/id_generator.dart';

import '../../domain/entities/address.dart';
import '../../domain/repositories/address_repository.dart';
import '../datasources/in_memory_address_datasource.dart';

class InMemoryAddressRepository implements AddressRepository {
  InMemoryAddressRepository(this._datasource);

  final InMemoryAddressDatasource _datasource;

  @override
  Stream<List<Address>> watchAddresses(String userId) {
    return _datasource.watchAll().map(
      (all) => all.where((a) => a.userId == userId).toList(),
    );
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
    final address = Address(
      id: IdGenerator.next(),
      userId: userId,
      label: label,
      city: city,
      details: details,
      latitude: latitude,
      longitude: longitude,
    );
    _datasource.add(address);
    return address;
  }

  @override
  Future<void> removeAddress({
    required String userId,
    required String addressId,
  }) async {
    _datasource.remove(addressId);
  }
}
