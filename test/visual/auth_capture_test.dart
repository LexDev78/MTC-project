import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/features/auth/presentation/screens/forgot_password_code_screen.dart';
import 'package:mtc_app/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:mtc_app/features/auth/presentation/screens/login_screen.dart';
import 'package:mtc_app/features/auth/presentation/screens/welcome_screen.dart';

import '../support/shop_capture.dart';

/// L'accueil et la connexion de la charte MTC, rendus sur le téléphone des
/// maquettes (390 × 844 pt, barre d'état de 47 pt) pour les comparer au
/// pixel près ; et la récupération du mot de passe, sous le même thème.

late SharedPreferences _preferences;

Future<void> _avancer(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// La connexion ouverte depuis l'accueil : il y a une page derrière, d'où
/// le bouton de retour des maquettes.
Widget _connexionDepuisAccueil() => Navigator(
  onGenerateInitialRoutes: (_, _) => [
    MaterialPageRoute<void>(builder: (_) => const SizedBox()),
    MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
  ],
);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    _preferences = await SharedPreferences.getInstance();
  });

  List<Override> preferences() => [
    sharedPreferencesProvider.overrideWithValue(_preferences),
  ];

  capturerEcran(
    'accueil',
    () => const WelcomeScreen(),
    largeur: 390,
    hauteur: 844,
    barreEtat: 47,
  );

  capturerEcran(
    'connexion',
    _connexionDepuisAccueil,
    overrides: preferences,
    largeur: 390,
    hauteur: 844,
    barreEtat: 47,
  );

  // La seconde maquette : identifiant saisi, case cochée, mot de passe en
  // cours de saisie (le focus y reste : la case est cochée d'abord).
  capturerEcran(
    'connexion_saisie',
    _connexionDepuisAccueil,
    overrides: preferences,
    largeur: 390,
    hauteur: 844,
    barreEtat: 47,
    geste: (tester) async {
      await tester.tap(find.text('Se souvenir de moi'));
      await _avancer(tester);
      final champs = find.byType(TextFormField);
      await tester.enterText(champs.at(0), 'mariam.k');
      await tester.enterText(champs.at(1), 'motdepass');
      await _avancer(tester);
    },
  );

  capturerEcran(
    'connexion_refusee',
    _connexionDepuisAccueil,
    overrides: preferences,
    largeur: 390,
    hauteur: 844,
    barreEtat: 47,
    geste: (tester) async {
      await tester.ensureVisible(find.text('Se connecter'));
      await tester.pump();
      await tester.tap(find.text('Se connecter'));
      await _avancer(tester);
    },
  );

  // Toute la page, comptes de démonstration ouverts.
  capturerEcran(
    'connexion_page',
    () => const LoginScreen(),
    overrides: preferences,
    hauteur: 1400,
    geste: (tester) async {
      await tester.ensureVisible(find.text('Comptes de démonstration'));
      await tester.pump();
      await tester.tap(find.text('Comptes de démonstration'));
      await _avancer(tester);
    },
  );

  // Un petit téléphone (iPhone SE de première génération).
  capturerEcran(
    'connexion_petit',
    () => const LoginScreen(),
    overrides: preferences,
    largeur: 320,
    hauteur: 568,
    barreEtat: 20,
  );

  capturerEcran(
    'accueil_petit',
    () => const WelcomeScreen(),
    largeur: 320,
    hauteur: 568,
    barreEtat: 20,
  );

  capturerEcran(
    'mdp_oublie',
    () => const ForgotPasswordScreen(identifier: 'awa'),
  );

  capturerEcran(
    'mdp_oublie_code',
    () => ForgotPasswordCodeScreen(
      args: (
        identifier: 'awa',
        request: (
          expiresAt: DateTime(2026, 10, 22, 10, 10),
          resendAfterSeconds: 60,
        ),
      ),
    ),
  );
}
