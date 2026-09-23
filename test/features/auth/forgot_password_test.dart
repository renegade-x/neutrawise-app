import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neutrawise/features/auth/screens/forgot_password_screen.dart';
import 'package:neutrawise/features/auth/screens/reset_password_screen.dart';
import 'package:neutrawise/providers/auth_provider.dart';

// Test mock notifier
class MockAuthNotifier extends AuthNotifier {
  final Future<String?> Function(String email)? onResetPassword;
  final Future<String?> Function(String password)? onUpdatePassword;

  MockAuthNotifier({this.onResetPassword, this.onUpdatePassword});

  @override
  AuthStateData build() {
    return AuthStateData(
      isAuthenticated: false,
      user: null,
      loading: false,
      error: null,
      hasProfileSetup: false,
      hasSeenOnboarding: true,
    );
  }

  @override
  Future<String?> resetPasswordForEmail(
    String email, {
    String? redirectTo,
  }) async {
    if (onResetPassword != null) {
      return onResetPassword!(email);
    }
    return null;
  }

  @override
  Future<String?> updatePassword(String newPassword) async {
    if (onUpdatePassword != null) {
      return onUpdatePassword!(newPassword);
    }
    return null;
  }
}

void main() {
  group('ForgotPasswordScreen Tests', () {
    testWidgets('renders all initial UI elements cleanly', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: ForgotPasswordScreen())),
      );

      expect(find.text('Reset Password'), findsOneWidget);
      expect(find.text('Forgot your password?'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Send Reset Link'), findsOneWidget);
      expect(find.text('Back to Log In'), findsOneWidget);
      expect(find.text('Helpful Tips'), findsOneWidget);
    });

    testWidgets('shows validation error when email is empty', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: ForgotPasswordScreen())),
      );

      await tester.tap(find.text('Send Reset Link'));
      await tester.pump();

      expect(find.text('Please enter your email address.'), findsOneWidget);
    });

    testWidgets('shows validation error when email format is invalid', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: ForgotPasswordScreen())),
      );

      await tester.enterText(find.byType(TextField), 'invalidemail');
      await tester.tap(find.text('Send Reset Link'));
      await tester.pumpAndSettle();

      expect(find.text('Invalid Email'), findsOneWidget);
      expect(
        find.text(
          'Please enter a valid email address (e.g. user@example.com).',
        ),
        findsWidgets,
      );

      // Dismiss dialog
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
    });

    testWidgets('shows success message on valid submission', (tester) async {
      String? requestedEmail;

      final mockNotifier = MockAuthNotifier(
        onResetPassword: (email) async {
          requestedEmail = email;
          return null;
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [authProvider.overrideWith(() => mockNotifier)],
          child: const MaterialApp(home: ForgotPasswordScreen()),
        ),
      );

      await tester.enterText(find.byType(TextField), 'user@example.com');
      await tester.tap(find.text('Send Reset Link'));
      await tester.pumpAndSettle();

      expect(requestedEmail, 'user@example.com');
      expect(
        find.text(
          'Password reset link sent! Check your inbox (and spam folder).',
        ),
        findsOneWidget,
      );
    });

    testWidgets('handles user not found gracefully without leaking existence', (
      tester,
    ) async {
      final mockNotifier = MockAuthNotifier(
        onResetPassword: (email) async => 'User not found in system',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [authProvider.overrideWith(() => mockNotifier)],
          child: const MaterialApp(home: ForgotPasswordScreen()),
        ),
      );

      await tester.enterText(find.byType(TextField), 'unknown@example.com');
      await tester.tap(find.text('Send Reset Link'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'If an account exists with this email, a password reset link has been sent.',
        ),
        findsOneWidget,
      );
    });
  });

  group('ResetPasswordScreen Tests', () {
    testWidgets('renders all initial UI elements and checklist', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: ResetPasswordScreen())),
      );

      expect(find.text('Create New Password'), findsOneWidget);
      expect(find.text('New Password'), findsOneWidget);
      expect(find.text('Confirm New Password'), findsOneWidget);
      expect(find.text('Reset Password'), findsWidgets);
      expect(find.text('Password Requirements:'), findsOneWidget);
      expect(find.text('At least 8 characters'), findsOneWidget);
      expect(find.text('Contains uppercase letter (A-Z)'), findsOneWidget);
      expect(find.text('Contains lowercase letter (a-z)'), findsOneWidget);
      expect(find.text('Contains number (0-9)'), findsOneWidget);
    });

    testWidgets('validates empty fields and mismatched passwords', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: ResetPasswordScreen())),
      );

      // Empty submission
      await tester.tap(find.widgetWithText(ElevatedButton, 'Reset Password'));
      await tester.pump();
      expect(find.text('Please fill in both password fields.'), findsOneWidget);

      // Mismatched passwords
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'Password123');
      await tester.enterText(textFields.at(1), 'Different123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Reset Password'));
      await tester.pump();
      expect(find.text('Passwords do not match.'), findsOneWidget);
    });

    testWidgets('validates weak password requirement', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: ResetPasswordScreen())),
      );

      final textFields = find.byType(TextField);
      // Weak password (< 8 chars)
      await tester.enterText(textFields.at(0), 'Pass1');
      await tester.enterText(textFields.at(1), 'Pass1');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Reset Password'));
      await tester.pump();

      expect(
        find.text('Please ensure your password meets all requirements below.'),
        findsOneWidget,
      );
    });

    testWidgets('updates password successfully on valid input', (tester) async {
      String? updatedPassword;

      final mockNotifier = MockAuthNotifier(
        onUpdatePassword: (pass) async {
          updatedPassword = pass;
          return null;
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [authProvider.overrideWith(() => mockNotifier)],
          child: const MaterialApp(home: ResetPasswordScreen()),
        ),
      );

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'ValidPass123');
      await tester.enterText(textFields.at(1), 'ValidPass123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Reset Password'));
      await tester.pump();

      expect(updatedPassword, 'ValidPass123');
      expect(
        find.text('Password reset successfully! Redirecting to Log In...'),
        findsOneWidget,
      );

      // Advance timers to clear the delayed redirect
      await tester.pump(const Duration(seconds: 3));
    });
  });
}
