import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/characteristic_type_providers.dart';

/// Décision du staff sur un type de caractéristique proposé par un
/// fournisseur.
///
/// Ne coordonne plus rien : le statut et la notification à l'auteur sont
/// écrits ensemble par `review_characteristic_type` (`0069`). Les faire en
/// deux appels obligeait à laisser une session insérer des notifications —
/// c'est-à-dire à laisser n'importe quel compte en écrire une pour
/// n'importe qui.
class CharacteristicTypeReviewController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> review({
    required String id,
    required bool approve,
    String? reason,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(characteristicTypeRepositoryProvider)
          .review(id: id, approve: approve, reason: reason),
    );
    return !state.hasError;
  }
}

final characteristicTypeReviewControllerProvider =
    AsyncNotifierProvider<CharacteristicTypeReviewController, void>(
      CharacteristicTypeReviewController.new,
    );
