import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/features/auth/domain/entities/app_user.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';

import '../../data/datasources/supabase_address_datasource.dart';
import '../../data/repositories/supabase_address_repository.dart';
import '../../domain/entities/address.dart';
import '../../domain/repositories/address_repository.dart';

final addressDatasourceProvider = Provider<SupabaseAddressDatasource>((ref) {
  return SupabaseAddressDatasource(ref.watch(supabaseClientProvider));
});

final addressRepositoryProvider = Provider<AddressRepository>((ref) {
  return SupabaseAddressRepository(ref.watch(addressDatasourceProvider));
});

final addressesProvider = StreamProvider<List<Address>>((ref) {
  // `.select`: see the same note in cart_providers.dart — avoids
  // rebuilding (and losing the in-flight subscription) on a re-emitted
  // but id-equal AppUser.
  final userId = ref.watch(currentUserProvider.select((u) => u.valueOrNull?.id));
  if (userId == null) return Stream.value(const <Address>[]);
  return ref.watch(addressRepositoryProvider).watchAddresses(userId);
});

/// L'identifiant de l'adresse que le client a choisie par défaut (`0117`),
/// ou `null` s'il n'en a pas choisi.
final chosenDefaultAddressIdProvider = Provider<String?>((ref) {
  return ref.watch(
    currentUserProvider.select(
      (u) => switch (u.valueOrNull) {
        ClientUser(:final defaultAddressId) => defaultAddressId,
        _ => null,
      },
    ),
  );
});

/// L'adresse que le paiement propose : celle que le client a choisie par
/// défaut, sinon la première enregistrée.
final defaultAddressProvider = Provider<Address?>((ref) {
  final addresses =
      ref.watch(addressesProvider).valueOrNull ?? const <Address>[];
  final choisie = ref.watch(chosenDefaultAddressIdProvider);
  return addresses.firstWhereOrNull((a) => a.id == choisie) ??
      addresses.firstOrNull;
});
