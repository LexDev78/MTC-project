library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/support/supabase_test_harness.dart';
import 'support/parcours_visuel.dart';

/// Focus « codes promo » : le fournisseur crée un code, le client le saisit
/// au paiement, et le fournisseur retrouve ce qu'il a remisé.
///
///   flutter drive --driver=test_driver/integration_test.dart \
///     --target=integration_test/focus_codes_promo_test.dart -d `<simulateur>`
///
/// La boucle complète en images, parce que c'est elle qui compte : un code
/// n'a de sens que s'il est distribué, saisi, et retrouvé. Les tests
/// (`promo_code_test`, `promo_code_checkout_test`) garantissent les montants
/// et les refus ; eux ne disent rien de ce que les deux écrans montrent.
///
/// Le panier de client2 est pré-semé avec du riz d'Alimentation Ségou
/// (fournisseur6) : le code est donc créé chez ce vendeur, et le parcours
/// n'a pas à composer un panier pour en arriver au paiement.
const _code = 'SEGOU10';

Future<void> toucher(WidgetTester tester, Finder cible, {int pas = 6}) async {
  final unique = cible.first;
  await tester.ensureVisible(unique);
  await tester.pump();
  await tester.tap(unique);
  await avancer(tester, pas: pas);
}

/// Fait défiler jusqu'à [cible] avant de l'attendre.
///
/// Un `ListView` ne construit que ce qui approche de l'écran : sur une page
/// de paiement longue, le champ « Code promo » n'existe pas encore dans
/// l'arbre, et aucune attente ne le fera apparaître. Il faut descendre.
Future<void> faireDefilerJusqua(WidgetTester tester, Finder cible) async {
  for (var i = 0; i < 20 && cible.evaluate().isEmpty; i++) {
    await tester.drag(find.byType(ListView).first, const Offset(0, -260));
    await avancer(tester, pas: 2);
  }
  await avancer(tester, pas: 2);
}

Future<void> revenirAuShell(WidgetTester tester, String infobulle) async {
  for (var i = 0; i < 3; i++) {
    if (find.byTooltip(infobulle).evaluate().isNotEmpty) return;
    await tester.pageBack();
    await avancer(tester, pas: 5);
  }
}

void main() {
  binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await resetAndSeed();
  });

  testWidgets(
    'focus codes promo — créer, saisir, retrouver',
    timeout: const Timeout(Duration(minutes: 12)),
    (tester) async {
      echecs.clear();
      await demarrer(tester);

      // ---- le fournisseur crée un code ---------------------------------
      await etapeVisuelle(tester, 'codes-01-vide', () async {
        await seConnecter(tester, 'fournisseur6');
        await ouvrirOnglet(tester, 'Profil');
        await toucher(tester, find.text('Codes promo'), pas: 10);
        await attendre(tester, find.text('Aucun code promo'));
      });

      // La règle de cumul doit rester dite : un vendeur qui laisse tourner
      // une promotion et distribue un code doit savoir que les deux ne
      // s'additionnent pas. Elle a quitté le corps de l'écran pour la
      // fenêtre d'aide ; ce qui compte est qu'on puisse encore y arriver,
      // pas où elle est posée.
      await etapeVisuelle(tester, 'codes-01b-aide', () async {
        await toucher(tester, find.byIcon(Icons.help_outline_rounded));
        expect(
          find.textContaining('ne s\'additionnent jamais'),
          findsOneWidget,
        );
        await toucher(tester, find.text('J\'ai compris'), pas: 6);
      });

      await etapeVisuelle(tester, 'codes-02-formulaire', () async {
        await toucher(tester, find.text('Créer un code'), pas: 10);
        await attendre(tester, find.text('Nouveau code'));
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Code (ex. RENTREE)').first,
          _code,
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Remise (%)').first,
          '10',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Intitulé (facultatif)').first,
          'Clients fidèles',
        );
        await avancer(tester, pas: 3);
        await cadrer(tester, find.text('Nouveau code'));
        expect(find.textContaining('tous vos produits'), findsOneWidget);
      });

      await etapeVisuelle(tester, 'codes-03-cree', () async {
        await toucher(tester, find.text('Créer le code'), pas: 12);
        await attendre(tester, find.text(_code));
        expect(find.text('En cours'), findsOneWidget);
        expect(find.textContaining('Jamais utilisé'), findsOneWidget);
      });

      // ---- le client le saisit au paiement ------------------------------
      await etapeVisuelle(tester, 'codes-04-paiement', () async {
        await revenirAuShell(tester, 'Profil');
        await ouvrirOnglet(tester, 'Profil');
        await toucher(tester, find.text('Déconnexion'), pas: 12);
        await seConnecter(tester, 'client2');
        await ouvrirOnglet(tester, 'Panier');
        await attendre(tester, find.text('Commander'));
        await toucher(tester, find.text('Commander'), pas: 12);
        await faireDefilerJusqua(tester, find.text('Code promo'));
        expect(find.text('Code promo'), findsWidgets);
      });

      await etapeVisuelle(tester, 'codes-05-applique', () async {
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Code promo').first,
          'segou10',
        );
        await avancer(tester, pas: 3);
        await toucher(tester, find.text('Appliquer le code'), pas: 12);
        // La liste remonte en haut après l'application : l'état appliqué
        // n'est pas construit tant qu'on n'est pas redescendu.
        await faireDefilerJusqua(tester, find.textContaining('appliqué'));
        // La remise se voit en clair dans le récapitulatif, et pas seulement
        // dans un sous-total qui aurait baissé sans explication.
        expect(find.textContaining('Code $_code appliqué'), findsOneWidget);
      });

      await etapeVisuelle(tester, 'codes-06-commande', () async {
        await toucher(tester, find.text('Confirmer la commande'), pas: 16);
      });

      // ---- le fournisseur retrouve ce qu'il a remisé --------------------
      await etapeVisuelle(tester, 'codes-07-utilisation', () async {
        await revenirAuShell(tester, 'Profil');
        await ouvrirOnglet(tester, 'Profil');
        // La déconnexion est en bas du menu du profil, comme dans le kit.
        await toucher(tester, find.text('Déconnexion'), pas: 12);
        await seConnecter(tester, 'fournisseur6');
        await ouvrirOnglet(tester, 'Profil');
        await toucher(tester, find.text('Codes promo'), pas: 12);
        await faireDefilerJusqua(tester, find.textContaining('utilisation'));
        await toucher(tester, find.textContaining('utilisation'), pas: 8);
        await attendre(tester, find.textContaining('Riz'));
        // Ce que le fournisseur vient chercher : quel code, sur quel
        // article, pour combien.
        expect(find.textContaining('Riz'), findsWidgets);
      });

      expect(echecs, isEmpty, reason: echecs.join('\n'));
    },
  );
}
