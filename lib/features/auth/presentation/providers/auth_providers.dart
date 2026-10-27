import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/core/di/providers.dart';

import '../../data/datasources/supabase_auth_datasource.dart';
import '../../data/repositories/supabase_auth_repository.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';

final authDatasourceProvider = Provider<SupabaseAuthDatasource>((ref) {
  return SupabaseAuthDatasource(ref.watch(supabaseClientProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final datasource = ref.watch(authDatasourceProvider);
  return SupabaseAuthRepository(datasource);
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

/// L'adresse e-mail de contact du compte en session (`0109`), ou `null`.
///
/// Distincte de l'identifiant de connexion, qui reste le téléphone. Relue à
/// chaque ouverture (`autoDispose`) : elle change rarement, mais un écran
/// qui montrerait l'ancienne juste après qu'on l'a modifiée ferait croire
/// que l'enregistrement a échoué.
/// L'adresse de contact et si elle est vérifiée (`0124`) — pour les écrans
/// qui doivent le dire.
final contactEmailStatusProvider =
    FutureProvider.autoDispose<ContactEmailStatus>((ref) {
      ref.watch(currentUserProvider.select((u) => u.valueOrNull?.id));
      return ref.watch(authRepositoryProvider).fetchContactEmailStatus();
    });

final contactEmailProvider = FutureProvider.autoDispose<String?>((ref) {
  // Dépend de la session : sans cela, l'adresse du compte précédent
  // survivrait à une déconnexion.
  ref.watch(currentUserProvider.select((u) => u.valueOrNull?.id));
  return ref.watch(authRepositoryProvider).fetchContactEmail();
});
