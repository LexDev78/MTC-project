import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'app/session_scope.dart';
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
const _supabaseUrlDefinie = bool.hasEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

/// Une version publiée parle à la base de production, en https — jamais à
/// la pile locale.
///
/// `127.0.0.1` par défaut est commode en développement, et désastreux dans
/// un APK : l'app chercherait la base sur le téléphone lui-même. Et une
/// adresse `http` ferait passer mots de passe et jetons de session en clair
/// sur le réseau. Un build de release mal configuré refuse donc de démarrer,
/// plutôt que de démarrer faux ; `tool/build_release.sh` l'empêche de se
/// construire.
void _verifierLaConfigurationDeProduction() {
  if (!kReleaseMode) return;
  final adresse = Uri.tryParse(_supabaseUrl);
  final hote = adresse?.host ?? '';
  final problemes = [
    if (!_supabaseUrlDefinie)
      'SUPABASE_URL manquant (--dart-define=SUPABASE_URL=https://…)',
    if (adresse == null || adresse.scheme != 'https')
      'SUPABASE_URL doit être en https (reçu : $_supabaseUrl)',
    if (hote == '127.0.0.1' ||
        hote == 'localhost' ||
        hote == '10.0.2.2' ||
        hote.endsWith('.local'))
      'SUPABASE_URL désigne une machine locale ($hote)',
    if (_supabaseAnonKey.isEmpty) 'SUPABASE_ANON_KEY manquant',
  ];
  if (problemes.isNotEmpty) {
    throw StateError(
      'Configuration de production invalide : ${problemes.join(' ; ')}.',
    );
  }
}

/// Les polices embarquées sont sous licence SIL OFL 1.1, qui demande que
/// leur licence les accompagne : elle figure dans la page des licences de
/// l'app (`showLicensePage`), lue depuis les fichiers joints aux polices.
void _inscrireLicencesDesPolices() {
  LicenseRegistry.addLicense(() async* {
    for (final (police, fichier) in const [
      ('Plus Jakarta Sans', 'assets/fonts/plus_jakarta_sans/OFL.txt'),
      ('Archivo', 'assets/fonts/archivo/OFL.txt'),
    ]) {
      yield LicenseEntryWithLineBreaks([
        police,
      ], await rootBundle.loadString(fichier));
    }
  });
}

/// Single entry point for launching [MtcApp], wrapped in a [ProviderScope]
/// so the whole widget tree can access Riverpod providers.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  _verifierLaConfigurationDeProduction();
  _inscrireLicencesDesPolices();
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
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Must be a top-level function (see `push_background_handler.dart`) and
    // registered before `runApp` — this is what lets a push arrive while
    // the app is fully killed, not just backgrounded.
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint(
      'Firebase.initializeApp failed (push disabled for this run): $e',
    );
  }

  // Explicit `ProviderContainer`s (rather than a bare `ProviderScope`) so
  // `registerNotificationTapHandling` below has something to read from
  // outside the widget tree — a push tap (cold start or from background)
  // has no `BuildContext` to get a `WidgetRef` from. One per account:
  // `SessionScope` replaces it when an account ends, so the next account on
  // this device inherits nothing from the previous one.
  ProviderContainer createContainer() => ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      supabaseClientProvider.overrideWithValue(Supabase.instance.client),
    ],
  );
  var container = createContainer();

  runApp(
    SessionScope(
      initialContainer: container,
      createContainer: createContainer,
      onContainerChanged: (next) => container = next,
      child: const MtcApp(),
    ),
  );

  if (Firebase.apps.isNotEmpty) {
    registerNotificationTapHandling(() => container);
  }
}
