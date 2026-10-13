import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/promo_code_providers.dart';

/// Création et gestion des codes promo d'un fournisseur.
///
/// Ne vérifie ni la propriété des produits ni la normalisation du code :
/// un trigger pose le fournisseur depuis la session et met le code en
/// majuscules, et un autre refuse un produit qui n'est pas le sien
/// (`0071`). Les redoubler ici donnerait deux règles à maintenir, dont une
/// seule compte.
class PromoCodeController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> create({
    required String code,
    required int percent,
    String? label,
    DateTime? startsAt,
    DateTime? endsAt,
    int? maxUses,
    int maxUsesPerClient = 1,
    int? minOrderFcfa,
    List<String> productIds = const [],
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(promoCodeRepositoryProvider)
          .create(
            code: code,
            percent: percent,
            label: label,
            startsAt: startsAt,
            endsAt: endsAt,
            maxUses: maxUses,
            maxUsesPerClient: maxUsesPerClient,
            minOrderFcfa: minOrderFcfa,
            productIds: productIds,
          ),
    );
    return !state.hasError;
  }

  Future<bool> setActive({required String id, required bool isActive}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(promoCodeRepositoryProvider)
          .setActive(id: id, isActive: isActive),
    );
    return !state.hasError;
  }

  Future<bool> remove(String id) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(promoCodeRepositoryProvider).delete(id),
    );
    return !state.hasError;
  }
}

final promoCodeControllerProvider =
    AsyncNotifierProvider<PromoCodeController, void>(PromoCodeController.new);
