import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:mtc_app/core/utils/stream_debounce.dart';

// Le regroupement des rafales Realtime (`stream_debounce.dart`). Ce qui est
// vérifié ici, c'est le compte d'émissions : c'est lui qui se traduit en
// rechargements complets côté application.
void main() {
  const window = Duration(milliseconds: 50);

  test('sans front montant, une rafale ne donne qu\'une émission', () async {
    final source = StreamController<void>();
    final seen = <void>[];
    final sub = source.stream
        .debounceTriggers(window: window)
        .listen(seen.add);

    for (var i = 0; i < 8; i++) {
      source.add(null);
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    // Rien avant le silence : c'est le dernier état qui compte.
    expect(seen, isEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(seen, hasLength(1));

    // Une rafale suivante, après le silence, redonne une émission.
    source.add(null);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(seen, hasLength(2));

    await sub.cancel();
    await source.close();
  });

  test(
    'avec front montant, le premier événement passe tout de suite',
    () async {
      final source = StreamController<void>();
      final seen = <void>[];
      final sub = source.stream
          .debounceTriggers(window: window, leading: true)
          .listen(seen.add);

      source.add(null);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      // L'écran ne doit pas attendre la fenêtre devant une liste vide.
      expect(seen, hasLength(1));

      for (var i = 0; i < 6; i++) {
        source.add(null);
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
      // Six de plus, et une seule émission de fin de rafale.
      expect(seen, hasLength(2));

      await sub.cancel();
      await source.close();
    },
  );

  test('une erreur passe sans attendre : elle déclenche la reconnexion', () async {
    final source = StreamController<void>();
    final errors = <Object>[];
    final sub = source.stream
        .debounceTriggers(window: window)
        .listen((_) {}, onError: errors.add);

    source.addError(StateError('coupure'));
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(errors, hasLength(1));

    await sub.cancel();
    await source.close();
  });

  test('l\'annulation arrête le minuteur en cours', () async {
    final source = StreamController<void>();
    final seen = <void>[];
    final sub = source.stream
        .debounceTriggers(window: window)
        .listen(seen.add);

    source.add(null);
    await sub.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(seen, isEmpty);

    await source.close();
  });

  // Le piège qui a cassé la suite : les deux appelants réels passent par
  // `.map((_) {})`, dont le type statique est `Stream<Null>`. Un
  // `transform` y échoue à l'exécution, et seulement là — jamais sur un
  // `StreamController<void>` comme ci-dessus.
  test('fonctionne sur un flux issu de `map`, pas seulement sur Stream<void>', () async {
    final source = StreamController<int>();
    final seen = <void>[];
    final sub = source.stream
        .map((_) {})
        .debounceTriggers(window: window, leading: true)
        .listen(seen.add);

    source.add(1);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(seen, hasLength(1));

    await sub.cancel();
    await source.close();
  });
}
