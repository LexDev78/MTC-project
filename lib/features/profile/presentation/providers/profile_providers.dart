import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';

import '../../data/datasources/in_memory_address_datasource.dart';
import '../../data/repositories/in_memory_address_repository.dart';
import '../../domain/entities/address.dart';
import '../../domain/repositories/address_repository.dart';

final addressDatasourceProvider = Provider<InMemoryAddressDatasource>((ref) {
  return InMemoryAddressDatasource();
});

final addressRepositoryProvider = Provider<AddressRepository>((ref) {
  return InMemoryAddressRepository(ref.watch(addressDatasourceProvider));
});

final addressesProvider = StreamProvider<List<Address>>((ref) {
  final userId = ref.watch(currentUserProvider).valueOrNull?.id;
  if (userId == null) return Stream.value(const <Address>[]);
  return ref.watch(addressRepositoryProvider).watchAddresses(userId);
});

/// The address used as checkout/tracking destination by default — simply
/// the first one on file for this pass (no explicit "default" flag yet).
final defaultAddressProvider = Provider<Address?>((ref) {
  final addresses =
      ref.watch(addressesProvider).valueOrNull ?? const <Address>[];
  return addresses.isEmpty ? null : addresses.first;
});
