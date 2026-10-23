library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mtc_app/app/app.dart';
import 'package:mtc_app/app/session_scope.dart';
import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:mtc_app/features/promo_codes/presentation/providers/applied_promo_code_provider.dart';

import '../../../test/support/supabase_test_harness.dart';

/// Passe l'écran de lancement puis l'accueil, jusqu'à la connexion.
Future<void> _entrer(WidgetTester tester) async {
  // L'accueil anime une balle en continu : pumpAndSettle n'aboutirait
  // jamais, on avance donc par durées fixes.
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.tap(find.text('Commencer'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _login(WidgetTester tester, String usernameOrPhone) async {
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), usernameOrPhone);
  await tester.enterText(fields.at(1), 'password123');
  await tester.tap(find.text('Se connecter'));
  await tester.pump();
  await tester.pumpAndSettle(const Duration(seconds: 1));
}

// L'app réelle, montée comme `bootstrap.dart` la monte : un conteneur de
// providers par compte (`SessionScope`). Un client se déconnecte, un
// fournisseur se connecte sur le même appareil : il doit arriver sur son
// tableau de bord sans rien hériter du client, et sans erreur pendant le
// changement.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await resetAndSeed();
  });

  testWidgets('un client se déconnecte, un fournisseur se connecte sur le '
      'même appareil', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    // Un seul client Supabase, comme `Supabase.instance.client` dans l'app :
    // c'est lui qui porte la session d'un conteneur à l'autre.
    final client = createTestSupabaseClient();
    final conteneurs = <ProviderContainer>[];

    await tester.pumpWidget(
      SessionScope(
        createContainer: () => ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            supabaseClientProvider.overrideWithValue(client),
          ],
        ),
        onContainerChanged: conteneurs.add,
        child: const MtcApp(),
      ),
    );
    await _entrer(tester);
    await _login(tester, 'client1');
    // L'accueil du kit : ses catégories sont en tête de page.
    expect(find.text('Catégories'), findsOneWidget);

    // Un état du client qui ne passe par aucune requête : le code promo
    // qu'il a tapé.
    conteneurs.last.read(typedPromoCodeProvider.notifier).state = 'SOLDES';

    // Ce qu'appelle le bouton « Déconnexion ».
    await conteneurs.last.read(authControllerProvider.notifier).logout();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(conteneurs, hasLength(2), reason: 'un conteneur neuf');
    expect(conteneurs.last.read(typedPromoCodeProvider), isEmpty);

    await _entrer(tester);
    await _login(tester, 'fournisseur1');
    expect(find.text('Bienvenue, Bogolan Bamako'), findsOneWidget);
    expect(conteneurs, hasLength(2), reason: 'se connecter ne recrée rien');

    // L'ancien conteneur se libère sans erreur.
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });
}
