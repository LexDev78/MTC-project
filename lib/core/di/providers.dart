import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Overridden with a real instance in `bootstrap.dart` before `runApp`.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in bootstrap.dart',
  );
});

/// Overridden with `Supabase.instance.client` in `bootstrap.dart` before
/// `runApp`, once `Supabase.initialize` has completed — see
/// `BACKEND_MIGRATION_PROGRESS.md`.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  throw UnimplementedError(
    'supabaseClientProvider must be overridden in bootstrap.dart',
  );
});
