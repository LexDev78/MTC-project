import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/promotion.dart';
import '../../domain/entities/promotion_batch.dart';
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

  /// Pose la même remise sur plusieurs produits d'un coup (`0090`).
  ///
  /// C'est le chemin que le fournisseur emprunte quand il pense sa remise
  /// avant de choisir où elle s'applique — « -20 % sur tout le bogolan » —
  /// par opposition à `create`, qui part d'un produit déjà ouvert.
  Future<bool> createBatch({
    required List<String> productIds,
    required PromotionKind kind,
    required int value,
    int minQuantity = 1,
    DateTime? startsAt,
    DateTime? endsAt,
    String? label,
  }) async {
    if (productIds.isEmpty) return false;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(productRepositoryProvider)
          .createPromotionBatch(
            productIds: productIds,
            kind: kind,
            value: value,
            minQuantity: minQuantity,
            startsAt: startsAt,
            endsAt: endsAt,
            label: label,
          ),
    );
    if (!state.hasError) ref.invalidate(myPromotionBatchesProvider);
    return !state.hasError;
  }

  /// Corrige une remise déjà posée, couverture comprise.
  Future<bool> updateBatch({
    required String batchId,
    required List<String> productIds,
    required PromotionKind kind,
    required int value,
    int minQuantity = 1,
    DateTime? startsAt,
    DateTime? endsAt,
    String? label,
  }) async {
    if (productIds.isEmpty) return false;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(productRepositoryProvider)
          .updatePromotionBatch(
            batchId: batchId,
            productIds: productIds,
            kind: kind,
            value: value,
            minQuantity: minQuantity,
            startsAt: startsAt,
            endsAt: endsAt,
            label: label,
          ),
    );
    if (!state.hasError) ref.invalidate(myPromotionBatchesProvider);
    return !state.hasError;
  }

  Future<bool> setBatchActive({
    required String batchId,
    required bool isActive,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(productRepositoryProvider)
          .setPromotionBatchActive(batchId: batchId, isActive: isActive),
    );
    if (!state.hasError) ref.invalidate(myPromotionBatchesProvider);
    return !state.hasError;
  }

  Future<bool> removeBatch(String batchId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(productRepositoryProvider).deletePromotionBatch(batchId),
    );
    if (!state.hasError) ref.invalidate(myPromotionBatchesProvider);
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

/// Les remises du fournisseur, regroupées par lot.
///
/// Un `FutureProvider` invalidé après chaque écriture, et non un flux : ces
/// lignes ne changent que par les gestes du fournisseur lui-même, sur cet
/// écran. Un abonnement temps réel y serait du travail permanent pour un
/// événement qui n'arrive jamais sans lui.
final myPromotionBatchesProvider = FutureProvider<List<PromotionBatch>>((ref) {
  return ref.watch(productRepositoryProvider).fetchMyPromotionBatches();
});
