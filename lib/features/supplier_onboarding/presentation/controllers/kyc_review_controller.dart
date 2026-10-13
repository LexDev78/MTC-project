import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:mtc_app/features/suppliers/presentation/providers/supplier_providers.dart';

import '../providers/supplier_kyc_providers.dart';

/// Décision du staff sur un dossier de vérification.
///
/// Ne coordonne plus rien : les quatre enregistrements qu'une décision
/// touche (le dossier, la fiche fournisseur, ses produits, la notification)
/// sont écrits ensemble par `review_supplier_kyc` (`0069`). Cette classe ne
/// garde que l'état de chargement et l'invalidation des caches.
class KycReviewController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> startReview({required String kycId}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(supplierKycRepositoryProvider).startReview(kycId: kycId),
    );
    return !state.hasError;
  }

  /// Approuve ou refuse, en un appel.
  ///
  /// Les quatre écritures qu'une décision entraîne — le dossier, la fiche
  /// fournisseur, la visibilité de ses produits, la notification — sont
  /// faites par `review_supplier_kyc` (`0069`) dans une transaction. Cette
  /// classe les enchaînait, et un échec au milieu laissait un dossier
  /// approuvé dont les produits restaient invisibles.
  ///
  /// Les caches locaux sont invalidés ensuite : ces lignes ont changé sans
  /// passer par les sources de données de l'app.
  Future<bool> review({
    required String kycId,
    required String supplierId,
    required bool approve,
    String? reason,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(supplierKycRepositoryProvider)
          .review(kycId: kycId, approve: approve, reason: reason),
    );
    if (state.hasError) return false;

    ref.invalidate(supplierDetailProvider(supplierId));
    ref.invalidate(productDetailProvider);
    return true;
  }
}

final kycReviewControllerProvider =
    AsyncNotifierProvider<KycReviewController, void>(KycReviewController.new);
