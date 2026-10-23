/// Boîte à outils commune aux tests *visuels* (ceux qui prennent des
/// captures pour une relecture humaine, par opposition aux tests
/// d'intégration qui vérifient des comportements) :
/// `visual_tour_test.dart` (large, un écran après l'autre) et
/// `focus_variantes_test.dart` (étroit, un seul parcours en détail).
///
/// Chaque fichier de test affecte [binding] dans son `main()` avant
/// d'appeler quoi que ce soit d'ici.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mtc_app/app/app.dart';
import 'package:mtc_app/core/di/providers.dart';

import '../../test/support/supabase_test_harness.dart';

late IntegrationTestWidgetsFlutterBinding binding;

/// Étapes dont l'exécution a échoué, remplie par [etapeVisuelle] — à vider
/// en début de test et à relire à la fin.
final List<String> echecs = [];

/// Avance le temps par pas fixes, **jamais** `pumpAndSettle`.
///
/// `WelcomeScreen` porte une animation décorative permanente (ses balles
/// qui rebondissent) qui ne se déclare jamais stabilisée :
/// `pumpAndSettle` y attend jusqu'à son timeout, app figée à l'écran. Les
/// autres tests d'intégration de ce dépôt documentent déjà ce piège et
/// l'évitent de la même façon.
/// `runAsync` est indispensable ici : `pump()` seul n'avance que l'horloge
/// simulée, alors que les écrans attendent de vraies requêtes réseau vers
/// Supabase. Sans lui, les captures arrivent avant les données et montrent
/// des grilles vides — ce qui ferait passer un simple retard d'affichage
/// pour une anomalie. Même motif que les helpers `settle()` des autres
/// tests du dépôt.
Future<void> avancer(
  WidgetTester tester, {
  int pas = 6,
  Duration intervalle = const Duration(milliseconds: 200),
}) async {
  for (var i = 0; i < pas; i++) {
    await tester.runAsync(() => Future<void>.delayed(intervalle));
    await tester.pump();
  }
}

/// Attend qu'un contenu attendu soit réellement présent, plutôt que de
/// parier sur un délai fixe. Sans ça, une capture prise pendant que la
/// requête réseau est encore en vol montre un écran vide et se lit comme
/// une anomalie d'affichage — c'est exactement ce qui est arrivé au premier
/// jet de ce parcours. Borné : si le contenu n'arrive jamais, on capture
/// quand même l'état réel (une grille vide est alors une vraie constatation).
Future<void> attendre(
  WidgetTester tester,
  Finder cible, {
  int tentatives = 25,
}) async {
  for (var i = 0; i < tentatives; i++) {
    if (cible.evaluate().isNotEmpty) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
  }
}

Future<void> capture(WidgetTester tester, String nom) async {
  await avancer(tester, pas: 3);
  await binding.takeScreenshot(nom);
}

/// Exécute [etape] en capturant l'écran à la fin, sans laisser une erreur
/// interrompre le reste du parcours.
///
/// La capture est prise **dans les deux cas**, succès ou échec. Un premier
/// jet ne capturait qu'en cas de succès : la toute première étape du focus
/// variantes a échoué et le parcours entier n'a produit aucune image — donc
/// aucun moyen de voir ce que l'écran montrait à ce moment-là, qui est
/// précisément l'information dont on a besoin. L'étape reste signalée dans
/// [echecs] ; l'image, elle, montre l'état réel au moment de l'échec.
Future<void> etapeVisuelle(
  WidgetTester tester,
  String nom,
  Future<void> Function() etape,
) async {
  try {
    await etape();
  } catch (e) {
    echecs.add('$nom : $e');
  }
  try {
    await capture(tester, nom);
  } catch (e) {
    echecs.add('$nom (capture) : $e');
  }
}

/// Pendant de [attendre] : attend qu'un contenu *disparaisse* (une route qui
/// se referme, un écran de connexion qui cède la place à l'app), borné de la
/// même façon.
Future<void> attendreDisparition(
  WidgetTester tester,
  Finder cible, {
  int tentatives = 25,
}) async {
  for (var i = 0; i < tentatives; i++) {
    if (cible.evaluate().isEmpty) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
  }
}

Future<void> demarrer(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        supabaseClientProvider.overrideWithValue(createTestSupabaseClient()),
      ],
      child: const MtcApp(),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 400));
}

