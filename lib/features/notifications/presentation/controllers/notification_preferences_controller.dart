import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';

import '../../domain/entities/notification_preferences.dart';
import '../providers/notification_providers.dart';

/// Les réglages de notification du client en session, et leur
/// enregistrement.
///
/// Un interrupteur bascule tout de suite : attendre le serveur pour le voir
/// bouger se lirait comme un toucher raté. Si l'enregistrement échoue, le
/// réglage revient à sa position d'avant, et l'erreur remonte pour que
/// l'écran la dise.
class NotificationPreferencesController
    extends AutoDisposeAsyncNotifier<NotificationPreferences> {
  @override
  Future<NotificationPreferences> build() async {
    final userId = ref.watch(
      currentUserProvider.select((u) => u.valueOrNull?.id),
    );
    if (userId == null) return NotificationPreferences.allOn;
    return ref.watch(notificationRepositoryProvider).fetchPreferences(userId);
  }

  Future<void> save(NotificationPreferences suivants) async {
    final userId = ref.read(currentUserProvider).valueOrNull?.id;
    final avant = state.valueOrNull;
    if (userId == null || avant == null || suivants == avant) return;
    state = AsyncData(suivants);
    try {
      await ref
          .read(notificationRepositoryProvider)
          .savePreferences(userId, suivants);
    } catch (_) {
      state = AsyncData(avant);
      rethrow;
    }
  }
}

final notificationPreferencesProvider =
    AsyncNotifierProvider.autoDispose<
      NotificationPreferencesController,
      NotificationPreferences
    >(NotificationPreferencesController.new);
