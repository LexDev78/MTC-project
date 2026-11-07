import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:mtc_app/firebase_options.dart';

/// Registered via `FirebaseMessaging.onBackgroundMessage` in
/// `bootstrap.dart`. Runs in its own isolate — no access to this app's
/// `ProviderContainer`/Riverpod state, and the plugin requires a top-level
/// (or static) function, never an instance method. Kept minimal: Android
/// already puts the notification in the system tray with zero app code
/// running, so this exists mainly to satisfy the plugin's contract and
/// leave room for a future silent/data-only push.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}
