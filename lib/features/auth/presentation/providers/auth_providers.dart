import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/core/di/providers.dart';

import '../../data/datasources/in_memory_auth_datasource.dart';
import '../../data/repositories/in_memory_auth_repository.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';

/// Kept alive for the app's lifetime — holds every seeded/created account
/// and the active mock session, so it must not be recreated on every
/// screen rebuild.
final authDatasourceProvider = Provider<InMemoryAuthDatasource>((ref) {
  return InMemoryAuthDatasource();
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final datasource = ref.watch(authDatasourceProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return InMemoryAuthRepository(datasource, prefs);
});

/// The signed-in user, or `null` when signed out. `AsyncLoading` while the
/// persisted session (if any) is being restored on app start — this is what
/// `route_guards.dart` uses to hold the app on `/splash` briefly.
final currentUserProvider = StreamProvider<AppUser?>((ref) async* {
  final repository = ref.watch(authRepositoryProvider);
  await repository.restoreSession();
  yield* repository.watchCurrentUser();
});

/// Set by `LoginScreen` right before it submits credentials, cleared by
/// `LoadingScreen` once it hands off to the dashboard. Lets
/// `route_guards.dart` tell "just signed in from the login form" apart from
/// "app launched with an already-restored session" — only the former should
/// detour through the loading animation instead of landing on the
/// dashboard immediately.
final justLoggedInProvider = StateProvider<bool>((ref) => false);
