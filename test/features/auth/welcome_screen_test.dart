import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/app/theme/app_theme.dart';
import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/core/shop/shop.dart';
import 'package:mtc_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/auth/presentation/screens/login_screen.dart';
import 'package:mtc_app/features/auth/presentation/screens/welcome_screen.dart';

/// L'accueil de la charte MTC, sans base : « Bienvenue ! », créer un compte
/// ou se connecter — et la connexion ouverte par-dessus, d'où l'on revient.

class _Compte implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _ouvrir(
  WidgetTester tester, {
  Size taille = const Size(390, 844),
}) async {
  tester.view.physicalSize = taille * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final conteneur = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(_Compte()),
      currentUserProvider.overrideWith((ref) => Stream.value(null)),
      sharedPreferencesProvider.overrideWithValue(preferences),
    ],
  );
  addTearDown(conteneur.dispose);

  // Comme dans `app_router.dart` : accueil et connexion sous la charte.
  final routeur = GoRouter(
    initialLocation: AppRoutes.welcome,
    routes: [
      GoRoute(
        path: AppRoutes.welcome,
        builder: (_, _) => const ShopScope(child: WelcomeScreen()),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, _) => const ShopScope(child: LoginScreen()),
      ),
      GoRoute(
        path: AppRoutes.signUpRole,
        builder: (_, _) => const Scaffold(body: Text('INSCRIPTION')),
      ),
    ],
  );
  addTearDown(routeur.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: conteneur,
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: routeur),
    ),
  );
  await _avancer(tester);
}

Future<void> _avancer(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _toucher(WidgetTester tester, Finder cible) async {
  await tester.ensureVisible(cible);
  await tester.pump();
  await tester.tap(cible);
  await _avancer(tester);
}

void main() {
  testWidgets('la maquette : bandeau au logo, « Bienvenue ! », deux boutons', (
    tester,
  ) async {
    await _ouvrir(tester);

    expect(find.byType(MtcBrandBand), findsOneWidget);
    expect(find.byType(MtcLogo), findsOneWidget);
    expect(find.text('MTC'), findsOneWidget);
    expect(find.text('Bienvenue !'), findsOneWidget);
    expect(
      find.text('Connectez-vous ou créez\nun compte pour continuer.'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(GradientButton, 'Créer un compte'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(GradientOutlinedButton, 'Se connecter'),
      findsOneWidget,
    );
    // Dessinés à la main, les deux boutons se déclarent comme tels.
    for (final libelle in ['Créer un compte', 'Se connecter']) {
      expect(
        tester.getSemantics(find.text(libelle)),
        containsSemantics(
          label: libelle,
          isButton: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
    }
    // Rien derrière l'accueil, et pas de moyens de connexion qui
    // n'existent pas.
    expect(find.byTooltip('Retour'), findsNothing);
    expect(find.text('Autres moyens de connexion'), findsNothing);
    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('« Créer un compte » mène à l\'inscription', (tester) async {
    await _ouvrir(tester);

    await _toucher(tester, find.text('Créer un compte'));

    expect(find.text('INSCRIPTION'), findsOneWidget);
  });

  testWidgets('« Se connecter » ouvre la connexion, et le retour ramène ici', (
    tester,
  ) async {
    await _ouvrir(tester);

    await _toucher(tester, find.text('Se connecter'));
    expect(find.text('Bon retour !'), findsOneWidget);
    expect(find.text('Bienvenue !'), findsNothing);

    await _toucher(tester, find.byTooltip('Retour'));
    expect(find.text('Bienvenue !'), findsOneWidget);
    expect(find.text('Bon retour !'), findsNothing);
  });

  // La police de `flutter test` est large : ce qui tient ici tient sur un
  // petit téléphone en grands caractères.
  testWidgets('tient sur un écran de 320 points, sans déborder', (
    tester,
  ) async {
    await _ouvrir(tester, taille: const Size(320, 568));

    await tester.scrollUntilVisible(
      find.text('Se connecter'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await _avancer(tester);
    expect(tester.takeException(), isNull);
  });
}
