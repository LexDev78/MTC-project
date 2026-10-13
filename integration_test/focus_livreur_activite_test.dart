library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';


import '../test/support/supabase_test_harness.dart';
import 'support/parcours_visuel.dart';

/// Focus « activité du livreur » : son historique de courses, les notes
/// qu'il reçoit, et la feuille par laquelle le client les donne.
///
///   flutter drive --driver=test_driver/integration_test.dart \
///     --target=integration_test/focus_livreur_activite_test.dart \
///     -d `<simulateur>`
///
/// Ce que seules des images disent : que l'historique ne montre **aucune**
/// identité (ni client, ni fournisseur), que le bandeau de cumuls tient sur
/// une ligne, et qu'une note déjà donnée se relit au lieu de reproposer un
/// formulaire vierge.
const _groupe = 'ca322249-2d39-5557-b97e-2e67eaeb4131'; // Electro Bamako
const _livreur1 = 'f1c4e8a2-0000-5000-9000-000000000001';

Future<void> toucher(WidgetTester tester, Finder cible, {int pas = 6}) async {
  final unique = cible.first;
  await tester.ensureVisible(unique);
  await tester.pump();
  await tester.tap(unique);
  await avancer(tester, pas: pas);
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
    await seedDeliveredDeliveryAsAdmin(
      groupId: _groupe,
      courierId: _livreur1,
    );
  });

  testWidgets(
    'focus activité livreur — historique sans identités, et notation',
    timeout: const Timeout(Duration(minutes: 12)),
    (tester) async {
      echecs.clear();
      await demarrer(tester);

      await etapeVisuelle(tester, 'activite-01-historique', () async {
        await seConnecter(tester, 'livreur1');
        await attendre(tester, find.byTooltip('Mon activité'));
        await toucher(tester, find.byTooltip('Mon activité'), pas: 12);
        await attendre(tester, find.text('Livrées'));
        // Aucune identité : ni le nom du client, ni celui du fournisseur.
        expect(find.textContaining('Electro'), findsNothing);
        expect(find.textContaining('Awa'), findsNothing);
      });

      await etapeVisuelle(tester, 'activite-02-notes-vides', () async {
        await toucher(tester, find.text('Notes reçues'), pas: 10);
        await attendre(tester, find.textContaining('Aucune note'));
        expect(find.textContaining('Aucune note'), findsOneWidget);
      });

      // Découpé en trois : un parcours qui se bloque ne dit rien de l'endroit
      // où il se bloque, et une capture par étape le dit tout de suite.
      await etapeVisuelle(tester, 'activite-03a-retour-accueil', () async {
        await tester.pageBack();
        await avancer(tester, pas: 6);
        expect(find.byTooltip('Déconnexion'), findsOneWidget);
      });

      await etapeVisuelle(tester, 'activite-03b-client-connecte', () async {
        await toucher(tester, find.byTooltip('Déconnexion'), pas: 12);
        await seConnecter(tester, 'client1');
        await ouvrirOnglet(tester, 'Profil');
        expect(find.text('Mes commandes'), findsOneWidget);
      });

      // Côté client : la feuille de notation, depuis sa commande livrée.
      await etapeVisuelle(tester, 'activite-03c-feuille-notation', () async {
        await toucher(tester, find.text('Mes commandes'), pas: 12);
        await attendre(tester, find.textContaining('Electro'));
        await toucher(tester, find.textContaining('Electro'), pas: 12);
        await attendre(tester, find.text('Noter le livreur'));
        await toucher(tester, find.text('Noter le livreur'), pas: 10);
        await attendre(tester, find.text('Envoyer la note'));
        expect(find.textContaining('jamais votre nom'), findsOneWidget);
      });

      await etapeVisuelle(tester, 'activite-04-note-donnee', () async {
        // Les cinq étoiles sont vides au départ : la quatrième donne 4/5.
        await toucher(tester, find.byIcon(Icons.star_border_rounded).at(3), pas: 3);
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Commentaire (facultatif)').first,
          'Ponctuel et soigneux, colis en parfait état.',
        );
        await avancer(tester, pas: 3);
        await toucher(tester, find.text('Envoyer la note'), pas: 12);
        // Le bouton rappelle la note donnée : sans cela on la redonnerait en
        // croyant que la première n'est pas partie.
        await attendre(tester, find.textContaining('Livreur noté'));
        expect(find.textContaining('Livreur noté 4/5'), findsOneWidget);
      });

      await etapeVisuelle(tester, 'activite-05-notes-recues', () async {
        await revenirAuShell(tester, 'Profil');
        await ouvrirOnglet(tester, 'Profil');
        await toucher(tester, find.text('Paramètres'), pas: 10);
        await toucher(tester, find.text('Déconnexion'), pas: 12);
        await seConnecter(tester, 'livreur1');
        await attendre(tester, find.byTooltip('Mon activité'));
        await toucher(tester, find.byTooltip('Mon activité'), pas: 12);
        await toucher(tester, find.text('Notes reçues'), pas: 10);
        await attendre(tester, find.textContaining('Ponctuel'));
        // D'où vient la note, jamais de qui.
        expect(find.text('Client'), findsOneWidget);
        expect(find.textContaining('Awa'), findsNothing);
      });

      expect(echecs, isEmpty, reason: echecs.join('\n'));
    },
  );
}
