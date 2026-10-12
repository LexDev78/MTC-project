// Pilote de `flutter drive` — son seul rôle est de recevoir les captures
// prises par `binding.takeScreenshot(...)` dans un test d'intégration et de
// les écrire sur disque (le test, lui, tourne sur l'appareil et n'a pas
// accès au système de fichiers de la machine).
//
// Utilisé par `integration_test/visual_tour_test.dart` :
//   flutter drive \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/visual_tour_test.dart \
//     -d <id du simulateur>
//
// Destination configurable par `SCREENSHOT_DIR` ; par défaut
// `build/captures/` à la racine du projet.

import 'dart:io';

// La variante « extended » est celle qui expose `onScreenshot` ; le pilote
// standard (`integration_test_driver.dart`) ne sait pas récupérer d'images.
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver(
  onScreenshot: (String name, List<int> bytes, [Map<String, Object?>? args]) async {
    final directory = Directory(
      Platform.environment['SCREENSHOT_DIR'] ?? 'build/captures',
    );
    await directory.create(recursive: true);
    await File('${directory.path}/$name.png').writeAsBytes(bytes);
    return true;
  },
);
