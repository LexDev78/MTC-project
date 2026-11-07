library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:mtc_app/core/auth/pseudo_email.dart';
import 'package:mtc_app/features/delivery/data/datasources/supabase_delivery_datasource.dart';
import 'package:mtc_app/features/delivery/data/repositories/supabase_delivery_repository.dart';

import '../test/support/supabase_test_harness.dart';
import 'support/parcours_visuel.dart';

/// Focus « suivi client » : ce que voit l'acheteur pendant que son colis est
/// en route.
///
///   flutter drive --driver=test_driver/integration_test.dart \
///     --target=integration_test/focus_suivi_client_test.dart -d `<simulateur>`
///
/// Le livreur est joué **hors interface**, par une session Supabase ordinaire
/// : l'app ne peut afficher qu'un compte à la fois, et c'est le client qu'on
/// vient regarder. Les appels utilisés sont exactement ceux de l'app livreur
/// (mêmes RPC, mêmes règles d'accès), pas des raccourcis d'administration.
const _groupe = 'ca322249-2d39-5557-b97e-2e67eaeb4131';
const _livreur1 = 'f1c4e8a2-0000-5000-9000-000000000001';

void main() {
  binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await resetAndSeed();
  });

  testWidgets(
    'focus suivi client — le colis en route, sur la carte',
    timeout: const Timeout(Duration(minutes: 10)),
    (tester) async {
      echecs.clear();

      // ---- décor : une course acceptée, un livreur en chemin --------------
      final courierClient = createTestSupabaseClient();
      await courierClient.auth.signInWithPassword(
        email: pseudoEmail('livreur1'),
        password: 'password123',
      );
      final asCourier = SupabaseDeliveryRepository(
        SupabaseDeliveryDatasource(courierClient),
      );
      await asCourier.setOnline(
        courierId: _livreur1,
        isOnline: true,
        latitude: 12.6392,
        longitude: -8.0029,
      );
      await adminSetGroupStatus(groupId: _groupe, status: 'preparing');
      await adminSetGroupStatus(groupId: _groupe, status: 'in_transit');
      final offered = await asCourier.watchForCourier(_livreur1).first;
      await asCourier.accept(offered.single.id);
      // Le livreur part **de la boutique**. Un départ à mi-chemin ne laisse
      // pas assez de trajet pour que l'arrivée estimée, arrondie à la minute
      // par le moteur de routage, bouge de façon mesurable plus bas.
      await asCourier.pushPosition(latitude: 12.6392, longitude: -8.0029);

      await demarrer(tester);

      await etapeVisuelle(tester, 'suivi-01-profil', () async {
        await seConnecter(tester, 'client1');
        await ouvrirOnglet(tester, 'Profil');
        await attendre(tester, find.text('Mes commandes'));
      });

      // L'historique range les commandes par étape (maquette « Orders » du
      // kit) : celle d'« Electro Bamako » est sous « En livraison ». Les
      // cartes écrivent la boutique en capitales, comme le kit.
      await etapeVisuelle(tester, 'suivi-02-commandes', () async {
        await tester.tap(find.text('Mes commandes'));
        await avancer(tester, pas: 10);
        await attendre(tester, find.text('En livraison'));
        await tester.tap(find.text('En livraison'));
        await avancer(tester, pas: 10);
        await attendre(tester, find.text('ELECTRO BAMAKO'));
      });

      await etapeVisuelle(tester, 'suivi-03-commande', () async {
        await tester.tap(find.text('ELECTRO BAMAKO').first);
        await avancer(tester, pas: 10);
        await attendre(tester, find.text('Suivre la livraison'));
        expect(find.text('Suivre la livraison'), findsWidgets);
      });

      await etapeVisuelle(tester, 'suivi-04-carte', () async {
        await tester.ensureVisible(find.text('Suivre la livraison').first);
        await tester.pump();
        await tester.tap(find.text('Suivre la livraison').first);
        await avancer(tester, pas: 16);
      });

      // ---- le suivi suit-il vraiment ? ------------------------------------
      // Une capture prouve qu'une carte s'affiche, pas qu'elle se met à jour.
      // On pousse une position bien plus proche du client **pendant que
      // l'écran est ouvert** : si le flux temps réel fonctionne, l'arrivée
      // estimée doit diminuer sans aucune action de l'utilisateur.
      await etapeVisuelle(tester, 'suivi-05-livreur-avance', () async {
        final avant = _etaAffichee(tester);

        await tester.runAsync(
          () => asCourier.pushPosition(latitude: 12.6487, longitude: -7.9935),
        );
        await avancer(tester, pas: 20);

        final apres = _etaAffichee(tester);
        expect(
          apres,
          lessThan(avant),
          reason:
              'Arrivée estimée inchangée ($avant → $apres) : la nouvelle '
              'position n\'est pas remontée jusqu\'à la carte.',
        );
      });

      await courierClient.dispose();

      if (echecs.isNotEmpty) {
        debugPrint('ÉTAPES EN ÉCHEC (suivi) :\n${echecs.join('\n')}');
      }
      expect(echecs, isEmpty, reason: 'Étapes du focus suivi en échec');
    },
  );
}

/// Lit les minutes affichées par le bandeau d'arrivée estimée.
///
/// C'est la seule valeur de l'écran qui dépende de la position du livreur et
/// qui soit lisible dans l'arbre de widgets — la carte, elle, ne dit rien de
/// ce qu'elle peint.
int _etaAffichee(WidgetTester tester) {
  final texte = tester
      .widgetList<Text>(find.textContaining('Arrivée estimée'))
      .first
      .data!;
  return int.parse(RegExp(r'(\d+)').firstMatch(texte)!.group(1)!);
}
