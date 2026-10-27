library;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/support/supabase_test_harness.dart';
import 'support/parcours_visuel.dart';

/// Focus « adresse » : poser un vrai point sur la carte.
///
///   flutter drive --driver=test_driver/integration_test.dart \
///     --target=integration_test/focus_adresse_test.dart -d `<simulateur>`
///
/// Ce que ce parcours remplace : l'app lisait le **nom de la ville** et
/// prenait ses coordonnées de centre. Toutes les adresses d'une même ville
/// atterrissaient au même endroit, et le livreur était envoyé du centre-ville
/// au centre-ville quelle que soit la commande.
void main() {
  binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await resetAndSeed();
  });

  testWidgets(
    'focus adresse — le client place sa porte sur la carte',
    timeout: const Timeout(Duration(minutes: 8)),
    (tester) async {
      echecs.clear();
      await demarrer(tester);

      await etapeVisuelle(tester, 'adresse-01-formulaire', () async {
        await seConnecter(tester, 'client1');
        await ouvrirOnglet(tester, 'Profil');
        await attendre(tester, find.text('Mes adresses'));
        await tester.tap(find.text('Mes adresses'));
        await avancer(tester, pas: 8);
        // Le bouton en pointillés de la maquette « Address » du kit.
        await tester.tap(find.text('Ajouter une adresse'));
        await avancer(tester, pas: 8);
        await attendre(tester, find.text('Placer sur la carte'));
        expect(find.text('Placer sur la carte'), findsOneWidget);
      });

      await etapeVisuelle(tester, 'adresse-02-selecteur', () async {
        await tester.tap(find.text('Placer sur la carte'));
        await avancer(tester, pas: 16);
        await attendre(tester, find.text('Confirmer ce point'));
        expect(find.text('Confirmer ce point'), findsOneWidget);
      });

      // Déplacer la carte sous le repère, comme le ferait un pouce : le point
      // retenu doit suivre, c'est tout le principe de ce sélecteur.
      await etapeVisuelle(tester, 'adresse-03-carte-deplacee', () async {
        final avant = _coordonneesAffichees(tester);
        await tester.drag(find.byType(FlutterMap), const Offset(-120, -90));
        await avancer(tester, pas: 8);
        final apres = _coordonneesAffichees(tester);
        expect(
          apres,
          isNot(avant),
          reason:
              'Le point retenu ($apres) n\'a pas suivi le déplacement de la '
              'carte : le repère ne désigne pas ce qu\'il montre.',
        );
      });

      await etapeVisuelle(tester, 'adresse-04-point-enregistre', () async {
        await tester.tap(find.text('Confirmer ce point'));
        await avancer(tester, pas: 10);
        await attendre(tester, find.textContaining('Point enregistré'));
        expect(find.textContaining('Point enregistré'), findsOneWidget);
      });

      if (echecs.isNotEmpty) {
        debugPrint('ÉTAPES EN ÉCHEC (adresse) :\n${echecs.join('\n')}');
      }
      expect(echecs, isEmpty, reason: 'Étapes du focus adresse en échec');
    },
  );
}

/// Les coordonnées que le sélecteur affiche sous la carte — le seul endroit
/// où le point retenu est lisible dans l'arbre de widgets.
String _coordonneesAffichees(WidgetTester tester) {
  return tester
      .widgetList<Text>(find.textContaining(','))
      .map((t) => t.data!)
      .firstWhere((d) => RegExp(r'^-?\d+\.\d{5}, -?\d+\.\d{5}$').hasMatch(d));
}
