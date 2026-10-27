import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/app/router/app_router.dart';
import 'package:mtc_app/features/auth/domain/entities/app_user.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/notifications/domain/entities/app_notification.dart';
import 'package:mtc_app/features/notifications/domain/notification_route_resolver.dart';
import 'package:mtc_app/features/suppliers/presentation/providers/operating_supplier_providers.dart';

/// Wires push-tap navigation to the same routing the in-app notification
/// list uses (`resolveNotificationRoute`) — cold start
/// (`getInitialMessage()`) and backgrounded-then-tapped
/// (`onMessageOpenedApp`). Called once from `bootstrap.dart`, right after
/// `runApp`, with a way to reach the app's current [ProviderContainer]:
/// there's no `BuildContext`/`WidgetRef` this early, or ever for a tap that
/// arrives while the app is backgrounded. *Current*, because `SessionScope`
/// replaces the container whenever an account ends.
void registerNotificationTapHandling(
  ProviderContainer Function() currentContainer,
) {
  Future<void> handle(RemoteMessage? message) async {
    if (message == null) return;
    final container = currentContainer();
    final type = notificationTypeFromDbValue(message.data['type'] as String?);
    if (type == null) return;

    // Cold start: the session may not have hydrated into an `AppUser` yet
    // even though `Supabase.initialize()` already completed — `.future`
    // waits for that instead of racing it with `.valueOrNull`, which could
    // otherwise misroute a supplier's tap as a client's, or vice versa.
    final user = await container.read(currentUserProvider.future);
    if (user == null) return;
    // The account changed while the session was loading: this tap was
    // addressed to the previous one, and must not navigate the next.
    if (!identical(container, currentContainer())) return;

    // The send path (`supabase/functions/_shared/fcm.ts`) sends `''` for a
    // missing reference — FCM's `data` payload only carries strings — so an
    // empty string here means the same thing `null` does everywhere else.
    final rawReferenceId = message.data['referenceId'] as String?;
    final referenceId = (rawReferenceId == null || rawReferenceId.isEmpty)
        ? null
        : rawReferenceId;

    final route = resolveNotificationRoute(
      type: type,
      referenceId: referenceId,
      isClient: user is ClientUser,
      supplierRoutePrefix: container.read(supplierRoutePrefixProvider),
    );
    if (route != null) {
      unawaited(container.read(routerProvider).push(route));
    }
  }

  unawaited(FirebaseMessaging.instance.getInitialMessage().then(handle));
  FirebaseMessaging.onMessageOpenedApp.listen(handle);
}
