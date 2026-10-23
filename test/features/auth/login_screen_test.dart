import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/app/theme/app_theme.dart';
import 'package:mtc_app/core/error/exceptions.dart';
import 'package:mtc_app/core/shop/shop.dart';
import 'package:mtc_app/features/auth/domain/entities/app_user.dart';
import 'package:mtc_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/auth/presentation/screens/login_screen.dart';

import '../../support/shop_fixtures.dart';

/// L'écran de connexion, repris du kit FlutterShop, sans base : ce qu'il
/// montre, ce qu'il refuse avant d'envoyer, et ce qu'il envoie.

/// Le compte, réduit à la connexion : il note les essais, et refuse ou
/// accepte selon [refus].
class _Compte implements AuthRepository {
  final essais = <({String identifiant, String motDePasse})>[];

  /// Si posé, la connexion échoue avec lui.
  Object? refus;

  /// Si posé, la connexion attend qu'on le complète.
  Completer<void>? attente;

  @override
  Future<AppUser> login({
    required String usernameOrPhone,
    required String password,
  }) async {
    essais.add((identifiant: usernameOrPhone, motDePasse: password));
    await attente?.future;
    if (refus != null) throw refus!;
    return clientAwa();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

late _Compte _compte;
late ProviderContainer _conteneur;

Future<void> _ouvrir(
  WidgetTester tester, {
  ThemeMode mode = ThemeMode.light,
  Size taille = const Size(375, 1400),
}) async {
  tester.view.physicalSize = taille * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  _compte = _Compte();
  _conteneur = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(_compte),
      currentUserProvider.overrideWith((ref) => Stream.value(null)),
    ],
  );
  addTearDown(_conteneur.dispose);

