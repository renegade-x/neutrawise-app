import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neutrawise/features/auth/screens/login_screen.dart';
import 'package:neutrawise/providers/auth_provider.dart';
import 'package:neutrawise/widgets/buttons/primary_button.dart';

class MockLoginAuthNotifier extends AuthNotifier {
  final Future<String?> Function(String email, String password)? onSignIn;

  MockLoginAuthNotifier({this.onSignIn});

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
  Future<String?> signIn(String email, String password) async {
    state = state.copyWith(loading: true);
    if (onSignIn != null) {
      final res = await onSignIn!(email, password);
      state = state.copyWith(loading: false, error: res);
      return res;
    }
    state = state.copyWith(loading: false);
    return null;
  }
}

void main() {
  group('LoginScreen Error Handling Tests', () {
    testWidgets('shows Invalid Email popup when email format is invalid', (
      tester,
    ) async {
      final mockAuth = MockLoginAuthNotifier();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [authProvider.overrideWith(() => mockAuth)],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'invalidemail');
      await tester.enterText(textFields.at(1), 'password123');

      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();

      expect(find.text('Invalid Email'), findsOneWidget);
      expect(
        find.text(
          'Please enter a valid email address (e.g. user@example.com).',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Invalid Email'), findsNothing);
    });

    testWidgets(
      'shows Incorrect login credentials popup when right email but wrong password is submitted',
      (tester) async {
        final mockAuth = MockLoginAuthNotifier(
          onSignIn: (email, password) async {
            return 'Incorrect login credentials: The email or password you entered is incorrect.';
          },
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [authProvider.overrideWith(() => mockAuth)],
            child: const MaterialApp(home: LoginScreen()),
          ),
        );

        final textFields = find.byType(TextField);
        await tester.enterText(textFields.at(0), 'user@example.com');
        await tester.enterText(textFields.at(1), 'wrongPassword');

        await tester.tap(find.byType(PrimaryButton));
        await tester.pumpAndSettle();

        // Verify the error popup is shown
        expect(find.text('Incorrect login credentials'), findsOneWidget);

        // Verify input values are preserved (form did not reset)
        expect(find.text('user@example.com'), findsOneWidget);
        expect(find.text('wrongPassword'), findsOneWidget);

        // Dismiss dialog
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        expect(find.text('Incorrect login credentials'), findsNothing);
      },
    );

    testWidgets('shows Too many requests popup on rate limiting', (
      tester,
    ) async {
      final mockAuth = MockLoginAuthNotifier(
        onSignIn: (email, password) async {
          return 'Too many requests: You have made too many requests. Please wait a moment and try again.';
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [authProvider.overrideWith(() => mockAuth)],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'user@example.com');
      await tester.enterText(textFields.at(1), 'pass1234');

      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();

      expect(find.text('Too many requests'), findsOneWidget);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Too many requests'), findsNothing);
    });

    testWidgets('shows Network Error popup when connection fails', (
      tester,
    ) async {
      final mockAuth = MockLoginAuthNotifier(
        onSignIn: (email, password) async {
          return 'Network Error: Please check your internet connection and try again.';
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [authProvider.overrideWith(() => mockAuth)],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'user@example.com');
      await tester.enterText(textFields.at(1), 'pass1234');

      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();

      expect(find.text('Network Error'), findsOneWidget);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Network Error'), findsNothing);
    });
  });
}