/// Connexion complète, de l'écran d'accueil jusqu'à l'app elle-même.
///
/// Les deux attentes bornées ne sont pas décoratives : un `avancer` à délai
/// fixe après « Se connecter » suffisait au parcours large (qui capturait
/// juste après) mais pas au focus variantes, qui enchaîne aussitôt sur un
/// onglet — 2,4 s plus tard la coquille n'était pas encore montée, et chaque
/// étape suivante tombait en cascade. On attend donc que l'écran de
/// connexion cède réellement la place, au lieu de parier sur une durée.
Future<void> seConnecter(WidgetTester tester, String identifiant) async {
  // Deux portes d'entrée vers le formulaire : l'écran d'accueil au
  // démarrage (bouton « Commencer »), ou directement l'écran de connexion
  // après une déconnexion — `logout()` y renvoie sans repasser par
  // l'accueil. Attendre l'un *ou* l'autre plutôt que de supposer le
  // premier : le focus variantes se reconnecte en client juste après avoir
  // déconnecté le fournisseur, et cherchait « Commencer » sur un écran qui
  // ne l'a jamais eu.
  final accueil = find.text('Commencer');
  final formulaire = find.byType(TextFormField);
  for (var i = 0; i < 25; i++) {
    if (accueil.evaluate().isNotEmpty || formulaire.evaluate().isNotEmpty) break;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
  }
  if (accueil.evaluate().isNotEmpty) {
    await tester.tap(accueil);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }
  await attendre(tester, formulaire);

  final champs = find.byType(TextFormField);
  await tester.enterText(champs.at(0), identifiant);
  await tester.enterText(champs.at(1), 'password123');
  await tester.tap(find.text('Se connecter'));
  await avancer(tester, pas: 12);
  // Borné : si la connexion échoue pour de bon, on repart quand même et
  // c'est la capture de l'étape qui montrera l'écran de connexion resté en
  // place (avec son message d'erreur) plutôt qu'un simple « widget
  // introuvable » plus loin.
  await attendreDisparition(tester, find.text('Se connecter'), tentatives: 40);
}

/// Amène [cible] à [alignement] de la hauteur visible (0 = en haut du
/// viewport, 1 = en bas), au lieu du minimum strict que fait
/// `tester.ensureVisible` — qui pose la cible pile sur le bord et laisse
/// hors champ tout ce qui l'entoure. Pour une capture, c'est la zone autour
/// de la cible qu'on vient regarder : une capture du sélecteur de variantes
/// collé au ras de l'écran, avec le prix coupé au-dessus, ne montre pas ce
/// qu'elle promet.
Future<void> cadrer(
  WidgetTester tester,
  Finder cible, {
  double alignement = 0.3,
}) async {
  // Sans `duration` : un défilement *animé* rend ici un `Future` qui
  // n'aboutit jamais — l'animation a besoin de frames, et rien n'en produit
  // pendant qu'on l'attend, donc le test reste figé sur ce `await` jusqu'à
  // son timeout (app immobile à l'écran, aucune capture écrite puisqu'elles
  // ne partent qu'à la fin). Un saut immédiat rend un `Future` déjà
  // complété, et c'est de toute façon une capture qu'on veut, pas une
  // animation.
  await Scrollable.ensureVisible(
    tester.element(cible.first),
    alignment: alignement,
  );
  await avancer(tester, pas: 3);
}

/// Ouvre un onglet par son `Tooltip` (barre de navigation sans libellés).
Future<void> ouvrirOnglet(WidgetTester tester, String infobulle) async {
  // La barre de navigation n'existe qu'une fois la coquille montée, ce qui
  // dépend d'une requête réseau quand on arrive juste de la connexion.
  await attendre(tester, find.byTooltip(infobulle));
  await tester.tap(find.byTooltip(infobulle));
  await avancer(tester, pas: 8);
}

/// Ouvre la recherche depuis la coquille client, tape [texte] et le
/// valide : la recherche du kit n'affiche ses résultats qu'une fois validée
/// (pendant la frappe, ce sont des suggestions).
Future<void> chercher(WidgetTester tester, String texte) async {
  await attendre(tester, find.byTooltip('Rechercher'));
  await tester.tap(find.byTooltip('Rechercher'));
  await avancer(tester, pas: 8);
  await tester.enterText(find.byType(TextField).first, texte);
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await avancer(tester, pas: 10);
}

