library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/support/supabase_test_harness.dart';
import 'support/parcours_visuel.dart';

/// Focus « livreur » : la vie d'une course vue du livreur, de la prise de
/// service à la feuille de route.
///
///   flutter drive --driver=test_driver/integration_test.dart \
///     --target=integration_test/focus_livreur_test.dart -d `<simulateur>`
///
/// Prérequis, à poser avant `flutter drive` — la permission de localisation
/// est réinitialisée à chaque réinstallation de l'app, et un test Flutter ne
/// peut pas toucher une alerte système :
///
///   xcrun simctl privacy `<id>` grant location com.mtc.mtcApp
///   xcrun simctl location `<id>` set 12.6500,-8.0100
///
/// La remise à la livraison est jouée **en base** (`adminSetGroupStatus`) et
/// non dans l'interface fournisseur : c'est un `update` sur le groupe, donc
/// le trigger qui crée la course se déclenche exactement comme si le
/// fournisseur l'avait fait depuis son écran. Faire autrement obligerait à
/// traverser deux comptes et trois écrans avant d'atteindre le sujet du
/// test, pour un décor que la base pose en une ligne.
const _groupe = 'ca322249-2d39-5557-b97e-2e67eaeb4131';

void main() {
  binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await resetAndSeed();
  });

  testWidgets(
    'focus livreur — prise de service, proposition, acceptation',
    timeout: const Timeout(Duration(minutes: 10)),
    (tester) async {
      echecs.clear();
      await demarrer(tester);

      await etapeVisuelle(tester, 'livreur-01-hors-service', () async {
        await seConnecter(tester, 'livreur1');
        await attendre(tester, find.text('Hors service'));
        expect(find.text('Hors service'), findsOneWidget);
      });

      await etapeVisuelle(tester, 'livreur-02-en-service', () async {
        await tester.tap(find.byType(Switch));
        await avancer(tester, pas: 12);
        await attendre(tester, find.text('En service'));
      });

      // Le fournisseur remet son groupe à la livraison : le trigger crée la
      // course et la propose au livreur en ligne le plus proche.
      await etapeVisuelle(tester, 'livreur-03-proposition', () async {
        await tester.runAsync(() async {
          await adminSetGroupStatus(groupId: _groupe, status: 'preparing');
          await adminSetGroupStatus(groupId: _groupe, status: 'in_transit');
        });
        await attendre(tester, find.text('Accepter la course'), tentatives: 40);
        expect(find.text('Accepter la course'), findsOneWidget);
      });

      await etapeVisuelle(tester, 'livreur-04-acceptee', () async {
        await tester.tap(find.text('Accepter la course'));
        await avancer(tester, pas: 14);
        await attendre(tester, find.text('Course en cours'));
        expect(find.text('Course en cours'), findsOneWidget);
      });

      await etapeVisuelle(tester, 'livreur-05-feuille-de-route', () async {
        await tester.tap(find.text('Course en cours'));
        await avancer(tester, pas: 4);
        // La carte de la course, pas le titre de section.
        await tester.tap(find.textContaining('Electro Bamako').last);
        await avancer(tester, pas: 10);
        await attendre(tester, find.text('1. Retrait'));
        // Les tuiles de la carte arrivent par le réseau : sans cette
        // respiration, la capture montre un cadre vide et ne prouve rien.
        await avancer(tester, pas: 14);
      });

      // Le bloc de remise est sous la carte : on fait défiler pour le
      // vérifier, et la capture sert de second regard sur la feuille.
      await etapeVisuelle(tester, 'livreur-06-remise', () async {
        // Le geste part du bloc « Retrait », pas de la carte : même figée,
        // viser la carte reviendrait à tester autre chose que le défilement.
        await tester.drag(find.text('1. Retrait'), const Offset(0, -420));
        await avancer(tester, pas: 6);
        expect(find.text('2. Remise'), findsOneWidget);
      });

      if (echecs.isNotEmpty) {
        debugPrint('ÉTAPES EN ÉCHEC (livreur) :\n${echecs.join('\n')}');
      }
      expect(
        echecs,
        isEmpty,
        reason: 'Étapes du focus livreur en échec — les captures restent sur disque',
      );
    },
  );
}
