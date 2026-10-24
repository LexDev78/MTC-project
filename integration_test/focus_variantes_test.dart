library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:mtc_app/features/catalog/presentation/screens/product_detail_screen.dart';
import 'package:mtc_app/core/shop/shop.dart';

import '../test/support/supabase_test_harness.dart';
import 'support/parcours_visuel.dart';

/// Focus « variantes » : là où `visual_tour_test.dart` traverse largement
/// tous les écrans principaux, celui-ci suit **un seul** parcours en
/// profondeur, des deux côtés de la même donnée — le fournisseur compose
/// une grille Couleur × Taille à la main, puis le client la choisit sur la
/// fiche produit. C'est le seul endroit où le composeur de variantes, et le
/// filtrage des options côté client (une option inatteignable en
/// combinaison avec la sélection courante passe à 35 % d'opacité), se
/// voient réellement en image.
///
///   flutter drive --driver=test_driver/integration_test.dart \
///     --target=integration_test/focus_variantes_test.dart -d `<simulateur>`
///
/// Même contrat que le parcours large : une étape qui échoue est signalée
/// sans interrompre les suivantes, pour livrer le jeu complet de captures.
/// La différence est le verdict final — `expect(echecs, isEmpty)` à la toute
/// fin, *après* que toutes les captures soient parties au pilote : ce test
/// décrit un parcours précis, dont une étape manquante est une anomalie, pas
/// seulement une image en moins.
///
/// Les trois variantes composées ici le sont par l'interface, pas par un
/// RPC : c'est justement le composeur (dialogue « Ajouter un champ », coût
/// supplémentaire, réutilisation d'une valeur déjà saisie) qui est l'objet
/// du focus.
const _produit = 'Boubou en bogolan brodé';

/// Amène [cible] à l'écran avant de la toucher. Sur un vrai téléphone, le
/// formulaire produit et les dialogues dépassent tous la hauteur visible :
/// un `tap` direct sur un widget hors champ échoue (ou, pire, touche à
/// côté) alors qu'il réussit en test de widget sur une surface géante.
///
/// Attention, le minimum qu'il fait suffit à amener la cible *dans* le
/// viewport, mais pas à la dégager de ce qui le recouvre : sur la fiche
/// produit, une option ramenée au ras du bas se retrouve sous la barre
/// « Acheter / Ajouter au panier », et le tap tombe sur celle-ci. D'où les
/// [cadrer] explicites avant chaque tap du sélecteur de variantes.
Future<void> toucher(WidgetTester tester, Finder cible, {int pas = 6}) async {
  final unique = cible.first;
  await tester.ensureVisible(unique);
  await tester.pump();
  await tester.tap(unique);
  await avancer(tester, pas: pas);
}

/// Un passage complet du dialogue « Ajouter un champ » : type, valeur, et
/// éventuel supplément de prix.
///
/// [valeur] déjà présente dans le pool du produit n'y crée pas de doublon —
/// le dialogue la reconnaît et réutilise l'option existante (voir
/// `_AddFieldDialogState._confirm`) — c'est ce qui permet de recomposer
/// « Rouge » sur une deuxième variante en la retapant simplement.
Future<void> ajouterChamp(
  WidgetTester tester, {
  required String type,
  required String valeur,
  int? supplementFcfa,
}) async {
  await toucher(tester, find.text('Ajouter un champ'));
  await toucher(tester, find.byKey(const Key('add-field-type-dropdown')));
  // `.last` : le menu déroulant ouvert rend le libellé du type une seconde
  // fois (l'élément du menu, par-dessus celui du champ fermé) et c'est
  // celui-là qu'il faut toucher.
  await toucher(tester, find.text(type).last);

  await tester.enterText(
    find.byKey(const Key('add-field-value-input')),
    valeur,
  );
  await avancer(tester, pas: 3);

  if (supplementFcfa != null) {
    await toucher(tester, find.byKey(const Key('add-field-extra-cost-checkbox')));
    await tester.enterText(
      find.byKey(const Key('add-field-delta-input')),
      '$supplementFcfa',
    );
    await avancer(tester, pas: 3);
  }

  // `.last` encore : la liste des produits, toujours montée sous le
  // formulaire, porte elle aussi un bouton « Ajouter » (son bouton
  // flottant) — celui du dialogue est le dernier dans l'arbre.
  await toucher(tester, find.text('Ajouter').last);
}

