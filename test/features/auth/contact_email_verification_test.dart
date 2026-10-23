import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/app/theme/app_theme.dart';
import 'package:mtc_app/core/error/exceptions.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';
import 'package:mtc_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/auth/presentation/screens/contact_email_code_screen.dart';
import 'package:mtc_app/features/auth/presentation/screens/contact_email_screen.dart';

import '../../support/shop_fixtures.dart';

/// Ajouter une adresse e-mail, sans base : un code part, l'adresse ne
/// s'enregistre qu'avec lui, et chaque refus se lit.

const _bonCode = '123456';

/// Le compte, réduit à l'adresse : il note les demandes de code, accepte
/// [_bonCode] et refuse le reste comme le ferait le serveur.
class _Compte implements AuthRepository {
  _Compte({this.email, this.verifiee = false});

  String? email;
  bool verifiee;
  final demandes = <String>[];
  final codes = <String>[];
  final retraits = <String?>[];

  /// Si posé, la demande de code échoue avec lui.
  Object? refusDemande;

  @override
  Future<ContactEmailStatus> fetchContactEmailStatus() async =>
      (email: email, verified: verifiee);

  @override
  Future<String?> fetchContactEmail() async => email;

  @override
  Future<ContactEmailCodeRequest> requestContactEmailCode(String adresse) async {
    if (refusDemande != null) throw refusDemande!;
    demandes.add(adresse);
    return (
      email: adresse.trim().toLowerCase(),
      expiresAt: DateTime(2026, 10, 22, 10, 10),
      resendAfterSeconds: 60,
    );
  }

  @override
  Future<String> confirmContactEmail(String code) async {
    codes.add(code);
    if (code != _bonCode) {
      throw const ValidationException('Code incorrect. Il vous reste 4 essais.');
    }
    email = demandes.last.trim().toLowerCase();
    verifiee = true;
    return email!;
  }

