import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/app/theme/app_theme.dart';
import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/core/error/exceptions.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';
import 'package:mtc_app/features/auth/domain/entities/app_user.dart';
import 'package:mtc_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/auth/presentation/screens/forgot_password_code_screen.dart';
import 'package:mtc_app/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:mtc_app/features/auth/presentation/screens/login_screen.dart';

import '../../support/shop_fixtures.dart';

/// Mot de passe oublié, sans base : on désigne son compte, un code part à
/// l'adresse vérifiée, et le bon code change le mot de passe puis connecte.

const _bonCode = '123456';

/// Le compte, réduit à la récupération : il note les demandes, accepte
/// [_bonCode] et refuse le reste comme le ferait le serveur.
class _Compte implements AuthRepository {
  final demandes = <String>[];
  final changements = <({String identifier, String code, String password})>[];
  final connexions = <({String identifiant, String motDePasse})>[];

  /// Si posé, la demande de code échoue avec lui.
  Object? refusDemande;

  @override
  Future<PasswordResetRequest> requestPasswordReset(String identifier) async {
    if (refusDemande != null) throw refusDemande!;
    demandes.add(identifier);
    return (
      maskedEmail: 'aw•••@example.com',
      expiresAt: DateTime(2026, 10, 22, 10, 10),
      resendAfterSeconds: 60,
    );
  }

  @override
  Future<String> resetPasswordWithCode({
    required String identifier,
    required String code,
    required String newPassword,
  }) async {
    changements.add((
      identifier: identifier,
      code: code,
      password: newPassword,
    ));
    if (code != _bonCode) {
      throw const ValidationException(
        'Code incorrect. Il vous reste 4 essais.',
      );
    }
    // Venu par l'adresse e-mail : le serveur rend l'identifiant.
    return 'client1';
  }

  @override
  Future<AppUser> login({
    required String usernameOrPhone,
    required String password,
  }) async {
    connexions.add((identifiant: usernameOrPhone, motDePasse: password));
    return clientAwa();
  }

  @override
  Stream<AppUser?> watchCurrentUser() => Stream.value(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

late _Compte _compte;
late ProviderContainer _conteneur;

Future<void> _ouvrir(
  WidgetTester tester, {
  String depart = AppRoutes.login,
}) async {
  tester.view.physicalSize = const Size(375, 1100) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  // La connexion relit l'identifiant que « Se souvenir de moi » a gardé.
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  _compte = _Compte();
  _conteneur = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(_compte),
      currentUserProvider.overrideWith((ref) => Stream.value(null)),
      sharedPreferencesProvider.overrideWithValue(preferences),
    ],
  );
  addTearDown(_conteneur.dispose);

  final router = GoRouter(
    initialLocation: depart,
    routes: [
      GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (_, state) =>
            ForgotPasswordScreen(identifier: state.extra as String?),
      ),
      GoRoute(
        path: AppRoutes.forgotPasswordCode,
        builder: (_, state) => ForgotPasswordCodeScreen(
          args: state.extra as ForgotPasswordCodeArgs?,
        ),
      ),
      GoRoute(
        path: AppRoutes.signUpRole,
        builder: (_, _) => const Scaffold(body: Text('INSCRIPTION')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: _conteneur,
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
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

Finder get _champCode => find.descendant(
  of: find.byType(CodeInputField),
  matching: find.byType(TextField),
);

/// De l'écran de connexion jusqu'à celui du code, pour « awa ».
Future<void> _jusquAuCode(WidgetTester tester) async {
  await _ouvrir(tester);
  await tester.enterText(
    find.widgetWithText(TextFormField, "Nom d'utilisateur ou téléphone"),
    'awa',
  );
  await _toucher(tester, find.text('Mot de passe oublié ?'));
  await _toucher(tester, find.text('Recevoir un code'));
}

Future<void> _saisirMotsDePasse(
  WidgetTester tester,
  String motDePasse, {
  String? confirmation,
}) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Nouveau mot de passe'),
    motDePasse,
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Confirmer le mot de passe'),
    confirmation ?? motDePasse,
  );
  await _avancer(tester);
}

void main() {
  testWidgets('le lien de la connexion emporte l\'identifiant déjà tapé', (
    tester,
  ) async {
    await _ouvrir(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, "Nom d'utilisateur ou téléphone"),
      ' awa ',
    );

    await _toucher(tester, find.text('Mot de passe oublié ?'));

    expect(find.text('Récupérer votre compte'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.widgetWithText(
                TextFormField,
                'Identifiant ou adresse e-mail',
              ),
              matching: find.byType(TextField),
            ),
          )
          .controller!
          .text,
      'awa',
    );
  });

