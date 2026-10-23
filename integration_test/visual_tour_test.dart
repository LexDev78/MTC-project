library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:mtc_app/features/catalog/presentation/screens/product_detail_screen.dart';
import 'package:mtc_app/core/shop/shop.dart';

import '../test/support/supabase_test_harness.dart';
import 'support/parcours_visuel.dart';

/// Parcours visuel : traverse les écrans principaux des deux rôles en
/// prenant une capture à chaque étape, pour une relecture humaine de
/// l'apparence réelle — ce que les autres tests d'intégration, qui ne
/// vérifient que des comportements, ne montrent pas.
///
/// Lancé via `flutter drive` (voir `test_driver/integration_test.dart`,
/// qui écrit les PNG) :
///   flutter drive --driver=test_driver/integration_test.dart \
///     --target=integration_test/visual_tour_test.dart -d `<simulateur>`
///
/// Pour le détail d'un seul parcours plutôt que la largeur de celui-ci, voir
/// `focus_variantes_test.dart`.
///
/// Chaque étape est isolée : une navigation qui échoue n'interrompt pas le
/// parcours — elle est signalée, sa capture est prise quand même (l'état
/// réel au moment de l'échec) et les suivantes aussi. Un test qui s'arrête à
/// la première difficulté ne livrerait qu'une poignée d'images, alors que
/// l'intérêt est justement d'en avoir un jeu complet à parcourir. Les
/// helpers communs (dont le piège du `pumpAndSettle`) vivent dans
/// `support/parcours_visuel.dart`.
void main() {
  binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await resetAndSeed();
  });

  // Garde-fou : même sans `pumpAndSettle`, un parcours visuel ne doit
  // jamais pouvoir immobiliser le simulateur. Au-delà, le test échoue au
  // lieu d'attendre.
  testWidgets(
    'parcours visuel — côté client',
    timeout: const Timeout(Duration(minutes: 4)),
    (tester) async {
      echecs.clear();
      await demarrer(tester);
      await capture(tester, 'client-01-bienvenue');

      await etapeVisuelle(tester, 'client-02-connexion', () async {
        await tester.tap(find.text('Commencer'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      });

      await etapeVisuelle(tester, 'client-03-accueil', () async {
        final champs = find.byType(TextFormField);
        await tester.enterText(champs.at(0), 'client1');
        await tester.enterText(champs.at(1), 'password123');
        await tester.tap(find.text('Se connecter'));
        await avancer(tester, pas: 12);
        await attendre(tester, find.byType(ShopProductCard));
      });

      // L'accueil du kit n'a plus d'onglets par type de fournisseur : les
      // fournisseurs tiers ont leur rangée, plus bas.
      await etapeVisuelle(tester, 'client-04-fournisseurs-tiers', () async {
        // Loin dans la page : une liste ne construit pas ce qui est sous le
        // pli, il faut y descendre avant de la cadrer.
        final rangee = find.text('Fournisseurs tiers');
        await tester.scrollUntilVisible(
          rangee.last,
          300,
          scrollable: find
              .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
              )
              .first,
        );
        await cadrer(tester, rangee.last);
      });

      // Viser la carte produit, pas `Image.first` : la première image de
      // l'arbre est celle de la bannière promo, dont le tap ne mène nulle
      // part — le premier jet de ce parcours capturait donc l'accueil une
      // troisième fois en croyant montrer la fiche produit.
      await etapeVisuelle(tester, 'client-05-fiche-produit', () async {
        await tester.tap(find.byType(ShopProductCard).first);
        await avancer(tester, pas: 10);
        await attendre(tester, find.byType(ProductDetailScreen));
        // Sans cette vérification, une navigation qui n'a pas eu lieu
        // passerait inaperçue : la capture montrerait l'écran précédent
        // sous un nom qui promet autre chose.
        expect(find.byType(ProductDetailScreen), findsOneWidget);
      });

      await etapeVisuelle(tester, 'client-06-retour-accueil', () async {
        final retour = find.byTooltip('Back');
        if (retour.evaluate().isNotEmpty) {
          await tester.tap(retour.first);
          await avancer(tester, pas: 8);
        }
      });

      for (final onglet in ['Découvrir', 'Favoris', 'Panier', 'Profil']) {
        await etapeVisuelle(
          tester,
          'client-${onglet.toLowerCase()}',
          () => ouvrirOnglet(tester, onglet),
        );
      }

      if (echecs.isNotEmpty) {
        debugPrint('ÉTAPES EN ÉCHEC (client) :\n${echecs.join('\n')}');
      }
    },
  );

  testWidgets(
    'parcours visuel — côté fournisseur',
    timeout: const Timeout(Duration(minutes: 4)),
    (tester) async {
      echecs.clear();
      await demarrer(tester);

      await etapeVisuelle(tester, 'fournisseur-01-tableau-de-bord', () async {
        await seConnecter(tester, 'fournisseur1');
        // L'écran de lancement (dégradé de marque plein écran) reste visible
        // derrière la coquille qui glisse : sans cette attente, la capture
        // tombait en plein milieu de la transition — une fois entièrement
        // sur le dégradé, une autre avec une bande violette au bord gauche
        // qu'on prendrait volontiers pour un défaut d'affichage.
        await attendre(tester, find.text('Tableau de bord'));
      });

      for (final onglet in [
        'Produits',
        'Commandes',
        'Messages',
        'Finances',
        'Profil',
      ]) {
        await etapeVisuelle(
          tester,
          'fournisseur-${onglet.toLowerCase()}',
          () => ouvrirOnglet(tester, onglet),
        );
      }

      if (echecs.isNotEmpty) {
        debugPrint('ÉTAPES EN ÉCHEC (fournisseur) :\n${echecs.join('\n')}');
      }
    },
  );
}
