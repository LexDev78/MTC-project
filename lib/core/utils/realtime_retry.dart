import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Wraps a Supabase Realtime-backed stream factory (a `.stream()` call) so a
/// transient failure doesn't kill it for good. `SupabaseStreamBuilder`
/// closes its controller on the first error — a dropped websocket
/// (`RealtimeSubscribeException`) or a request that raced session restore
/// with a stale/anon token — instead of retrying, which otherwise leaves a
/// chat thread or order list silently stuck until the whole app reloads.
///
/// Resubscribes on **transient** errors, for as long as something is
/// listening, with exponential backoff between attempts (capped at
/// [maxDelay], reset back to [initialDelay] after the next successful
/// emission). A plain fixed-delay retry hammers the server every couple of
/// seconds for as long as the underlying cause persists — e.g. an access
/// token that's expired and hasn't been refreshed yet, where every immediate
/// retry fails the same way until the refresh lands — so each attempt backs
/// off further instead.
///
/// Deux limites à cette patience, sans lesquelles elle se retourne contre
/// l'utilisateur :
///
/// - une erreur **permanente** (voir [_isPermanent]) est propagée tout de
///   suite, sans réessai ;
/// - une succession de [maxAttemptsWithoutData] échecs **sans qu'aucune
///   donnée ne soit jamais arrivée** est propagée elle aussi.
///
/// Dans les deux cas l'écran reçoit une erreur — donc un message et un moyen
/// de réessayer — au lieu d'un chargement perpétuel. Le compteur repart à
/// zéro dès qu'une valeur passe : une coupure de websocket au bout de deux
/// heures de flux sain garde toute la tolérance d'origine.

/// Une erreur que réessayer ne corrigera jamais : la **requête elle-même**
/// est fautive.
///
/// Le tri se fait sur le code, pas sur le type. Un premier jet considérait
/// toute `PostgrestException` comme définitive, ce qui coupait le flux à la
/// moindre erreur passagère — jeton expiré en cours de rafraîchissement,
/// serveur momentanément saturé — et rendait instables des tests qui
/// n'avaient rien à voir : ils échouaient par poignées, jamais les mêmes
/// d'une exécution à l'autre.
///
///  * SQLSTATE `42xxx` : objet inconnu, syntaxe, privilège. Une colonne mal
///    nommée ou une migration oubliée ne se répareront pas en réessayant.
///  * PostgREST `PGRST1xx` (requête mal formée) et `PGRST2xx` (relation
///    introuvable dans le cache de schéma) : même famille.
///
/// Tout le reste — authentification (`PGRST3xx`), erreurs serveur, réseau —
/// est passager et vaut un nouvel essai. C'est précisément le cas que cet
/// enrobage existe pour couvrir.
bool _isPermanent(Object error) {
  if (error is! PostgrestException) return false;
  final code = error.code;
  if (code == null) return false;
  return code.startsWith('42') ||
      code.startsWith('PGRST1') ||
      code.startsWith('PGRST2');
}

Stream<T> withRealtimeRetry<T>(
  Stream<T> Function() streamFactory, {
  Duration initialDelay = const Duration(seconds: 2),
  Duration maxDelay = const Duration(seconds: 30),
  int maxAttemptsWithoutData = 5,
}) {
  late final StreamController<T> controller;
  StreamSubscription<T>? subscription;
  var cancelled = false;
  var currentDelay = initialDelay;
  var attemptsWithoutData = 0;

  void subscribe() {
    subscription = streamFactory().listen(
      (data) {
        currentDelay = initialDelay;
        attemptsWithoutData = 0;
        controller.add(data);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (cancelled) return;

        // Deux raisons d'abandonner plutôt que de réessayer : une erreur que
        // le serveur répétera à l'identique, ou une succession d'échecs sans
        // qu'aucune donnée ne soit jamais arrivée. Dans les deux cas l'erreur
        // est propagée au flux : l'écran montre un message et un moyen de
        // réessayer, au lieu d'un chargement perpétuel.
        attemptsWithoutData++;
        if (_isPermanent(error) ||
            attemptsWithoutData >= maxAttemptsWithoutData) {
          controller.addError(error, stackTrace);
          unawaited(controller.close());
          return;
        }

        final delay = currentDelay;
        currentDelay = currentDelay * 2 < maxDelay ? currentDelay * 2 : maxDelay;
        Future.delayed(delay, () {
          if (!cancelled) subscribe();
        });
      },
    );
  }

  controller = StreamController<T>.broadcast(
    onListen: subscribe,
    onCancel: () {
      cancelled = true;
      unawaited(subscription?.cancel());
    },
  );

  return controller.stream;
}
