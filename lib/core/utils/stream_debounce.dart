import 'dart:async';

/// Regroupe les rafales d'un flux de rafraîchissement en une seule émission.
///
/// Les flux Realtime de ce projet ne transportent pas de données utiles :
/// ils réveillent une vraie requête (`asyncMap`). Un fournisseur qui
/// enregistre huit variantes, une commande qui traverse quatre statuts, un
/// import de catalogue : chacun produit une rafale, et donc autant de
/// rechargements complets — sur **chaque** appareil connecté, pour aboutir
/// au même affichage que le dernier.
///
/// [leading] décide de ce qui se passe au **début** d'une rafale :
///
///  * `false` (défaut) : rien n'est émis avant le silence. Convient à un
///    flux purement déclencheur, posé à côté d'une première émission que
///    l'appelant fait lui-même (voir les `_watch` des sources de données) ;
///  * `true` : le premier événement passe immédiatement, les suivants de la
///    rafale sont regroupés en une émission de fin. Nécessaire quand le flux
///    **est** la source affichée : sans cela, l'ouverture de l'écran
///    attendrait la fenêtre entière devant une liste vide.
extension DebounceTriggers on Stream<void> {
  /// Volontairement sans `transform` : `.map((_) {})` produit un
  /// `Stream<Null>`, que cette extension accepte (`Null` est un sous-type de
  /// `void`) mais dont le `transform` exige alors un
  /// `StreamTransformer<Null, void>`. L'incompatibilité ne se voit qu'à
  /// l'exécution, et seulement sur les flux issus d'un `map` — c'est-à-dire
  /// exactement les deux appelants réels. Un abonnement direct n'a pas ce
  /// piège.
  Stream<void> debounceTriggers({
    Duration window = const Duration(milliseconds: 400),
    bool leading = false,
  }) {
    late StreamController<void> controller;
    StreamSubscription<void>? subscription;
    Timer? timer;
    var pending = false;

    void emit() {
      if (!controller.isClosed) controller.add(null);
    }

    void closeBurst() {
      timer = null;
      if (!pending) return;
      pending = false;
      emit();
    }

    controller = StreamController<void>(
      onListen: () {
        subscription = listen(
          (_) {
            if (timer == null && leading) {
              emit();
            } else {
              pending = true;
            }
            timer?.cancel();
            timer = Timer(window, closeBurst);
          },
          // Une erreur doit passer sans attendre : c'est elle qui déclenche
          // la reconnexion (`withRealtimeRetry`).
          onError: controller.addError,
          onDone: () {
            timer?.cancel();
            controller.close();
          },
        );
      },
      onCancel: () async {
        timer?.cancel();
        await subscription?.cancel();
      },
    );
    return controller.stream;
  }
}
