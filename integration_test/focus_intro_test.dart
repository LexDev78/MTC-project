library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:mtc_app/features/auth/presentation/widgets/mali_trade_connect_intro.dart';

import 'support/parcours_visuel.dart';

/// Focus « intro » : l'animation d'ouverture, figée à chaque phase.
///
///   flutter drive --driver=test_driver/integration_test.dart \
///     --target=integration_test/focus_intro_test.dart -d `<simulateur>`
///
/// Une animation de dix-huit secondes ne se juge pas en la regardant tourner
/// une fois : on ne retient pas ce qui s'est passé à la quatrième seconde, et
/// c'est précisément là que les défauts se cachent (un libellé qui sort de
/// l'écran, un point posé dans la mer, un titre qui recouvre le réseau).
/// Chaque phase est donc capturée séparément.
///
/// ## Pourquoi remonter le widget à chaque phase
///
/// `takeScreenshot` prend une à deux secondes sur simulateur, et l'animation
/// continue pendant ce temps : onze captures enchaînées sur une seule montée
/// dériveraient de dix secondes ou plus, et les dernières montreraient toutes
/// la même image finale. Chaque phase repart donc de zéro avec une clé
/// différente — l'état est reconstruit, le temps écoulé est exactement celui
/// qu'on a demandé.
///
/// Cela vérifie au passage quelque chose d'utile : que le widget supporte
/// d'être monté et démonté onze fois de suite sans fuite ni assertion.
///
/// Aucune base de données ici, et c'est le point fort de ce widget : il ne
/// dépend ni de Supabase, ni d'un paquet d'animation, ni d'un asset.
///
/// ## Pourquoi ce test existe malgré son jumeau rapide
///
/// `test/features/auth/mali_trade_connect_intro_test.dart` fait la même chose
/// en neuf secondes, sur une horloge exacte, et sans appareil — il faut le
/// préférer pour la géométrie, les couleurs et le minutage.
///
/// Mais `flutter test` tourne sans fontes système et y dessine tout texte en
/// carrés. Le titre, le slogan et les sept libellés de marchés ne se voient
/// donc que **ici**, sur un vrai appareil. C'est la seule raison de garder
/// ce parcours, et elle suffit : le titre occupe presque toute la largeur,
/// et c'est précisément le genre de chose qui casse sur un écran étroit.

/// Les instants à capturer, choisis sur les bornes annoncées par le widget.
const List<({double t, String nom})> _phases = [
  (t: 0.3, nom: 'intro-01-fond'),
  (t: 1.6, nom: 'intro-02-trace-a-mi-chemin'),
  (t: 3.3, nom: 'intro-03-contour-ferme'),
  (t: 4.4, nom: 'intro-04-producteurs'),
  (t: 5.6, nom: 'intro-05-acheteurs-et-anneaux'),
  (t: 7.5, nom: 'intro-06-premieres-connexions'),
  (t: 9.5, nom: 'intro-07-reseau-complet'),
  (t: 11.5, nom: 'intro-08-flux-qui-s-effacent'),
  (t: 12.8, nom: 'intro-09-carte-au-drapeau'),
  (t: 14.2, nom: 'intro-10-titre'),
  (t: 15.5, nom: 'intro-11-image-finale'),
];

Future<void> monter(
  WidgetTester tester,
  double t, {
  bool mouvementReduit = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      // `Scaffold` et non le widget nu : sans ancêtre `Material`, Flutter
      // souligne tout texte en jaune pour signaler l'oubli — ce que le premier
      // jet de ce test a parfaitement reproduit sur le titre. Le widget dessine
      // son propre fond plein écran, ce qui donne envie de l'utiliser tel quel
      // en `home:` ; il ne porte pourtant pas de `Material`.
      home: Scaffold(
        body: MediaQuery(
          // Reprend les réglages réels de l'appareil, en ne forçant que le
          // champ qu'on veut éprouver.
          data: MediaQueryData.fromView(
            tester.view,
          ).copyWith(disableAnimations: mouvementReduit),
          child: MaliTradeConnectIntro(key: ValueKey(t)),
        ),
      ),
    ),
  );
  // Le temps avance réellement ici (pilote « live ») : l'animation est donc
  // à `t` secondes de son début, à la latence d'une frame près.
  if (t > 0) {
    await tester.pump(Duration(milliseconds: (t * 1000).round()));
  }
  await tester.pump();
}

void main() {
  binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'focus intro — chaque phase de l\'animation, capturée séparément',
    timeout: const Timeout(Duration(minutes: 12)),
    (tester) async {
      echecs.clear();

      for (final phase in _phases) {
        await etapeVisuelle(tester, phase.nom, () async {
          await monter(tester, phase.t);
        });
      }

      // Mouvement réduit : le widget doit montrer l'image finale sans
      // animer. C'est un réglage d'accessibilité du système, et le seul
      // moyen de vérifier qu'il est respecté est de le forcer.
      await etapeVisuelle(tester, 'intro-12-mouvement-reduit', () async {
        await monter(tester, 0, mouvementReduit: true);
      });

      expect(echecs, isEmpty, reason: echecs.join('\n'));
    },
  );

  testWidgets(
    'un toucher passe l\'animation, un second la rejoue',
    timeout: const Timeout(Duration(minutes: 3)),
    (tester) async {
      var terminees = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MaliTradeConnectIntro(onFinished: () => terminees++),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));

      // Personne ne regarde dix-huit secondes d'intro au troisième
      // lancement : le toucher doit en sortir tout de suite.
      await tester.tap(find.byType(MaliTradeConnectIntro));
      await tester.pump();
      expect(
        terminees,
        1,
        reason: 'le toucher doit terminer l\'animation et prévenir l\'appelant',
      );

      // Une fois terminée, le même geste la rejoue — c'est ce que le widget
      // annonce en tête de fichier.
      await tester.tap(find.byType(MaliTradeConnectIntro));
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        terminees,
        1,
        reason: 'une animation relancée n\'est pas une animation terminée',
      );
    },
  );
}
