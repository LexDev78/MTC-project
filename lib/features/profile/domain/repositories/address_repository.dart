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

  Future<void> removeAddress({
    required String userId,
    required String addressId,
  });
}
