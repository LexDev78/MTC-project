library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/support/supabase_test_harness.dart';
import 'support/parcours_visuel.dart';

/// Focus « fournisseur » : tout ce qui a changé sur son interface.
///
///   flutter drive --driver=test_driver/integration_test.dart \
///     --target=integration_test/focus_fournisseur_test.dart -d `<simulateur>`
///
/// Le tableau de bord chiffré, le profil réorganisé en trois sections,
/// l'écran de localisation, les remises (liste, création, modification) et
/// les codes promo avec leur aide repliée et leur sélecteur de produits.
///
/// Aucun de ces écrans n'avait encore été vu : les garanties posées jusque-là
/// sont au niveau des données. Ce parcours regarde ce que montre l'écran,
/// qui est une autre question.

Future<void> toucher(WidgetTester tester, Finder cible, {int pas = 8}) async {
  final unique = cible.first;
  await tester.ensureVisible(unique);
  await tester.pump();
  await tester.tap(unique);
  await avancer(tester, pas: pas);
}

/// Remonte jusqu'à la coquille à onglets, quel que soit le nombre d'écrans
/// empilés — on ne compte pas les retours, on vérifie qu'on est arrivé.
Future<void> revenirAuShell(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    if (find.byTooltip('Profil').evaluate().isNotEmpty) return;
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
    'focus fournisseur — tableau de bord, profil, remises, codes promo',
    timeout: const Timeout(Duration(minutes: 15)),
    (tester) async {
      echecs.clear();
      await demarrer(tester);
      await seConnecter(tester, 'fournisseur1');

      // ---- tableau de bord -------------------------------------------
      await etapeVisuelle(tester, 'fr-01-tableau-de-bord', () async {
        await ouvrirOnglet(tester, 'Tableau de bord');
        await attendre(tester, find.text('Mon activité'));
      });

      await etapeVisuelle(tester, 'fr-02-gains', () async {
        await cadrer(tester, find.text('Gains'), alignement: 0.2);
      });

      await etapeVisuelle(tester, 'fr-03-aide-chiffres', () async {
        await cadrer(tester, find.text('Mon activité'), alignement: 0.2);
        await toucher(tester, find.byIcon(Icons.help_outline_rounded));
      });
      await etapeVisuelle(tester, 'fr-04-apres-aide', () async {
        await toucher(tester, find.text('J\'ai compris'));
      });

      // ---- profil réorganisé ------------------------------------------
      await etapeVisuelle(tester, 'fr-05-profil-haut', () async {
        await ouvrirOnglet(tester, 'Profil');
        await attendre(tester, find.text('Gestion de la boutique'));
      });

      await etapeVisuelle(tester, 'fr-06-profil-sections', () async {
        await cadrer(tester, find.text('Paramètres supplémentaires'),
            alignement: 0.25);
      });

      // ---- localisation ------------------------------------------------
      await etapeVisuelle(tester, 'fr-07-localisation', () async {
        await toucher(tester, find.text('Localisation'));
        await attendre(tester, find.text('Zones de livraison (séparées par '
            'des virgules, optionnel)'));
      });
      await revenirAuShell(tester);

      // ---- remises -----------------------------------------------------
      await etapeVisuelle(tester, 'fr-08-remises-vide', () async {
        await ouvrirOnglet(tester, 'Profil');
        await toucher(tester, find.text('Remises'));
        await attendre(tester, find.text('Nouvelle remise'));
      });

      await etapeVisuelle(tester, 'fr-09-remise-formulaire', () async {
        await toucher(tester, find.text('Nouvelle remise'));
        await attendre(tester, find.text('Sur quels produits ?'));
      });

      await etapeVisuelle(tester, 'fr-10-remise-selecteur', () async {
        await cadrer(tester, find.text('Sur quels produits ?'),
            alignement: 0.15);
      });

      await etapeVisuelle(tester, 'fr-11-remise-recherche', () async {
        // Accents volontairement omis : « bogolan » doit trouver « Bògòlan ».
        final champs = find.widgetWithText(TextFormField, 'Rechercher un produit');
        await tester.enterText(champs.first, 'bogolan');
        await avancer(tester, pas: 5);
      });

      await etapeVisuelle(tester, 'fr-12-remise-posee', () async {
        await toucher(tester, find.text('Tout sélectionner'));
        await toucher(tester, find.text('Poser la remise'), pas: 12);
        await attendre(tester, find.textContaining('produits :'));
      });

      await etapeVisuelle(tester, 'fr-13-remise-modifier', () async {
        await toucher(tester, find.text('Modifier'));
        await attendre(tester, find.text('Modifier la remise'));
      });

      await etapeVisuelle(tester, 'fr-14-remise-aide', () async {
        // « Annuler » et non `pageBack` : une feuille modale n'a pas de
        // bouton retour, et un premier jet est resté bloqué dessus — les
        // six captures suivantes montraient toutes le même écran.
        await toucher(tester, find.text('Annuler'), pas: 8);
        await toucher(tester, find.byIcon(Icons.help_outline_rounded));
      });
      await etapeVisuelle(tester, 'fr-15-apres-aide-remises', () async {
        await toucher(tester, find.text('J\'ai compris'));
      });
      await revenirAuShell(tester);

      // ---- codes promo --------------------------------------------------
      await etapeVisuelle(tester, 'fr-16-codes-promo', () async {
        await ouvrirOnglet(tester, 'Profil');
        await toucher(tester, find.text('Codes promo'));
        await avancer(tester, pas: 8);
      });

      await etapeVisuelle(tester, 'fr-17-code-formulaire', () async {
        // Texte exact : `textContaining('un code')` attrape d'abord le
        // sous-titre de l'état vide — « Créez un code, donnez-le à vos
        // clients » — et le formulaire ne s'ouvrait jamais.
        await toucher(tester, find.text('Créer un code'));
        await attendre(tester, find.text('Rechercher un produit'));
      });

      await etapeVisuelle(tester, 'fr-18-code-selecteur', () async {
        await cadrer(tester, find.text('Rechercher un produit'),
            alignement: 0.2);
      });

      // ---- liste des produits, avec sa recherche -------------------------
      await etapeVisuelle(tester, 'fr-19-produits-recherche', () async {
        // Le formulaire de code promo est posé dans la page, pas en feuille :
        // on le referme par « Annuler » avant de remonter.
        if (find.text('Annuler').evaluate().isNotEmpty) {
          await toucher(tester, find.text('Annuler'), pas: 6);
        }
        await revenirAuShell(tester);
        await ouvrirOnglet(tester, 'Produits');
        // Sans accent, volontairement : « bogolan » doit trouver
        // « Bogolan », et la base comme l'app replient les accents.
        final champ = find.widgetWithText(TextFormField, 'Rechercher un produit');
        await tester.enterText(champ.first, 'bogolan');
        await avancer(tester, pas: 6);
      });

      // Ce que l'écran dit quand rien ne correspond. Un premier jet
      // affichait « Ajoutez votre premier article » à un fournisseur qui en
      // a quatre — il n'avait que mal tapé un nom.
      await etapeVisuelle(tester, 'fr-20-recherche-sans-resultat', () async {
        final champ = find.widgetWithText(TextFormField, 'Rechercher un produit');
        await tester.enterText(champ.first, 'brouette');
        await avancer(tester, pas: 6);
        expect(find.text('Aucun résultat'), findsOneWidget);
      });

      expect(echecs, isEmpty, reason: echecs.join('\n'));
    },
  );
}
