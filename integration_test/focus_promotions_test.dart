library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:mtc_app/features/catalog/presentation/screens/product_detail_screen.dart';
import 'package:mtc_app/features/catalog/presentation/widgets/product_card.dart';

import '../test/support/supabase_test_harness.dart';
import 'support/parcours_visuel.dart';

/// Focus « promotions » : le fournisseur pose deux remises sur un produit,
/// puis le client les voit sur la vignette, sur la fiche, et dans son
/// panier.
///
///   flutter drive --driver=test_driver/integration_test.dart \
///     --target=integration_test/focus_promotions_test.dart -d `<simulateur>`
///
/// C'est le seul endroit où la feuille de gestion des remises, l'aperçu de
/// prix qu'elle calcule, le badge de la vignette et l'incitation au palier
/// suivant se voient réellement en image. Les tests de logique
/// (`promotion_pricing_test.dart`, `promotion_checkout_test.dart`)
/// garantissent les montants ; eux ne disent rien de ce que l'écran montre.
///
/// Deux remises et non une, parce que c'est leur **coexistence** qui est
/// difficile à lire : une remise immédiate et une remise sur quantité
/// donnent un prix différent selon ce que le client met au panier, et la
/// vignette doit annoncer la seconde sans mentir sur le prix de la première.
const _produit = 'Tissu Bogolan traditionnel';

/// Remonte jusqu'à la coquille à onglets.
///
/// La fiche produit **et** l'écran de recherche sont deux routes poussées :
/// aucune des deux ne porte la barre de navigation, et un `pageBack` unique
/// laisse donc sur la seconde. On remonte tant que l'onglet cherché n'est
/// pas là plutôt que de compter les écrans.
Future<void> revenirAuShell(WidgetTester tester, String infobulle) async {
  for (var i = 0; i < 3; i++) {
    if (find.byTooltip(infobulle).evaluate().isNotEmpty) return;
    await tester.pageBack();
    await avancer(tester, pas: 5);
  }
}

Future<void> toucher(WidgetTester tester, Finder cible, {int pas = 6}) async {
  final unique = cible.first;
  await tester.ensureVisible(unique);
  await tester.pump();
  await tester.tap(unique);
  await avancer(tester, pas: pas);
}

/// Un passage complet du formulaire « Nouvelle promotion ».
Future<void> creerPromotion(
  WidgetTester tester, {
  required int pourcentage,
  required int desQuantite,
  String? intitule,
}) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Remise (%)').first,
    '$pourcentage',
  );
  await avancer(tester, pas: 2);
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Dès x unités').first,
    '$desQuantite',
  );
  await avancer(tester, pas: 2);
  if (intitule != null) {
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Intitulé (facultatif)').first,
      intitule,
    );
    await avancer(tester, pas: 2);
  }
}

