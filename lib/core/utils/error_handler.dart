import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'logger.dart';

class ErrorHandler {
  static void handle(BuildContext context, Object error, {String? customMessage}) {
    AppLogger.error(customMessage ?? 'An error occurred', error);

    String message = customMessage ?? 'An unexpected error occurred. Please try again.';

    if (error is AuthException) {
      message = error.message;
    } else if (error is PostgrestException) {
      message = 'Database error: ${error.message}';
    } else if (error is StorageException) {
      message = 'Storage error: ${error.message}';
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  static void showSuccess(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
