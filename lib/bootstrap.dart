import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/di/providers.dart';

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
  );

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        supabaseClientProvider.overrideWithValue(Supabase.instance.client),
      ],
      child: const MtcApp(),
    ),
  );
}
