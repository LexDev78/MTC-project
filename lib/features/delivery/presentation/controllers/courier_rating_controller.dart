import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/courier_history_providers.dart';
import '../providers/delivery_providers.dart';

/// Dépôt d'une note sur une course livrée, par le client ou le fournisseur.
///
/// Aucune règle n'est vérifiée ici : qui a le droit de noter, à partir de
/// quand, et de quel côté vient la note sont décidés par `rate_courier`
/// (`0059`). Les redoubler dans l'app donnerait deux vérités à maintenir,
/// dont une seule compte.
class CourierRatingController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> submit({
    required String deliveryId,
    required int stars,
    String? comment,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(deliveryRepositoryProvider)
          .rateCourier(deliveryId: deliveryId, stars: stars, comment: comment),
    );
    if (state.hasError) return false;

    // La note déjà donnée est lue ponctuellement : sans invalidation,
    // l'écran reproposerait un formulaire vierge juste après l'envoi.
    ref.invalidate(myDeliveryRatingProvider(deliveryId));
    return true;
  }
}

final courierRatingControllerProvider =
    AsyncNotifierProvider<CourierRatingController, void>(
      CourierRatingController.new,
    );
