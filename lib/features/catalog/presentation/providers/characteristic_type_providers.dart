import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/core/di/providers.dart';

import '../../data/datasources/supabase_characteristic_type_datasource.dart';
import '../../data/repositories/supabase_characteristic_type_repository.dart';
import '../../domain/entities/product_characteristic_type.dart';
import '../../domain/repositories/characteristic_type_repository.dart';

final characteristicTypeDatasourceProvider =
    Provider<SupabaseCharacteristicTypeDatasource>((ref) {
      return SupabaseCharacteristicTypeDatasource(
        ref.watch(supabaseClientProvider),
      );
    });

final characteristicTypeRepositoryProvider =
    Provider<CharacteristicTypeRepository>((ref) {
      return SupabaseCharacteristicTypeRepository(
        ref.watch(characteristicTypeDatasourceProvider),
      );
    });

/// Every approved type — feeds the supplier's characteristic picker
/// (`VariantManagerPanel`) and anywhere a type's label is shown.
final approvedCharacteristicTypesProvider =
    StreamProvider<List<ProductCharacteristicType>>((ref) {
      return ref.watch(characteristicTypeRepositoryProvider).watchApprovedTypes();
    });

/// Staff review queue: every pending proposal.
final characteristicTypeQueueProvider =
    StreamProvider<List<ProductCharacteristicType>>((ref) {
      return ref.watch(characteristicTypeRepositoryProvider).watchQueue();
    });
