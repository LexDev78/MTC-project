import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/features/suppliers/presentation/providers/operating_supplier_providers.dart';

import '../../data/datasources/supabase_promo_code_datasource.dart';
import '../../data/repositories/supabase_promo_code_repository.dart';
import '../../domain/entities/promo_code.dart';
import '../../domain/repositories/promo_code_repository.dart';

final promoCodeDatasourceProvider = Provider<SupabasePromoCodeDatasource>((ref) {
  return SupabasePromoCodeDatasource(ref.watch(supabaseClientProvider));
});

final promoCodeRepositoryProvider = Provider<PromoCodeRepository>((ref) {
  return SupabasePromoCodeRepository(ref.watch(promoCodeDatasourceProvider));
});

/// Les codes du fournisseur connecté.
///
/// Dépend du fournisseur en activité : sans cela, le résultat du compte
/// précédent survivrait à une déconnexion — ce qui est arrivé aux écrans
/// livreur, et vaut aussi pour des codes promo.
final myPromoCodesProvider = StreamProvider.autoDispose<List<PromoCode>>((ref) {
  ref.watch(operatingSupplierIdProvider);
  return ref.watch(promoCodeRepositoryProvider).watchMine();
});

/// Les codes appliqués sur une commande, par groupe fournisseur.
///
/// Lecture ponctuelle : une commande passée ne change plus de code.
final orderPromoCodesProvider = FutureProvider.autoDispose
    .family<Map<String, ({String code, int discountFcfa})>, String>((
      ref,
      orderId,
    ) {
      return ref.watch(promoCodeRepositoryProvider).fetchForOrder(orderId);
    });