Future<void> saisirStockVariante(WidgetTester tester, String valeur) async {
  final champ = find
      .widgetWithText(TextFormField, 'Stock pour cette variante')
      .first;
  await tester.ensureVisible(champ);
  await tester.pump();
  await tester.enterText(champ, valeur);
  await avancer(tester, pas: 3);
}

void main() {
  binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await resetAndSeed();
  });

  testWidgets(
    'focus variantes — le fournisseur compose, le client choisit',
    timeout: const Timeout(Duration(minutes: 12)),
    (tester) async {
      echecs.clear();
      await demarrer(tester);

      // ---- côté fournisseur : composer la grille ------------------------
      await etapeVisuelle(tester, 'variantes-01-produits', () async {
        await seConnecter(tester, 'fournisseur1');
        await ouvrirOnglet(tester, 'Produits');
        await attendre(tester, find.textContaining('Boubou'));
        expect(find.textContaining('Boubou'), findsWidgets);
      });

      await etapeVisuelle(tester, 'variantes-02-formulaire', () async {
        await toucher(tester, find.text(_produit), pas: 10);
        await attendre(tester, find.text('Caractéristiques et variantes'));
        // Sans ça, une navigation qui n'a pas eu lieu passerait inaperçue :
        // les captures suivantes montreraient la liste produits sous des
        // noms qui promettent le composeur.
        expect(find.text('Caractéristiques et variantes'), findsOneWidget);
      });

      await etapeVisuelle(tester, 'variantes-03-panneau', () async {
        // Le panneau n'existe qu'une fois le produit complet rechargé
        // (variantes incluses) — un `CircularProgressIndicator` tient la
        // place jusque-là, d'où l'attente sur le bouton plutôt qu'un délai.
        await attendre(tester, find.text('Ajouter une variante'));
        await tester.ensureVisible(find.text('Ajouter une variante').first);
        await avancer(tester, pas: 3);
        expect(find.text('Variantes (1)'), findsOneWidget);
      });

      // Le seed donne à chaque produit une variante « Taille : Standard »
      // (`0020_reseed_characteristic_types.sql`, §13) uniquement pour
      // satisfaire `products_active_requires_variants`. On la retire : sinon
      // les captures côté client montreraient une taille « Standard » de
      // remplissage au milieu d'une vraie grille Couleur × Taille.
      await etapeVisuelle(tester, 'variantes-04-standard-supprimee', () async {
        await toucher(tester, find.byTooltip('Supprimer cette variante'));
        expect(find.text('Variantes (1)'), findsNothing);
      });

      await etapeVisuelle(tester, 'variantes-05-composeur', () async {
        await toucher(tester, find.text('Ajouter une variante'));
        expect(find.text('Nouvelle variante'), findsOneWidget);
      });

      await etapeVisuelle(tester, 'variantes-06-champ-couleur', () async {
        await toucher(tester, find.text('Ajouter un champ'));
        await toucher(tester, find.byKey(const Key('add-field-type-dropdown')));
        await toucher(tester, find.text('Couleur').last);
        await tester.enterText(
          find.byKey(const Key('add-field-value-input')),
          'Rouge',
        );
        await avancer(tester, pas: 3);
        await toucher(
          tester,
          find.byKey(const Key('add-field-extra-cost-checkbox')),
        );
        await tester.enterText(
          find.byKey(const Key('add-field-delta-input')),
          '2000',
        );
        // Capture le dialogue *rempli* avant de le valider : le supplément
        // de prix d'une valeur ne se voit nulle part ailleurs.
        await avancer(tester, pas: 3);
      });

      await etapeVisuelle(tester, 'variantes-07-deux-champs', () async {
        await toucher(tester, find.text('Ajouter').last);
        await ajouterChamp(tester, type: 'Taille', valeur: 'M');
        expect(find.textContaining('Couleur : Rouge'), findsOneWidget);
        expect(find.textContaining('Taille : M'), findsOneWidget);
      });

      await etapeVisuelle(tester, 'variantes-08-premiere-variante', () async {
        await saisirStockVariante(tester, '4');
        await toucher(tester, find.text('Ajouter cette variante'));
        expect(find.text('Variantes (1)'), findsOneWidget);
      });

      // Deux variantes de plus, sans capture intermédiaire : ce sont les
      // mêmes écrans que ci-dessus. Elles existent pour que le client ait
      // de quoi filtrer — « Rouge » en M et L, « Bleu » en M seulement,
      // donc la taille L devient inatteignable dès que Bleu est choisi.
      await etapeVisuelle(tester, 'variantes-09-trois-variantes', () async {
        await toucher(tester, find.text('Ajouter une variante'));
        await ajouterChamp(tester, type: 'Couleur', valeur: 'Rouge');
        await ajouterChamp(tester, type: 'Taille', valeur: 'L');
        await saisirStockVariante(tester, '7');
        await toucher(tester, find.text('Ajouter cette variante'));

        await toucher(tester, find.text('Ajouter une variante'));
        await ajouterChamp(tester, type: 'Couleur', valeur: 'Bleu');
        await ajouterChamp(tester, type: 'Taille', valeur: 'M');
        await saisirStockVariante(tester, '2');
        await toucher(tester, find.text('Ajouter cette variante'));

        expect(find.text('Variantes (3)'), findsOneWidget);
      });

      await etapeVisuelle(tester, 'variantes-10-enregistre', () async {
        await toucher(tester, find.text('Enregistrer'), pas: 12);
        // `_submit` ne referme le formulaire qu'en cas de succès : s'il
        // reste ouvert, la capture montre l'erreur telle quelle.
        await attendreDisparition(
          tester,
          find.text('Caractéristiques et variantes'),
        );
        expect(find.text('Caractéristiques et variantes'), findsNothing);
      });

      // ---- côté client : choisir dans la grille -------------------------
      // `logout()` renvoie sur l'écran de connexion, pas sur l'accueil :
      // c'est « Bon retour ! » qui signe le retour à l'état déconnecté, pas
      // « Bienvenue ! » (qui n'existe que sur l'accueil du démarrage).
      await etapeVisuelle(tester, 'variantes-11-deconnexion', () async {
        await ouvrirOnglet(tester, 'Profil');
        await toucher(tester, find.text('Déconnexion'), pas: 12);
        await attendre(tester, find.text('Bon retour !'));
        expect(find.text('Bon retour !'), findsOneWidget);
      });

      await etapeVisuelle(tester, 'variantes-12-recherche', () async {
        await seConnecter(tester, 'client1');
        await chercher(tester, 'Boubou');
        await attendre(tester, find.byType(ShopProductCard));
        expect(find.byType(ShopProductCard), findsWidgets);
      });

      await etapeVisuelle(tester, 'variantes-13-fiche-variantes', () async {
        await toucher(tester, find.byType(ShopProductCard).first, pas: 12);
        await attendre(tester, find.byType(ProductDetailScreen));
        expect(find.byType(ProductDetailScreen), findsOneWidget);
        // Le sélecteur est dans la feuille d'achat du kit, derrière
        // « Acheter ». La variante par défaut est la première composée
        // (Rouge M) : il arrive donc déjà sur « Rouge » et « M ».
        await toucher(tester, find.text('Acheter'), pas: 8);
        await attendre(tester, find.text('Bleu'));
        await cadrer(tester, find.text('Taille'));
      });

      // Le filtrage, en une image : « Bleu » n'existe qu'en M, donc choisir
      // Bleu doit faire passer la taille L en estompé (opacité 0,35, chip
      // non cliquable) au lieu de la laisser proposée comme si elle était
      // disponible.
      //
      // L'ordre des deux taps n'est pas interchangeable, et un premier jet
      // l'avait inversé : en choisissant L d'abord, c'est « Bleu » qui
      // devient inatteignable (il n'existe pas en L) — le tap suivant ne
      // faisait donc rien et la capture montrait toujours Rouge L.
      await etapeVisuelle(tester, 'variantes-14-couleur-bleu', () async {
        await cadrer(tester, find.text('Taille'));
        await toucher(tester, find.text('Bleu'), pas: 8);
        await cadrer(tester, find.text('Taille'));
      });

      // Et le filtrage dans l'autre sens : retour sur Rouge (toujours
      // atteignable en M), puis L — c'est « Bleu » qui s'estompe.
      await etapeVisuelle(tester, 'variantes-15-rouge-taille-l', () async {
        await cadrer(tester, find.text('Taille'));
        await toucher(tester, find.text('Rouge'), pas: 8);
        await cadrer(tester, find.text('Taille'));
        await toucher(tester, find.text('L'), pas: 8);
        await cadrer(tester, find.text('Taille'));
      });

      if (echecs.isNotEmpty) {
        debugPrint('ÉTAPES EN ÉCHEC (variantes) :\n${echecs.join('\n')}');
      }
      expect(
        echecs,
        isEmpty,
        reason:
            'Étapes du focus variantes en échec — les captures déjà prises '
            'restent sur disque pour relecture',
      );
    },
  );
}
