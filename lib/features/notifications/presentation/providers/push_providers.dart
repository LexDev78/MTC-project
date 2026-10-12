import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/features/auth/domain/entities/app_user.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';

import '../../data/datasources/supabase_device_token_datasource.dart';
import '../../data/repositories/supabase_device_token_repository.dart';
import '../../domain/repositories/device_token_repository.dart';

final firebaseMessagingProvider = Provider<FirebaseMessaging>((ref) {
  return FirebaseMessaging.instance;
});

final deviceTokenDatasourceProvider = Provider<SupabaseDeviceTokenDatasource>((
  ref,
) {
  return SupabaseDeviceTokenDatasource(ref.watch(supabaseClientProvider));
});

final deviceTokenRepositoryProvider = Provider<DeviceTokenRepository>((ref) {
  return SupabaseDeviceTokenRepository(ref.watch(deviceTokenDatasourceProvider));
});

/// Owns this device's FCM token lifecycle for the signed-in user: requests
/// notification permission, fetches and registers the token, and keeps it
/// fresh on rotation. Watched once from `MtcApp` (see `app.dart`) so it
/// lives for the app's lifetime, same pattern as
/// `routerProvider`/`themeModeControllerProvider`.
///
/// `fireImmediately: true` on the `currentUserProvider` listener covers
/// both "already signed in when the app launches" (a restored session
/// replays through `currentUserProvider` right away, per its own doc
/// comment) and "signs in during this session" with the same code path,
/// rather than needing two.
final pushRegistrationProvider = Provider<void>((ref) {
  // `FirebaseMessaging.instance` (below, via `firebaseMessagingProvider`)
  // throws synchronously if no app was ever initialized — true both before
  // the Phase 3 `flutterfire configure` step lands, and in every
  // widget/integration test that pumps `MtcApp` through a bare
  // `ProviderScope` rather than `bootstrap.dart`'s
  // `Firebase.initializeApp()`. Push registration is opt-in best-effort, so
  // it simply doesn't run rather than taking the whole widget tree down
  // with it.
  if (Firebase.apps.isEmpty) return;

  final messaging = ref.watch(firebaseMessagingProvider);
  final repository = ref.watch(deviceTokenRepositoryProvider);

  Future<void> registerFor(String userId) async {
    try {
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      final token = await messaging.getToken();
      if (token != null) {
        await repository.registerToken(userId: userId, fcmToken: token);
      }
    } catch (e) {
      debugPrint('pushRegistrationProvider.registerFor failed (ignored): $e');
    }
  }

  ref.listen<AsyncValue<AppUser?>>(
    currentUserProvider,
    (previous, next) {
      final user = next.valueOrNull;
      if (user != null) unawaited(registerFor(user.id));
    },
    fireImmediately: true,
  );

  final tokenRefreshSubscription = messaging.onTokenRefresh.listen((token) {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user != null) {
      unawaited(repository.registerToken(userId: user.id, fcmToken: token));
    }
  });
  ref.onDispose(tokenRefreshSubscription.cancel);
});
