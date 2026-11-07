import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/delivery_providers.dart';

/// Décision du staff sur une inscription livreur.
///
/// La validation du motif de refus est côté serveur (`review_courier`), pas
/// ici : c'est la base qui doit refuser un refus non motivé, y compris si la
/// demande vient d'ailleurs que de cet écran.
class CourierReviewController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> review({
    required String courierId,
    required bool approve,
    String? reason,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(deliveryRepositoryProvider)
          .reviewCourier(
            courierId: courierId,
            approve: approve,
            reason: reason,
          ),
    );
    // La file est une requête ponctuelle : sans invalidation, le livreur
    // décidé resterait affiché jusqu'au prochain passage sur l'écran.
    if (!state.hasError) ref.invalidate(pendingCouriersProvider);
    return !state.hasError;
  }
}

final courierReviewControllerProvider =
    AsyncNotifierProvider<CourierReviewController, void>(
      CourierReviewController.new,
    );
