import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:neutrawise/widgets/theme/app_colors.dart';

enum AppErrorType {
  network,
  somethingWentWrong,
  tooManyRequests,
  incorrectCredentials,
  invalidEmail,
  general,
}

class ErrorPopup extends StatelessWidget {
  final String title;
  final String message;
  final AppErrorType type;
  final IconData? customIcon;
  final Color? customColor;
  final VoidCallback? onRetry;
  final String? buttonText;

  const ErrorPopup({
    super.key,
    required this.title,
    required this.message,
    this.type = AppErrorType.general,
    this.customIcon,
    this.customColor,
    this.onRetry,
    this.buttonText,
  });

  static AppErrorType classify(dynamic error) {
    if (error == null) return AppErrorType.somethingWentWrong;
    final message = error.toString().toLowerCase();

    // 1. Network error (No internet connection / offline / host lookup failure)
    if (error is SocketException ||
        message.contains('socketexception') ||
        message.contains('failed host lookup') ||
        message.contains('network is unreachable') ||
        message.contains('network error') ||
        message.contains('no internet') ||
        message.contains('connection refused') ||
        message.contains('connection closed') ||
        message.contains('clientexception') ||
        message.contains('os error') ||
        message.contains('handshakeexception') ||
        message.contains('tls exception') ||
        message.contains('network_error') ||
        message.contains('offline')) {
      return AppErrorType.network;
    }

    // 2. Too many requests (Rate limiting / 429)
    if (message.contains('too many requests') ||
        message.contains('rate limit') ||
        message.contains('429') ||
        message.contains('over_email_send_rate_limit') ||
        message.contains('resource_exhausted') ||
        message.contains('quota exceeded') ||
        message.contains('too_many_requests')) {
      return AppErrorType.tooManyRequests;
    }

    // 3. Incorrect login credentials
    if (message.contains('invalid login credentials') ||
        message.contains('invalid_credentials') ||
        message.contains('incorrect login credentials') ||
        message.contains('invalid_grant') ||
        message.contains('wrong password') ||
        message.contains('incorrect password') ||
        message.contains('invalid password') ||
        message.contains('user not found') ||
        message.contains('invalid username or password') ||
        message.contains('invalid email or password') ||
        message.contains('email not confirmed')) {
      return AppErrorType.incorrectCredentials;
    }

    // 4. Invalid Email
    if (message.contains('invalid email') ||
        message.contains('invalid format') ||
        message.contains('unable to validate email') ||
        message.contains('email_address_invalid') ||
        message.contains('valid email address') ||
        message.contains('invalid email address')) {
      return AppErrorType.invalidEmail;
    }

    // 5. Something went wrong (Server down, 5xx, timeout)
    if (error is TimeoutException ||
        message.contains('timeout') ||
        message.contains('500') ||
        message.contains('502') ||
        message.contains('503') ||
        message.contains('504') ||
        message.contains('internal server error') ||
        message.contains('service unavailable') ||
        message.contains('bad gateway') ||
        message.contains('gateway timeout') ||
        message.contains('server down') ||
        message.contains('something went wrong')) {
      return AppErrorType.somethingWentWrong;
    }

    return AppErrorType.somethingWentWrong;
  }

  static String getDefaultTitle(AppErrorType type) {
    switch (type) {
      case AppErrorType.network:
        return 'Network Error';
      case AppErrorType.somethingWentWrong:
        return 'Something went wrong';
      case AppErrorType.tooManyRequests:
        return 'Too many requests';
      case AppErrorType.incorrectCredentials:
        return 'Incorrect login credentials';
      case AppErrorType.invalidEmail:
        return 'Invalid Email';
      case AppErrorType.general:
        return 'Error';
    }
  }

  static String getDefaultMessage(AppErrorType type) {
    switch (type) {
      case AppErrorType.network:
        return 'No internet connection detected. Please check your connection and try again.';
      case AppErrorType.somethingWentWrong:
        return 'Our servers encountered an unexpected issue or the request timed out. Please try again later.';
      case AppErrorType.tooManyRequests:
        return 'You have made too many requests in a short period. Please wait a moment and try again.';
      case AppErrorType.incorrectCredentials:
        return 'The email address or password you entered is incorrect. Please check your credentials and try again.';
      case AppErrorType.invalidEmail:
        return 'Please enter a valid email address format (e.g. user@example.com).';
      case AppErrorType.general:
        return 'An unexpected error occurred. Please try again.';
    }
  }

  static IconData getDefaultIcon(AppErrorType type) {
    switch (type) {
      case AppErrorType.network:
        return Icons.wifi_off_rounded;
      case AppErrorType.somethingWentWrong:
        return Icons.cloud_off_rounded;
      case AppErrorType.tooManyRequests:
        return Icons.hourglass_top_rounded;
      case AppErrorType.incorrectCredentials:
        return Icons.lock_person_rounded;
      case AppErrorType.invalidEmail:
        return Icons.mark_email_unread_rounded;
      case AppErrorType.general:
        return Icons.error_outline_rounded;
    }
  }

