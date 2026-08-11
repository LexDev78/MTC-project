import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';

import '../providers/favorite_providers.dart';

class FavoriteController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> toggle(String productId) async {
    final userId = ref.read(currentUserProvider).valueOrNull?.id;
    if (userId == null) return;

    final repository = ref.read(favoriteRepositoryProvider);
    final isFavorite = ref.read(isFavoriteProvider(productId));

    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      return isFavorite
          ? repository.removeFavorite(userId: userId, productId: productId)
          : repository.addFavorite(userId: userId, productId: productId);
    });
  }
}

final favoriteControllerProvider =
    AsyncNotifierProvider<FavoriteController, void>(FavoriteController.new);
