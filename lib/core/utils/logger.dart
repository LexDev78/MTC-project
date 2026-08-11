import 'dart:developer' as developer;

/// Thin wrapper around `dart:developer`'s `log()` so `avoid_print` stays
/// enforceable even before any real crash-reporting backend exists.
abstract final class AppLogger {
  static void debug(String message, {String name = 'MTC'}) {
    developer.log(message, name: name);
  }

  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String name = 'MTC',
  }) {
    developer.log(
      message,
      name: name,
      error: error,
      stackTrace: stackTrace,
      level: 1000,
    );
  }
}
