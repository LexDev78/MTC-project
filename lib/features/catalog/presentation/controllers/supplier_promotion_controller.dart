import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/promotion.dart';
import '../providers/catalog_providers.dart';

/// Les promotions d'un fournisseur sur ses propres produits.
///
/// Ne vérifie pas la propriété du produit : un trigger la vérifie à
/// l'écriture et refuse le produit d'un autre
/// (`stamp_promotion_supplier`, `0062`). La redoubler ici donnerait deux
/// règles à maintenir, dont une seule compte.
class SupplierPromotionController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> create({
    required String productId,
    required PromotionKind kind,
    required int value,
    int minQuantity = 1,
    DateTime? startsAt,
    DateTime? endsAt,
    String? label,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(productRepositoryProvider)
          .createPromotion(
            productId: productId,
            kind: kind,
            value: value,
            minQuantity: minQuantity,
            startsAt: startsAt,
            endsAt: endsAt,
            label: label,
          ),
    );
    return !state.hasError;
  }

  Future<bool> setActive({required String id, required bool isActive}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(productRepositoryProvider)
          .setPromotionActive(id: id, isActive: isActive),
    );
    return !state.hasError;
  }

  Future<bool> remove(String id) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(productRepositoryProvider).deletePromotion(id),
    );
    return !state.hasError;
  }
}

final supplierPromotionControllerProvider =
    AsyncNotifierProvider<SupplierPromotionController, void>(
      SupplierPromotionController.new,
    );
