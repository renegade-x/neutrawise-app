import 'package:flutter/foundation.dart';

/// Central place for reporting errors that are handled (not rethrown).
///
/// Everything goes to the debug console. To send them to a crash reporter
/// (for example Sentry), set [reporter] once at startup:
///
/// ```dart
/// AppLogger.reporter = (where, error, stack) =>
///     Sentry.captureException(error, stackTrace: stack);
/// ```
class AppLogger {
  AppLogger._();

  /// Optional hook for a crash-reporting backend.
  static void Function(String where, Object error, StackTrace? stack)? reporter;

  static void error(String where, Object error, [StackTrace? stack]) {
    debugPrint('[$where] $error');
    try {
      reporter?.call(where, error, stack);
    } catch (_) {
      // Reporting must never throw.
    }
  }
}