  static Color getDefaultColor(AppErrorType type) {
    switch (type) {
      case AppErrorType.network:
        return const Color(0xFFEF5350); // Warning/Error Red-Orange
      case AppErrorType.somethingWentWrong:
        return const Color(0xFFE53935); // Server Error Red
      case AppErrorType.tooManyRequests:
        return const Color(0xFFFFA726); // Rate Limit Amber/Orange
      case AppErrorType.incorrectCredentials:
        return const Color(0xFFE53935); // Auth Error Red
      case AppErrorType.invalidEmail:
        return const Color(0xFFFFA726); // Format Warning Amber
      case AppErrorType.general:
        return const Color(0xFFEF5350);
    }
  }

  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required String message,
    AppErrorType type = AppErrorType.general,
    IconData? icon,
    Color? color,
    VoidCallback? onRetry,
    String? buttonText,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ErrorPopup(
        title: title,
        message: message,
        type: type,
        customIcon: icon,
        customColor: color,
        onRetry: onRetry,
        buttonText: buttonText,
      ),
    );
  }

  static Future<T?> showNetworkError<T>(
    BuildContext context, {
    String? message,
    VoidCallback? onRetry,
  }) {
    return show<T>(
      context,
      title: 'Network Error',
      message: message ?? getDefaultMessage(AppErrorType.network),
      type: AppErrorType.network,
      onRetry: onRetry,
    );
  }

  static Future<T?> showSomethingWentWrong<T>(
    BuildContext context, {
    String? message,
    VoidCallback? onRetry,
  }) {
    return show<T>(
      context,
      title: 'Something went wrong',
      message: message ?? getDefaultMessage(AppErrorType.somethingWentWrong),
      type: AppErrorType.somethingWentWrong,
      onRetry: onRetry,
    );
  }

  static Future<T?> showTooManyRequests<T>(
    BuildContext context, {
    String? message,
  }) {
    return show<T>(
      context,
      title: 'Too many requests',
      message: message ?? getDefaultMessage(AppErrorType.tooManyRequests),
      type: AppErrorType.tooManyRequests,
    );
  }

  static Future<T?> showIncorrectCredentials<T>(
    BuildContext context, {
    String? message,
  }) {
    return show<T>(
      context,
      title: 'Incorrect login credentials',
      message: message ?? getDefaultMessage(AppErrorType.incorrectCredentials),
      type: AppErrorType.incorrectCredentials,
    );
  }

  static Future<T?> showInvalidEmail<T>(
    BuildContext context, {
    String? message,
  }) {
    return show<T>(
      context,
      title: 'Invalid Email',
      message: message ?? getDefaultMessage(AppErrorType.invalidEmail),
      type: AppErrorType.invalidEmail,
    );
  }

  static Future<T?> showFromException<T>(
    BuildContext context,
    dynamic error, {
    VoidCallback? onRetry,
  }) {
    final type = classify(error);
    final title = getDefaultTitle(type);
    final defaultMsg = getDefaultMessage(type);

    String? customMsg;
    if (error != null) {
      final str = error.toString().replaceAll('Exception: ', '').trim();
      // If error message contains custom explanation and is not raw technical gibberish
      if (str.isNotEmpty &&
          !str.contains('SocketException') &&
          !str.contains('HandshakeException') &&
          !str.contains('ClientException') &&
          !str.contains('PostgrestException') &&
          !str.contains('AuthException')) {
        customMsg = str;
      }
    }

    return show<T>(
      context,
      title: title,
      message: customMsg ?? defaultMsg,
      type: type,
      onRetry: onRetry,
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor = customColor ?? getDefaultColor(type);
    final effectiveIcon = customIcon ?? getDefaultIcon(type);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: effectiveColor.withValues(alpha: 0.25),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: effectiveColor.withValues(alpha: 0.12),
              blurRadius: 24,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 8),
            // Glowing Icon Header
            Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: effectiveColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: effectiveColor.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(effectiveIcon, size: 40, color: effectiveColor),
                )
                .animate()
                .scale(
                  duration: 350.ms,
                  curve: Curves.easeOutBack,
                  begin: const Offset(0.7, 0.7),
                  end: const Offset(1.0, 1.0),
                )
                .fade(duration: 250.ms),
            const SizedBox(height: 20),
            // Title
            Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary(context),
                    letterSpacing: 0.2,
                  ),
                )
                .animate()
                .fade(delay: 100.ms, duration: 300.ms)
                .slideY(begin: 0.2, end: 0.0),
            const SizedBox(height: 12),
            // Description / Message
            Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary(context),
                    height: 1.45,
                  ),
                )
                .animate()
                .fade(delay: 150.ms, duration: 300.ms)
                .slideY(begin: 0.1, end: 0.0),
            const SizedBox(height: 24),
            // Action Buttons
            if (onRetry != null)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary(context),
                        side: BorderSide(color: AppColors.border(context)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: effectiveColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        onRetry!();
                      },
                      child: const Text(
                        'Retry',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ).animate().fade(delay: 200.ms).slideY(begin: 0.2, end: 0.0)
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: effectiveColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    buttonText ?? 'OK',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ).animate().fade(delay: 200.ms).slideY(begin: 0.2, end: 0.0),
          ],
        ),
      ),
    );
  }
}
