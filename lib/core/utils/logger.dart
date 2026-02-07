import 'package:flutter/foundation.dart';

class AppLogger {
  static void info(String message) {
    if (kDebugMode) {
      print('INFO: $message');
    }
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      print('ERROR: $message');
      if (error != null) print('Details: $error');
      if (stackTrace != null) print('StackTrace: $stackTrace');
    }
  }

  static void warn(String message) {
    if (kDebugMode) {
      print('WARN: $message');
    }
  }
}
