library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mtc_app/features/auth/presentation/widgets/mali_trade_connect_intro.dart';

/// L'animation d'ouverture, éprouvée sur une horloge **exacte**.
///
/// Un premier jet passait par `flutter drive` sur simulateur. Il montrait bien
/// l'animation, mais pas au moment annoncé : le temps y est réel, une capture
/// d'écran coûte une à deux secondes, et chaque phase arrivait en retard sur
/// son étiquette — la capture dite « 11,5 s » montrait en fait l'état à 13 s.
/// Pour juger d'une séquence, savoir *quand* les choses arrivent est tout
/// l'enjeu.
///
/// Ici l'horloge est simulée : `pump(d)` avance d'exactement `d`. Les instants
/// sont donc ceux qu'on demande, le test tourne en quelques secondes, et il
/// n'a besoin d'aucun appareil.
///
/// Les images ne sont écrites que si `MTC_INTRO_CAPTURES` désigne un dossier :
///
///   MTC_INTRO_CAPTURES=/tmp/intro flutter test \
///     test/features/auth/mali_trade_connect_intro_test.dart
///
/// Sans cette variable, le test vérifie seulement que chaque phase se dessine
/// sans exception — ce qui est déjà l'essentiel, un `CustomPainter` qui lève
/// ne laissant qu'un écran rouge.
///
/// ## Ce que ce test ne peut pas montrer
///
/// Les polices. `flutter test` tourne sans fontes système : tout texte y est
/// dessiné en carrés. La géométrie, les couleurs et le minutage sont justes,
/// la typographie non — le titre et les libellés des marchés ne se jugent
/// donc que sur appareil, par `integration_test/focus_intro_test.dart`.
/// Les deux harnais sont complémentaires, aucun ne remplace l'autre.

/// Les instants à éprouver, pris sur les bornes annoncées par le widget.
const List<({double t, String nom})> _phases = [
  (t: 0.3, nom: '01-fond'),
  (t: 1.6, nom: '02-trace-a-mi-chemin'),
  (t: 3.3, nom: '03-contour-ferme'),
  (t: 4.4, nom: '04-producteurs'),
  (t: 5.6, nom: '05-acheteurs-et-anneaux'),
  (t: 7.5, nom: '06-premieres-connexions'),
  (t: 9.5, nom: '07-reseau-complet'),
  (t: 11.5, nom: '08-flux-qui-s-effacent'),
  (t: 12.8, nom: '09-carte-au-drapeau'),
  (t: 14.2, nom: '10-titre'),
  (t: 17.9, nom: '11-image-finale'),
];

final _cadre = GlobalKey();

/// Monte l'animation dans un `Scaffold`.
///
/// Le `Scaffold` n'est pas décoratif : sans ancêtre `Material`, Flutter
/// souligne tout texte en jaune pour signaler l'oubli, et le titre de
/// l'animation en est couvert. Le widget dessine son propre fond plein
/// écran, ce qui donne envie de l'utiliser tel quel en `home:` — il ne porte
/// pourtant pas de `Material`.
Future<void> monter(
  WidgetTester tester,
  double t, {
  bool mouvementReduit = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData.fromView(
            tester.view,
          ).copyWith(disableAnimations: mouvementReduit),
          child: RepaintBoundary(
            key: _cadre,
            // Une clé par instant : chaque phase repart d'un état neuf plutôt
            // que de prolonger la précédente. Les erreurs de temps ne
            // s'additionnent donc pas d'une capture à l'autre.
            child: MaliTradeConnectIntro(key: ValueKey(t)),
          ),
        ),
      ),
    ),
  );
  if (t > 0) {
    await tester.pump(Duration(microseconds: (t * 1000000).round()));
  }
}

/// Écrit l'image de la frame courante, si un dossier a été demandé.
Future<void> capturer(WidgetTester tester, String nom) async {
  final dossier = Platform.environment['MTC_INTRO_CAPTURES'];
  if (dossier == null) return;

  final cadre =
      _cadre.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await cadre.toImage(pixelRatio: 2);
    final octets = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final sortie = Directory(dossier)..createSync(recursive: true);
    File('${sortie.path}/$nom.png').writeAsBytesSync(
      octets!.buffer.asUint8List(),
    );
  });
}

/// Pose un format de téléphone courant, et surtout **fixe**.
///
/// La mise en page de l'animation dépend entièrement des proportions de
/// l'écran — la carte est dimensionnée par `min(0,64 × largeur, 0,40 ×
/// hauteur)` — donc une capture prise sur la surface par défaut de 800×600
/// ne dirait rien de ce que voit un téléphone.
void poserEcran(WidgetTester tester) {
  tester.view.physicalSize = const Size(1179, 2556);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {

  for (final phase in _phases) {
    testWidgets('phase ${phase.nom} se dessine à ${phase.t} s', (tester) async {
      poserEcran(tester);

      await monter(tester, phase.t);

      // Un `CustomPainter` qui lève laisse un écran rouge et aucune trace
      // ailleurs : c'est `takeException` qui le dit.
      expect(tester.takeException(), isNull);
      await capturer(tester, phase.nom);
    });
  }

  testWidgets('mouvement réduit : l\'image finale, sans animer', (tester) async {
    poserEcran(tester);

    await monter(tester, 0, mouvementReduit: true);
    await tester.pump();

    // Le titre n'apparaît qu'à 12,6 s : le voir à l'instant zéro prouve que
    // le réglage d'accessibilité a bien été honoré, et pas seulement que le
    // widget se dessine.
    expect(find.textContaining('TRADE CONNECT'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capturer(tester, '12-mouvement-reduit');
  });

  testWidgets('un toucher passe l\'animation et prévient l\'appelant', (
    tester,
  ) async {
    var terminees = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MaliTradeConnectIntro(onFinished: () => terminees++),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    // Personne ne regarde dix-huit secondes d'intro au troisième lancement.
    await tester.tap(find.byType(MaliTradeConnectIntro));
    await tester.pump();
    expect(terminees, 1);
    expect(find.textContaining('TRADE CONNECT'), findsOneWidget);

    // Le même geste la rejoue, comme le widget l'annonce.
    await tester.tap(find.byType(MaliTradeConnectIntro));
    await tester.pump(const Duration(milliseconds: 300));
    expect(terminees, 1, reason: 'une animation relancée n\'est pas terminée');
    expect(find.textContaining('TRADE CONNECT'), findsNothing);

    // Laissée à son terme, elle prévient une seconde fois.
    //
    // Par pas, et non par un seul `pump(18 s)` : le rejeu démarre son tic à
    // la frame du toucher, si bien qu'un bond de dix-huit secondes y place
    // l'horloge **exactement** sur la borne. Or `isDone` teste `t > durée`,
    // strictement : à 18,000 s l'animation n'est pas finie, et le test
    // échouait sur une frame d'écart. Dans l'app la frame suivante arrive
    // seize millisecondes plus tard et personne ne le voit ; ici rien ne
    // produit cette frame.
    for (var i = 0; i < 190; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(terminees, 2);
  });

  testWidgets('la séquence va jusqu\'au bout sans lever', (tester) async {
    poserEcran(tester);

    // Les captures ne montrent que onze instants ; entre deux, rien ne dit
    // qu'une frame ne lève pas. On déroule donc la séquence entière par pas
    // de 100 ms — dix-huit secondes d'horloge simulée coûtent une seconde de
    // test.
    await monter(tester, 0);
    for (var i = 0; i < 190; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull, reason: 'à ${i * 0.1} s');
    }
  });
}