  testWidgets('sans identifiant, rien ne part', (tester) async {
    await _ouvrir(tester, depart: AppRoutes.forgotPassword);

    await _toucher(tester, find.text('Recevoir un code'));

    expect(
      find.text('Saisissez votre identifiant ou votre adresse e-mail.'),
      findsOneWidget,
    );
    expect(_compte.demandes, isEmpty);
  });

  testWidgets('un compte sans adresse vérifiée le dit, et l\'on reste', (
    tester,
  ) async {
    await _ouvrir(tester, depart: AppRoutes.forgotPassword);
    _compte.refusDemande = const ValidationException(
      'Ce compte n\'a pas d\'adresse e-mail vérifiée : il ne peut pas être '
      'récupéré par e-mail. Contactez MTC.',
    );

    await tester.enterText(find.byType(TextFormField), 'client2');
    await _toucher(tester, find.text('Recevoir un code'));

    expect(find.byType(MtcErrorBanner), findsOneWidget);
    expect(
      find.textContaining('pas d\'adresse e-mail vérifiée'),
      findsOneWidget,
    );
    expect(find.text('Nouveau mot de passe'), findsNothing);
  });

  testWidgets('le code part : l\'écran dit où, et attend avant de renvoyer', (
    tester,
  ) async {
    await _jusquAuCode(tester);

    expect(_compte.demandes, ['awa']);
    expect(find.textContaining('aw•••@example.com'), findsOneWidget);
    expect(find.text('Renvoyer le code dans 1:00'), findsOneWidget);
    final renvoyer = find.widgetWithText(TextButton, 'Renvoyer');
    expect(tester.widget<TextButton>(renvoyer).onPressed, isNull);

    await tester.pump(const Duration(seconds: 61));
    await _avancer(tester);
    expect(tester.widget<TextButton>(renvoyer).onPressed, isNotNull);
    await _toucher(tester, renvoyer);
    expect(_compte.demandes, ['awa', 'awa']);
    expect(
      find.text('Un nouveau code est parti à aw•••@example.com.'),
      findsOneWidget,
    );
  });

  testWidgets('code incomplet, mots de passe différents : rien ne part', (
    tester,
  ) async {
    await _jusquAuCode(tester);

    await _saisirMotsDePasse(tester, 'NouveauMdp1');
    await _toucher(tester, find.text('Changer le mot de passe'));
    expect(
      find.text('Saisissez les six chiffres du code reçu.'),
      findsOneWidget,
    );

    await tester.enterText(_champCode, _bonCode);
    await _saisirMotsDePasse(tester, 'NouveauMdp1', confirmation: 'Autre1');
    await _toucher(tester, find.text('Changer le mot de passe'));
    expect(
      find.text('Les deux mots de passe ne sont pas identiques.'),
      findsOneWidget,
    );

    await _saisirMotsDePasse(tester, '12345');
    await _toucher(tester, find.text('Changer le mot de passe'));
    expect(find.text('6 caractères minimum'), findsOneWidget);

    expect(_compte.changements, isEmpty);
  });

  testWidgets('un code faux est refusé, et les cases se vident', (
    tester,
  ) async {
    await _jusquAuCode(tester);

    await tester.enterText(_champCode, '000000');
    await _saisirMotsDePasse(tester, 'NouveauMdp1');
    await _toucher(tester, find.text('Changer le mot de passe'));

    expect(
      find.text('Code incorrect. Il vous reste 4 essais.'),
      findsOneWidget,
    );
    expect(tester.widget<TextField>(_champCode).controller!.text, isEmpty);
    expect(_compte.connexions, isEmpty);
  });

  testWidgets('le bon code change le mot de passe, puis connecte', (
    tester,
  ) async {
    await _jusquAuCode(tester);

    await tester.enterText(_champCode, _bonCode);
    await _saisirMotsDePasse(tester, 'NouveauMdp1');
    await _toucher(tester, find.text('Changer le mot de passe'));

    expect(_compte.changements.single, (
      identifier: 'awa',
      code: _bonCode,
      password: 'NouveauMdp1',
    ));
    // Avec l'identifiant rendu par le serveur.
    expect(_compte.connexions.single, (
      identifiant: 'client1',
      motDePasse: 'NouveauMdp1',
    ));
    expect(_conteneur.read(justLoggedInProvider), isTrue);
    expect(
      find.text('Mot de passe changé : vous êtes connecté.'),
      findsOneWidget,
    );
  });

  testWidgets('ouvert sans demande, l\'écran du code le dit', (tester) async {
    await _ouvrir(tester, depart: AppRoutes.forgotPasswordCode);

    expect(find.text('Aucun code demandé'), findsOneWidget);
  });
}
