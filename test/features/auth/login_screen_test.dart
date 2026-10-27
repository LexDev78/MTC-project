import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/app/theme/app_theme.dart';
import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/core/error/exceptions.dart';
import 'package:mtc_app/core/shop/shop.dart';
import 'package:mtc_app/features/auth/domain/entities/app_user.dart';
import 'package:mtc_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/auth/presentation/screens/login_screen.dart';

import '../../support/shop_fixtures.dart';

/// L'écran de connexion de la charte MTC, sans base : ce qu'il montre, ce
/// qu'il refuse avant d'envoyer, ce qu'il envoie, et ce que « Se souvenir de
/// moi » garde sur le téléphone.

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
late SharedPreferences _preferences;
late GoRouter _routeur;

/// Ouvre la connexion. [retenu] : l'identifiant déjà gardé par « Se
/// souvenir de moi ». [depuisAccueil] : ouverte par-dessus l'accueil, comme
/// dans l'app.
Future<void> _ouvrir(
  WidgetTester tester, {
  ThemeMode mode = ThemeMode.light,
  Size taille = const Size(390, 1400),
  String? retenu,
  bool depuisAccueil = false,
}) async {
  tester.view.physicalSize = taille * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({
    if (retenu != null) LoginScreen.cleIdentifiantRetenu: retenu,
  });
  _preferences = await SharedPreferences.getInstance();
  _compte = _Compte();
  _conteneur = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(_compte),
      currentUserProvider.overrideWith((ref) => Stream.value(null)),
      sharedPreferencesProvider.overrideWithValue(_preferences),
    ],
  );
  addTearDown(_conteneur.dispose);

  // Comme dans `app_router.dart` : l'écran sous le thème de la charte.
  _routeur = GoRouter(
    initialLocation: depuisAccueil ? AppRoutes.welcome : AppRoutes.login,
    routes: [
      GoRoute(
        path: AppRoutes.welcome,
        builder: (_, _) => const Scaffold(body: Text('ACCUEIL')),
      ),
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
  addTearDown(_routeur.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: _conteneur,
      child: MaterialApp.router(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: mode,
        routerConfig: _routeur,
      ),
    ),
  );
  await _avancer(tester);
  if (depuisAccueil) {
    unawaited(_routeur.push(AppRoutes.login));
    await _avancer(tester);
  }
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

Finder get _coche => find.byWidgetPredicate(
  (w) => w is ShopIcon && w.asset == ShopIcons.singlecheck,
);

Future<void> _seConnecter(
  WidgetTester tester,
  String identifiant, {
  String motDePasse = 'password123',
}) async {
  await tester.enterText(_champIdentifiant, identifiant);
  await tester.enterText(_champMotDePasse, motDePasse);
  await _toucher(tester, find.text('Se connecter'));
}

void main() {
  testWidgets('la maquette : bandeau au logo, titre, champs, liens, bouton', (
    tester,
  ) async {
    await _ouvrir(tester);

    expect(find.byType(MtcBrandBand), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is SvgPicture &&
            w.bytesLoader is SvgAssetLoader &&
            (w.bytesLoader as SvgAssetLoader).assetName == MtcLogo.asset,
      ),
      findsOneWidget,
    );
    expect(find.text('MTC'), findsOneWidget);
    expect(find.text('Bon retour !'), findsOneWidget);
    expect(
      find.text(
        'Connectez-vous avec l\'identifiant et le\n'
        'mot de passe choisis à votre inscription.',
      ),
      findsOneWidget,
    );
    expect(_champIdentifiant, findsOneWidget);
    expect(_champMotDePasse, findsOneWidget);
    expect(find.text('Se souvenir de moi'), findsOneWidget);
    expect(find.text('Mot de passe oublié ?'), findsOneWidget);
    expect(find.widgetWithText(GradientButton, 'Se connecter'), findsOneWidget);
    expect(find.text('Pas encore de compte ?'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Créer un compte'), findsOneWidget);
    // Les icônes du kit, pas celles de Material.
    expect(find.byType(Icon), findsNothing);
    // Ouverte directement (après une déconnexion), rien derrière : pas de
    // retour.
    expect(find.byTooltip('Retour'), findsNothing);
    // L'écran est sous le thème de la charte.
    expect(
      Theme.of(tester.element(find.text('Bon retour !'))).colorScheme.primary,
      const Color(0xFF7762F6),
    );
  });

  testWidgets('ouverte depuis l\'accueil, le retour y ramène', (tester) async {
    await _ouvrir(tester, depuisAccueil: true);
    expect(find.text('Bon retour !'), findsOneWidget);
    expect(
      tester.getSemantics(find.byTooltip('Retour')),
      containsSemantics(isButton: true, hasTapAction: true),
    );

    await _toucher(tester, find.byTooltip('Retour'));

    expect(find.text('ACCUEIL'), findsOneWidget);
    expect(find.text('Bon retour !'), findsNothing);
  });

  testWidgets('en sombre, liens et case passent au violet clair', (
    tester,
  ) async {
    await _ouvrir(tester, mode: ThemeMode.dark);

    final lien = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Mot de passe oublié ?'),
    );
    expect(
      lien.style!.foregroundColor!.resolve(const {}),
      ShopColors.primaryLight,
    );
    expect(
      Theme.of(
        tester.element(find.text('Bon retour !')),
      ).scaffoldBackgroundColor,
      ShopColors.black,
    );
  });

  testWidgets('barre d\'état : claire sur le bandeau, puis selon la toile', (
    tester,
  ) async {
    // Assez bas pour que le bandeau puisse sortir tout entier par le haut.
    await _ouvrir(tester, taille: const Size(390, 480));
    expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.light);

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -2000),
    );
    await _avancer(tester);
    expect(find.byType(MtcLogo).hitTestable(), findsNothing);
    expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.dark);
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

  testWidgets('au focus, l\'icône du champ passe au violet', (tester) async {
    await _ouvrir(tester);
    Color? couleurCadenas() => tester
        .widget<ShopIcon>(
          find.descendant(
            of: _champMotDePasse,
            matching: find.byWidgetPredicate(
              (w) => w is ShopIcon && w.asset == ShopIcons.lock,
            ),
          ),
        )
        .color;
    expect(couleurCadenas(), ShopColors.fieldIcon);

    await tester.showKeyboard(_champMotDePasse);
    await _avancer(tester);
    expect(couleurCadenas(), ShopColors.primary);
  });

  testWidgets('la coche suit la saisie de l\'identifiant', (tester) async {
    await _ouvrir(tester);
    expect(_coche, findsNothing);

    await tester.enterText(_champIdentifiant, 'mariam.k');
    await _avancer(tester);
    expect(_coche, findsOneWidget);

    await tester.enterText(_champIdentifiant, '   ');
    await _avancer(tester);
    expect(_coche, findsNothing);
  });

  testWidgets('se connecter envoie l\'identifiant nettoyé, et attend', (
    tester,
  ) async {
    await _ouvrir(tester);
    _compte.attente = Completer<void>();

    await _seConnecter(tester, '  client1 ');

    expect(_compte.essais.single, (
      identifiant: 'client1',
      motDePasse: 'password123',
    ));
    // Posé avant la réponse : le routeur passera par le chargement.
    expect(_conteneur.read(justLoggedInProvider), isTrue);
    // Pendant l'envoi, le bouton tourne et ne se retouche pas ; un lecteur
    // d'écran l'entend encore, inactif.
    expect(find.text('Se connecter'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(GradientButton)),
      containsSemantics(
        label: 'Se connecter',
        isButton: true,
        isEnabled: false,
      ),
    );
    await tester.tap(find.byType(GradientButton));
    await _avancer(tester);
    expect(_compte.essais, hasLength(1));

    _compte.attente!.complete();
    await _avancer(tester);
    expect(_conteneur.read(justLoggedInProvider), isTrue);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('un refus le dit, et le bouton revient', (tester) async {
    await _ouvrir(tester);
    _compte.refus = const InvalidCredentialsException();

    await _seConnecter(tester, 'client1', motDePasse: 'mauvais');

    expect(find.text('Identifiants incorrects'), findsOneWidget);
    expect(_conteneur.read(justLoggedInProvider), isFalse);
    expect(find.text('Se connecter'), findsOneWidget);
  });

  group('se souvenir de moi', () {
    testWidgets('la case se coche, et le dit', (tester) async {
      await _ouvrir(tester);
      final caseACocher = find.text('Se souvenir de moi');
      expect(
        tester.getSemantics(caseACocher),
        containsSemantics(
          label: 'Se souvenir de moi',
          hasCheckedState: true,
          isChecked: false,
          hasTapAction: true,
        ),
      );

      await _toucher(tester, caseACocher);

      expect(
        tester.getSemantics(caseACocher),
        containsSemantics(hasCheckedState: true, isChecked: true),
      );
    });

    testWidgets('cochée, l\'identifiant revient à la connexion suivante', (
      tester,
    ) async {
      await _ouvrir(tester);
      await _toucher(tester, find.text('Se souvenir de moi'));

      await _seConnecter(tester, ' client1 ');

      expect(
        _preferences.getString(LoginScreen.cleIdentifiantRetenu),
        'client1',
      );
      // Jamais le mot de passe.
      expect(
        _preferences.getKeys().map(_preferences.get),
        isNot(contains('password123')),
      );

      // L'écran rouvert (après une déconnexion) le reprend, case cochée.
      await _ouvrir(tester, retenu: 'client1');
      expect(_saisie(tester, _champIdentifiant).controller.text, 'client1');
      expect(_saisie(tester, _champMotDePasse).controller.text, isEmpty);
      expect(
        tester.getSemantics(find.text('Se souvenir de moi')),
        containsSemantics(isChecked: true),
      );
    });

    testWidgets('décochée, l\'identifiant gardé est oublié', (tester) async {
      await _ouvrir(tester, retenu: 'ancien');
      await _toucher(tester, find.text('Se souvenir de moi'));

      await _seConnecter(tester, 'client2');

      expect(
        _preferences.containsKey(LoginScreen.cleIdentifiantRetenu),
        isFalse,
      );
    });

    testWidgets('un refus ne retient rien', (tester) async {
      await _ouvrir(tester);
      _compte.refus = const InvalidCredentialsException();
      await _toucher(tester, find.text('Se souvenir de moi'));

      await _seConnecter(tester, 'faute.de.frappe', motDePasse: 'mauvais');

      expect(
        _preferences.containsKey(LoginScreen.cleIdentifiantRetenu),
        isFalse,
      );
    });
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
