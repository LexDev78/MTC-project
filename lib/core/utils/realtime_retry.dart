import 'dart:async';

/// Wraps a Supabase Realtime-backed stream factory (a `.stream()` call) so a
/// transient failure doesn't kill it for good. `SupabaseStreamBuilder`
/// closes its controller on the first error — a dropped websocket
/// (`RealtimeSubscribeException`) or a request that raced session restore
/// with a stale/anon token — instead of retrying, which otherwise leaves a
/// chat thread or order list silently stuck until the whole app reloads.
///
/// Resubscribes on every error, for as long as something is listening, with
/// exponential backoff between attempts (capped at [maxDelay], reset back to
/// [initialDelay] after the next successful emission). A plain fixed-delay
/// retry hammers the server every couple of seconds for as long as the
/// underlying cause persists — e.g. an access token that's expired and
/// hasn't been refreshed yet, where every immediate retry fails the same way
/// until the refresh lands — so each attempt backs off further instead.
Stream<T> withRealtimeRetry<T>(
  Stream<T> Function() streamFactory, {
  Duration initialDelay = const Duration(seconds: 2),
  Duration maxDelay = const Duration(seconds: 30),
}) {
  late final StreamController<T> controller;
  StreamSubscription<T>? subscription;
  var cancelled = false;
  var currentDelay = initialDelay;

  void subscribe() {
    subscription = streamFactory().listen(
      (data) {
        currentDelay = initialDelay;
        controller.add(data);
      },
      onError: (Object _, StackTrace __) {
        if (cancelled) return;
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