  @override
  Future<String?> setContactEmail(String? adresse) async {
    retraits.add(adresse);
    email = null;
    verifiee = false;
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

late _Compte _compte;

/// Une page de départ d'où l'on ouvre l'écran de l'adresse, pour voir
/// celui-ci se refermer une fois l'adresse enregistrée.
Future<void> _ouvrir(
  WidgetTester tester, {
  String? email,
  bool verifiee = false,
}) async {
  tester.view.physicalSize = const Size(375, 1000) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  _compte = _Compte(email: email, verifiee: verifiee);
  final router = GoRouter(
    initialLocation: '/depart',
    routes: [
      GoRoute(
        path: '/depart',
        builder: (context, _) => Scaffold(
          body: TextButton(
            onPressed: () => context.push(AppRoutes.accountEmail),
            child: const Text('OUVRIR'),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.accountEmail,
        builder: (_, _) => const ContactEmailScreen(),
      ),
      GoRoute(
        path: AppRoutes.accountEmailCode,
        builder: (_, state) => ContactEmailCodeScreen(
          request: state.extra as ContactEmailCodeRequest?,
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_compte),
        currentUserProvider.overrideWith((ref) => Stream.value(clientAwa())),
      ],
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  await _avancer(tester);
  await tester.tap(find.text('OUVRIR'));
  await _avancer(tester);
}

Future<void> _avancer(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _toucher(WidgetTester tester, String texte) async {
  await tester.tap(find.text(texte));
  await _avancer(tester);
}

/// Le champ, invisible, sous les six cases du code.
Finder get _champCode => find.descendant(
  of: find.byType(CodeInputField),
  matching: find.byType(TextField),
);

Future<void> _demanderCode(WidgetTester tester, String adresse) async {
  await tester.enterText(
    find.widgetWithText(TextField, 'Adresse e-mail'),
    adresse,
  );
  await _avancer(tester);
  await _toucher(tester, 'Recevoir un code');
}

void main() {
  testWidgets('l\'adresse ne part pas sans code : on reçoit d\'abord un code', (
    tester,
  ) async {
    await _ouvrir(tester);

    final bouton = find.widgetWithText(MtcPrimaryButton, 'Recevoir un code');
    expect(tester.widget<MtcPrimaryButton>(bouton).onPressed, isNull);

    await _demanderCode(tester, ' Awa@Exemple.ml ');

    expect(_compte.demandes, ['Awa@Exemple.ml']);
    expect(find.text('Code de vérification'), findsOneWidget);
    expect(find.textContaining('awa@exemple.ml'), findsOneWidget);
    expect(find.text('Renvoyer le code dans 1:00'), findsOneWidget);
    // Rien d'enregistré tant que le code n'est pas donné.
    expect(_compte.email, isNull);
  });

  testWidgets('un code faux est refusé, les cases se vident', (tester) async {
    await _ouvrir(tester);
    await _demanderCode(tester, 'awa@exemple.ml');

    // Six chiffres : la validation part d'elle-même.
    await tester.enterText(_champCode, '000000');
    await _avancer(tester);

    expect(_compte.codes, ['000000']);
    expect(find.text('Code incorrect. Il vous reste 4 essais.'), findsOneWidget);
    expect(tester.widget<TextField>(_champCode).controller!.text, isEmpty);
    expect(_compte.email, isNull);
  });

  testWidgets('le bon code enregistre l\'adresse, et l\'on revient', (
    tester,
  ) async {
    await _ouvrir(tester);
    await _demanderCode(tester, 'awa@exemple.ml');

    await tester.enterText(_champCode, _bonCode);
    await _avancer(tester);

    expect(_compte.codes, [_bonCode]);
    expect(_compte.email, 'awa@exemple.ml');
    expect(
      find.text('Adresse vérifiée et enregistrée : awa@exemple.ml'),
      findsOneWidget,
    );
    // Les deux écrans se sont refermés : on est revenu au départ.
    expect(find.text('OUVRIR'), findsOneWidget);
  });

  testWidgets('« Renvoyer » attend son délai, puis renvoie', (tester) async {
    await _ouvrir(tester);
    await _demanderCode(tester, 'awa@exemple.ml');

    final renvoyer = find.widgetWithText(OutlinedButton, 'Renvoyer');
    expect(tester.widget<OutlinedButton>(renvoyer).onPressed, isNull);

    await tester.pump(const Duration(seconds: 30));
    expect(find.text('Renvoyer le code dans 0:30'), findsOneWidget);
    await tester.pump(const Duration(seconds: 31));
    await _avancer(tester);
    expect(tester.widget<OutlinedButton>(renvoyer).onPressed, isNotNull);

    await tester.tap(renvoyer);
    await _avancer(tester);

    expect(_compte.demandes, ['awa@exemple.ml', 'awa@exemple.ml']);
    expect(
      find.text('Un nouveau code est parti à awa@exemple.ml.'),
      findsOneWidget,
    );
    expect(find.text('Renvoyer le code dans 1:00'), findsOneWidget);
  });

  testWidgets('« Changer d\'adresse » revient sans rien enregistrer', (
    tester,
  ) async {
    await _ouvrir(tester);
    await _demanderCode(tester, 'awa@exemple.ml');

    await _toucher(tester, 'Changer d\'adresse');

    expect(find.text('Code de vérification'), findsNothing);
    expect(find.text('Adresse e-mail'), findsWidgets);
    expect(_compte.email, isNull);
  });

  testWidgets('un refus du serveur se lit, et l\'on reste', (tester) async {
    await _ouvrir(tester);
    _compte.refusDemande = const ValidationException(
      'Cette adresse est déjà utilisée par un autre compte.',
    );

    await _demanderCode(tester, 'moussa@exemple.ml');

    expect(
      find.text('Cette adresse est déjà utilisée par un autre compte.'),
      findsOneWidget,
    );
    expect(find.text('Code de vérification'), findsNothing);
  });

  testWidgets('une ancienne adresse jamais vérifiée se vérifie telle quelle', (
    tester,
  ) async {
    await _ouvrir(tester, email: 'ancienne@exemple.ml');

    expect(find.textContaining('jamais vérifiée'), findsOneWidget);
    await _toucher(tester, 'Vérifier cette adresse');

    expect(_compte.demandes, ['ancienne@exemple.ml']);
    expect(find.text('Code de vérification'), findsOneWidget);
  });

  testWidgets('une adresse vérifiée et inchangée n\'a rien à renvoyer', (
    tester,
  ) async {
    await _ouvrir(tester, email: 'awa@exemple.ml', verifiee: true);

    expect(find.textContaining('vérifiée'), findsOneWidget);
    final bouton = find.widgetWithText(MtcPrimaryButton, 'Recevoir un code');
    expect(tester.widget<MtcPrimaryButton>(bouton).onPressed, isNull);
  });

  testWidgets('retirer son adresse se confirme', (tester) async {
    await _ouvrir(tester, email: 'awa@exemple.ml', verifiee: true);

    await _toucher(tester, 'Retirer cette adresse');
    expect(find.text('Retirer votre adresse e-mail ?'), findsOneWidget);
    await _toucher(tester, 'Retirer');

    expect(_compte.retraits, [null]);
    expect(find.text('Adresse e-mail retirée.'), findsOneWidget);
  });

  testWidgets('ouvert sans demande, l\'écran du code le dit', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ContactEmailCodeScreen(request: null),
        ),
      ),
    );
    await _avancer(tester);

    expect(find.text('Aucun code demandé'), findsOneWidget);
  });
}
