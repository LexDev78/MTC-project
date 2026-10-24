import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mtc_app/app/router/app_router.dart';
import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/app/theme/app_theme.dart';
import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/features/auth/data/datasources/supabase_auth_datasource.dart';
import 'package:mtc_app/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/auth/presentation/screens/loading_screen.dart';

/// Le parcours de l'incident du 24/10/2026, avec le vrai routeur et le vrai
/// dépôt : accueil, « Se connecter », identifiants, et le compte relu juste
/// après la connexion se fait d'abord refuser le jeton (`PGRST303`). La
/// connexion doit quand même mener au tableau de bord (par l'écran de
/// chargement), au lieu de rester sur l'écran de connexion.

class _Source implements SupabaseAuthDatasource {
  final evenements = StreamController<AuthState>.broadcast();
  Session? session;

  /// Le sort des prochaines lectures du profil, dans l'ordre : une erreur
  /// à lever, ou `null` pour une lecture qui passe.
  final echecs = <Object?>[];

  @override
  Session? get currentSession => session;

  @override
  Stream<AuthState> onAuthStateChange() => evenements.stream;

  @override
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    session = Session(
      accessToken: 'jeton',
      tokenType: 'bearer',
      user: const User(
        id: 'client-awa',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '2026-01-01T00:00:00Z',
      ),
    );
    evenements.add(AuthState(AuthChangeEvent.signedIn, session));
    return AuthResponse(session: session);
  }

  @override
  Future<void> signOut() async {
    session = null;
    evenements.add(const AuthState(AuthChangeEvent.signedOut, null));
  }

  @override
  Future<Map<String, dynamic>> fetchProfileRow(String userId) async {
    if (echecs.isNotEmpty) {
      final echec = echecs.removeAt(0);
      if (echec != null) throw echec;
    }
    return {
      'id': userId,
      'role': 'client',
      'display_name': 'Awa Traoré',
      'username_or_phone': 'client1',
      'phone_number': '+223 70 12 34 56',
      'created_at': '2026-01-01T00:00:00Z',
      'deleted_at': null,
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _avancer(WidgetTester tester, {int pas = 6}) async {
  for (var i = 0; i < pas; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

const _jetonDuFutur = PostgrestException(
  message: 'JWT issued at future',
  code: 'PGRST303',
);

Future<void> _seConnecterMalgre(
  WidgetTester tester,
  List<Object?> lectures,
) async {
  tester.view.physicalSize = const Size(390, 1400) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final source = _Source();
  addTearDown(source.evenements.close);
  final conteneur = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(SupabaseAuthRepository(source)),
      sharedPreferencesProvider.overrideWithValue(preferences),
    ],
  );
  addTearDown(conteneur.dispose);
  final routeur = conteneur.read(routerProvider);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: conteneur,
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: routeur),
    ),
  );
  // Démarrage : déconnecté, l'accueil.
  await _avancer(tester, pas: 10);
  expect(find.text('Bienvenue !'), findsOneWidget);

  await tester.tap(find.text('Se connecter'));
  await _avancer(tester);
  expect(find.text('Bon retour !'), findsOneWidget);

  source.echecs.addAll(lectures);
  final champs = find.byType(TextFormField);
  await tester.enterText(champs.at(0), 'client1');
  await tester.enterText(champs.at(1), 'password123');
  await tester.tap(find.text('Se connecter'));
  // Les reprises attendent 250 ms, puis 750 ms.
  await _avancer(tester, pas: 15);

  expect(find.byType(LoadingScreen), findsOneWidget);
  expect(find.text('Bon retour !'), findsNothing);
  expect(find.byType(SnackBar), findsNothing);
  expect(
    routeur.routerDelegate.currentConfiguration.uri.path,
    anyOf(AppRoutes.loading, AppRoutes.welcome),
  );
  expect(conteneur.read(currentUserProvider).valueOrNull?.id, 'client-awa');
}

void main() {
  // Le cas exact des journaux : `login()` relit le compte sans souci, mais
  // la relecture du flux de session se fait refuser le jeton. Avant la
  // correction, aucun message, et l'écran de connexion restait.
  testWidgets('seule la relecture du flux de session est refusée', (
    tester,
  ) async {
    await _seConnecterMalgre(tester, [null, _jetonDuFutur]);
  });

  testWidgets('les deux relectures sont refusées', (tester) async {
    await _seConnecterMalgre(tester, [_jetonDuFutur, _jetonDuFutur]);
  });
}
