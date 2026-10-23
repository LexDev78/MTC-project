import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mtc_app/core/shop/shop_scope.dart';
import 'package:mtc_app/app/theme/app_theme.dart';

/// Banc de rendu des écrans du côté client, sans base ni appareil.
///
/// Chaque test d'écran y passe deux fois, en clair et en sombre, sur la
/// taille d'un iPhone (375 × 812 points, échelle 2) — celle des captures du
/// kit FlutterShop. Le rendu échoue sur toute exception de construction,
/// débordement compris : c'est déjà un contrôle.
///
/// Avec `--dart-define=MTC_CAPTURES=true`, il enregistre en plus l'image
/// dans `build/captures/`, pour la comparer aux maquettes du kit.
const _enregistrer = bool.fromEnvironment('MTC_CAPTURES');

bool _policesChargees = false;

/// Charge les vraies polices : sans elles, `flutter test` dessine chaque
/// caractère comme un rectangle, et une capture ne dit rien de la mise en
/// page réelle.
Future<void> chargerPolices() async {
  if (_policesChargees) return;
  Future<void> famille(String nom, List<String> fichiers) async {
    final loader = FontLoader(nom);
    for (final fichier in fichiers) {
      loader.addFont(rootBundle.load(fichier));
    }
    await loader.load();
  }

  await famille('Plus Jakarta', const [
    'assets/fonts/plus_jakarta/PlusJakartaDisplay-Regular.otf',
    'assets/fonts/plus_jakarta/PlusJakartaDisplay-Medium.otf',
    'assets/fonts/plus_jakarta/PlusJakartaDisplay-Bold.otf',
  ]);
  await famille('Archivo', const ['assets/fonts/archivo/Archivo-Variable.ttf']);

  // Les icônes Material viennent du SDK, pas des assets du projet.
  final racine =
      Platform.environment['FLUTTER_ROOT'] ??
      File(
        Platform.resolvedExecutable,
      ).parent.parent.parent.parent.parent.parent.path;
  final icones = File(
    '$racine/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (icones.existsSync()) {
    final loader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(icones.readAsBytesSync())));
    await loader.load();
  }
  _policesChargees = true;
}

/// Monte [ecran] dans le thème client (via le vrai `ShopScope`), le laisse
/// charger images et SVG, puis l'enregistre si demandé.
Future<void> rendreEcran(
  WidgetTester tester,
  String nom,
  Widget ecran, {
  List<Override> overrides = const [],
  Brightness brightness = Brightness.light,
  Size taille = const Size(375, 812),
  Future<void> Function(WidgetTester tester)? geste,
}) async {
  await tester.runAsync(chargerPolices);
  tester.view.physicalSize = taille * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  final cle = GlobalKey();
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: RepaintBoundary(
        key: cle,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: brightness == Brightness.dark
              ? ThemeMode.dark
              : ThemeMode.light,
          home: ShopScope(child: ecran),
        ),
      ),
    ),
  );

  // Images et SVG se décodent hors de l'horloge simulée du test.
  Future<void> laisserCharger() async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  await laisserCharger();
  if (geste != null) {
    await geste(tester);
    await laisserCharger();
  }

  if (!_enregistrer) return;
  final boundary =
      cle.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final octets = await image.toByteData(format: ui.ImageByteFormat.png);
    final suffixe = brightness == Brightness.dark ? 'sombre' : 'clair';
    final fichier = File('build/captures/client/${nom}_$suffixe.png');
    fichier.parent.createSync(recursive: true);
    fichier.writeAsBytesSync(octets!.buffer.asUint8List());
  });
}

/// Les deux passages, clair puis sombre, d'un même écran.
///
/// [hauteur] au-delà de 812 : une capture « page entière », pour relire ce
/// qui est sous le pli. [geste] : ce que l'utilisateur fait avant la
/// capture (ouvrir une feuille, changer un tri).
void capturerEcran(
  String nom,
  Widget Function() ecran, {
  List<Override> Function()? overrides,
  double hauteur = 812,
  Future<void> Function(WidgetTester tester)? geste,
}) {
  for (final brightness in Brightness.values) {
    testWidgets(
      '$nom (${brightness == Brightness.dark ? 'sombre' : 'clair'})',
      (tester) async {
        await rendreEcran(
          tester,
          nom,
          ecran(),
          overrides: overrides?.call() ?? const [],
          brightness: brightness,
          taille: Size(375, hauteur),
          geste: geste,
        );
      },
    );
  }
}
