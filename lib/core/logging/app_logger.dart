import 'dart:developer' as developer;

class AppLogger {
  AppLogger._();

  static const String _name = 'BAMM';

  static void debug(String message, {String? tag}) {
    developer.log(message, name: tag ?? _name, level: 500);
  }

  static void info(String message, {String? tag}) {
    developer.log(message, name: tag ?? _name, level: 800);
  }

  static void warning(String message, {String? tag, Object? error}) {
    developer.log(
      message,
      name: tag ?? _name,
      level: 900,
      error: error,
    );
  }

  static void error(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    developer.log(
      message,
      name: tag ?? _name,
      level: 1000,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
