import 'package:flutter_test/flutter_test.dart';

import 'package:mtc_app/features/auth/presentation/screens/forgot_password_code_screen.dart';
import 'package:mtc_app/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:mtc_app/features/auth/presentation/screens/login_screen.dart';

import '../support/shop_capture.dart';

/// La connexion, reprise de l'écran du kit FlutterShop
/// (`lib/screens/auth/views/login_screen.dart` du kit), et la récupération
/// du mot de passe qu'elle ouvre, sous le même thème.

Future<void> _avancer(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  capturerEcran('connexion', () => const LoginScreen());

  // Toute la page : ce qu'on voit en faisant défiler, comptes de
  // démonstration ouverts.
  capturerEcran(
    'connexion_page',
    () => const LoginScreen(),
    hauteur: 1300,
    geste: (tester) async {
      await tester.tap(find.text('Comptes de démonstration'));
      await _avancer(tester);
    },
  );

  capturerEcran(
    'connexion_refusee',
    () => const LoginScreen(),
    geste: (tester) async {
      await tester.ensureVisible(find.text('Se connecter'));
      await tester.pump();
      await tester.tap(find.text('Se connecter'));
      await _avancer(tester);
    },
  );

  // Moins de 700 points de haut : le kit réduit l'espace avant le bouton.
  capturerEcran('connexion_ecran_bas', () => const LoginScreen(), hauteur: 640);

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
          maskedEmail: 'aw•••@example.com',
          expiresAt: DateTime(2026, 10, 22, 10, 10),
          resendAfterSeconds: 60,
        ),
      ),
    ),
  );
}