void main() {
  binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await resetAndSeed();
  });

  testWidgets(
    'focus promotions — le fournisseur remise, le client paie moins',
    timeout: const Timeout(Duration(minutes: 12)),
    (tester) async {
      echecs.clear();
      await demarrer(tester);

      // ---- côté fournisseur -------------------------------------------
      await etapeVisuelle(tester, 'promos-01-produits', () async {
        await seConnecter(tester, 'fournisseur1');
        await ouvrirOnglet(tester, 'Produits');
        await attendre(tester, find.text(_produit));
        expect(find.text(_produit), findsWidgets);
      });

      await etapeVisuelle(tester, 'promos-02-section-vide', () async {
        await toucher(tester, find.text(_produit), pas: 10);
        await attendre(tester, find.text('Promotions'));
        await cadrer(tester, find.text('Aucune promotion en cours.'));
        expect(find.text('Créer une promotion'), findsOneWidget);
      });

      await etapeVisuelle(tester, 'promos-03-feuille-vide', () async {
        await toucher(tester, find.text('Créer une promotion'), pas: 10);
        await attendre(tester, find.text('Nouvelle promotion'));
        expect(find.textContaining('prix de base'), findsOneWidget);
      });

      // L'aperçu est le vrai contrôle de saisie : c'est lui qu'on vient
      // regarder, pas le pourcentage tapé.
      await etapeVisuelle(tester, 'promos-04-apercu-prix', () async {
        await creerPromotion(
          tester,
          pourcentage: 15,
          desQuantite: 1,
          intitule: 'Rentrée',
        );
        expect(find.textContaining('Dès la première unité'), findsOneWidget);
      });

      await etapeVisuelle(tester, 'promos-05-premiere-posee', () async {
        await toucher(tester, find.text('Créer la promotion'), pas: 12);
        await attendre(tester, find.text('En cours'));
        expect(find.text('Rentrée'), findsWidgets);
      });

      // La seconde remise, conditionnée à la quantité : c'est la
      // coexistence des deux qui se lit mal, et que la feuille doit
      // expliquer (« le client paie la plus avantageuse »).
      await etapeVisuelle(tester, 'promos-06-deux-remises', () async {
        await creerPromotion(
          tester,
          pourcentage: 20,
          desQuantite: 10,
          intitule: 'Gros volume',
        );
        await toucher(tester, find.text('Créer la promotion'), pas: 12);
        await attendre(tester, find.text('Gros volume'));
        await cadrer(tester, find.textContaining('ne s\'additionnent pas'));
        expect(find.text('Gros volume'), findsWidgets);
      });

      // ---- côté client -------------------------------------------------
      // Deux retours en arrière : la feuille des promotions, puis le
      // formulaire produit. Et l'onglet se nomme « Profil », pas « Compte ».
      await etapeVisuelle(tester, 'promos-07-deconnexion', () async {
        await revenirAuShell(tester, 'Profil');
        await ouvrirOnglet(tester, 'Profil');
        await toucher(tester, find.text('Déconnexion'), pas: 12);
        await attendre(tester, find.text('Connectez-vous pour continuer'));
        expect(find.text('Connectez-vous pour continuer'), findsOneWidget);
      });

      // Par la recherche plutôt que par le flux d'accueil : la vignette
      // cherchée y est seule à l'écran, donc la capture montre le badge
      // sans ambiguïté.
      await etapeVisuelle(tester, 'promos-08-vignette', () async {
        await seConnecter(tester, 'client1');
        await attendre(tester, find.text('Rechercher un produit...'));
        await toucher(tester, find.text('Rechercher un produit...'));
        await tester.enterText(find.byType(TextField).first, 'Bogolan tradition');
        await avancer(tester, pas: 10);
        await attendre(tester, find.byType(ProductCard));
        // Le badge annonce le meilleur palier (-20% dès 10) alors que le
        // prix affiché reste celui d'une unité (-15%) : une vignette qui
        // annoncerait -20% sur son prix mentirait.
        expect(find.textContaining('-20%'), findsWidgets);
      });

      await etapeVisuelle(tester, 'promos-09-fiche-une-unite', () async {
        await toucher(tester, find.byType(ProductCard).first, pas: 12);
        await attendre(tester, find.byType(ProductDetailScreen));
        expect(find.textContaining('unités pour'), findsOneWidget);
      });

      // Dix unités : le prix doit basculer sur l'autre remise, et
      // l'incitation disparaître puisqu'il n'y a plus de palier à atteindre.
      await etapeVisuelle(tester, 'promos-10-fiche-dix-unites', () async {
        for (var i = 0; i < 9; i++) {
          await toucher(tester, find.byIcon(Icons.add_rounded).first, pas: 2);
        }
        expect(find.textContaining('Encore'), findsNothing);
      });

      // La fiche est une route poussée : sa barre d'onglets n'existe pas
      // tant qu'on ne l'a pas quittée.
      await etapeVisuelle(tester, 'promos-11-panier', () async {
        await toucher(tester, find.text('Ajouter au panier'), pas: 12);
        await revenirAuShell(tester, 'Panier');
        await ouvrirOnglet(tester, 'Panier');
        await attendre(tester, find.textContaining('Bogolan'));
        expect(find.textContaining('Bogolan'), findsWidgets);
      });

      expect(echecs, isEmpty, reason: echecs.join('\n'));
    },
  );
}
