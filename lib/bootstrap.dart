import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/di/providers.dart';
import 'core/push/notification_tap_router.dart';
import 'core/push/push_background_handler.dart';
import 'core/storage/secure_session_storage.dart';
import 'firebase_options.dart';

/// Local Supabase stack started via `supabase start` (see
/// `BACKEND_MIGRATION_PROGRESS.md`) — `54321` is the CLI's fixed local API
/// port. The anon key isn't fixed across CLI versions/projects, so it's
/// supplied at build/run time (`--dart-define=SUPABASE_ANON_KEY=...`)
/// rather than guessed/hardcoded here.
const _supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'http://127.0.0.1:54321',
);
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

/// Single entry point for launching [MtcApp], wrapped in a [ProviderScope]
/// so the whole widget tree can access Riverpod providers.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  assert(
    _supabaseAnonKey.isNotEmpty,
    'Run with --dart-define=SUPABASE_ANON_KEY=<key from `supabase status`> '
    '(see BACKEND_MIGRATION_PROGRESS.md, Lot 0).',
  );
  await Supabase.initialize(
    url: _supabaseUrl,
    publishableKey: _supabaseAnonKey,
    authOptions: FlutterAuthClientOptions(localStorage: SecureSessionStorage()),
  );

  // Best-effort: `firebase_options.dart` is a placeholder until
  // `flutterfire configure` has been run (see the push-notifications plan,
  // Phase 3) and deliberately throws if used before then. The rest of the
  // app must stay usable in the meantime — push is opt-in everywhere else
  // (`pushRegistrationProvider`, `AuthController.logout`) via the same
  // `Firebase.apps.isEmpty` check, so this is the one place that also has
  // to survive `initializeApp` itself failing, not just being skipped.
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    // Must be a top-level function (see `push_background_handler.dart`) and
    // registered before `runApp` — this is what lets a push arrive while
    // the app is fully killed, not just backgrounded.
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('Firebase.initializeApp failed (push disabled for this run): $e');
  }

  // An explicit `ProviderContainer` (rather than a bare `ProviderScope`)
  // so `registerNotificationTapHandling` below has something to read from
  // outside the widget tree — a push tap (cold start or from background)
  // has no `BuildContext` to get a `WidgetRef` from.
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      supabaseClientProvider.overrideWithValue(Supabase.instance.client),
    ],
  );

  runApp(
    UncontrolledProviderScope(container: container, child: const MtcApp()),
  );

  if (Firebase.apps.isNotEmpty) {
    registerNotificationTapHandling(container);
  }
}