  // Comme dans `app_router.dart` : l'écran sous le thème du kit.
  final router = GoRouter(
    initialLocation: AppRoutes.login,
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (_, _) => const ShopScope(child: LoginScreen()),
      ),
      GoRoute(
        path: AppRoutes.signUpRole,
        builder: (_, _) => const Scaffold(body: Text('INSCRIPTION')),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (_, state) =>
            Scaffold(body: Text('RÉCUPÉRATION de « ${state.extra} »')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: _conteneur,
      child: MaterialApp.router(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: mode,
        routerConfig: router,
      ),
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

Finder get _champIdentifiant =>
    find.widgetWithText(TextFormField, "Nom d'utilisateur ou téléphone");

Finder get _champMotDePasse =>
    find.widgetWithText(TextFormField, 'Mot de passe');

/// Le texte réellement saisi (et masqué ou non) du champ [champ].
EditableText _saisie(WidgetTester tester, Finder champ) =>
    tester.widget<EditableText>(
      find.descendant(of: champ, matching: find.byType(EditableText)),
    );

void main() {
  testWidgets('l\'écran du kit : photo, titre, champs, liens et bouton', (
    tester,
  ) async {
    await _ouvrir(tester);

    expect(
      find.image(const AssetImage('assets/shop/images/login_light.png')),
      findsOneWidget,
    );
    expect(find.text('Bon retour !'), findsOneWidget);
    expect(
      find.text(
        'Connectez-vous avec l\'identifiant et le mot de passe choisis à '
        'votre inscription.',
      ),
      findsOneWidget,
    );
    expect(_champIdentifiant, findsOneWidget);
    expect(_champMotDePasse, findsOneWidget);
    expect(find.text('Mot de passe oublié ?'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Se connecter'), findsOneWidget);
    expect(find.text('Pas encore de compte ?'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Créer un compte'), findsOneWidget);
    // Les icônes du kit, pas celles de Material.
    expect(find.byType(Icon), findsNothing);
    // Le bouton prend la couleur du kit : l'écran est bien sous `ShopScope`.
    expect(
      Theme.of(tester.element(find.byType(ElevatedButton))).colorScheme.primary,
      ShopColors.primary,
    );
  });

  testWidgets('en sombre, la photo dont la vague a la couleur de la toile', (
    tester,
  ) async {
    await _ouvrir(tester, mode: ThemeMode.dark);

    expect(
      find.image(const AssetImage('assets/shop/images/login_dark.png')),
      findsOneWidget,
    );
    expect(
      find.image(const AssetImage('assets/shop/images/login_light.png')),
      findsNothing,
    );
    final toile = Theme.of(
      tester.element(find.text('Bon retour !')),
    ).scaffoldBackgroundColor;
    // La vague du fichier sombre est peinte en #16161E.
    expect(toile, ShopColors.black);
  });

  testWidgets('barre d\'état : foncée sur la photo, claire sur la toile '
      'sombre', (tester) async {
    // Assez bas pour que la photo puisse sortir tout entière par le haut.
    await _ouvrir(tester, mode: ThemeMode.dark, taille: const Size(375, 480));
    expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.dark);

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -2000),
    );
    await _avancer(tester);
    expect(find.byType(Image).hitTestable(), findsNothing);
    expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.light);
  });

  // La police de `flutter test` est large : ce qui tient ici tient sur un
  // petit téléphone en grands caractères.
  testWidgets('tient sur un écran de 320 points, sans déborder', (
    tester,
  ) async {
    await _ouvrir(tester, taille: const Size(320, 568));

    await tester.scrollUntilVisible(
      find.text('Créer un compte'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await _avancer(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Créer un compte'), findsOneWidget);
  });

  testWidgets('rien ne part sans identifiant ni mot de passe', (tester) async {
    await _ouvrir(tester);

    await _toucher(tester, find.text('Se connecter'));

    expect(find.text('Identifiant obligatoire'), findsOneWidget);
    expect(find.text('Le mot de passe est obligatoire'), findsOneWidget);
    expect(_compte.essais, isEmpty);
    expect(_conteneur.read(justLoggedInProvider), isFalse);
  });

  testWidgets('l\'œil affiche puis masque le mot de passe', (tester) async {
    await _ouvrir(tester);
    await tester.enterText(_champMotDePasse, 'secret1');
    await _avancer(tester);

    expect(_saisie(tester, _champMotDePasse).obscureText, isTrue);

    await _toucher(tester, find.byTooltip('Afficher le mot de passe'));
    expect(_saisie(tester, _champMotDePasse).obscureText, isFalse);
    expect(_saisie(tester, _champMotDePasse).controller.text, 'secret1');

    await _toucher(tester, find.byTooltip('Masquer le mot de passe'));
    expect(_saisie(tester, _champMotDePasse).obscureText, isTrue);
  });

  testWidgets('se connecter envoie l\'identifiant nettoyé, et attend', (
    tester,
  ) async {
    await _ouvrir(tester);
    _compte.attente = Completer<void>();
    await tester.enterText(_champIdentifiant, '  client1 ');
    await tester.enterText(_champMotDePasse, 'password123');

    await _toucher(tester, find.text('Se connecter'));

    expect(_compte.essais.single, (
      identifiant: 'client1',
      motDePasse: 'password123',
    ));
    // Posé avant la réponse : le routeur passera par le chargement.
    expect(_conteneur.read(justLoggedInProvider), isTrue);
    // Pendant l'envoi, le bouton tourne et ne se retouche pas.
    expect(find.text('Se connecter'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );

    _compte.attente!.complete();
    await _avancer(tester);
    expect(_conteneur.read(justLoggedInProvider), isTrue);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('un refus le dit, et le bouton revient', (tester) async {
    await _ouvrir(tester);
    _compte.refus = const InvalidCredentialsException();
    await tester.enterText(_champIdentifiant, 'client1');
    await tester.enterText(_champMotDePasse, 'mauvais');

    await _toucher(tester, find.text('Se connecter'));

    expect(find.text('Identifiants incorrects'), findsOneWidget);
    expect(_conteneur.read(justLoggedInProvider), isFalse);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('« Créer un compte » mène à l\'inscription', (tester) async {
    await _ouvrir(tester);

    await _toucher(tester, find.text('Créer un compte'));

    expect(find.text('INSCRIPTION'), findsOneWidget);
  });

  testWidgets('« Mot de passe oublié ? » emporte l\'identifiant tapé', (
    tester,
  ) async {
    await _ouvrir(tester);
    await tester.enterText(_champIdentifiant, ' awa ');

    await _toucher(tester, find.text('Mot de passe oublié ?'));

    expect(find.text('RÉCUPÉRATION de « awa »'), findsOneWidget);
  });

  testWidgets('un compte de démonstration remplit les deux champs', (
    tester,
  ) async {
    await _ouvrir(tester);
    expect(find.text('Fournisseur tiers (vérifié)'), findsNothing);

    await _toucher(tester, find.text('Comptes de démonstration'));
    await _toucher(tester, find.text('Fournisseur tiers (vérifié)'));

    expect(_saisie(tester, _champIdentifiant).controller.text, 'fournisseur1');
    expect(_saisie(tester, _champMotDePasse).controller.text, 'password123');
  });
}
