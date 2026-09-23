import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neutrawise/widgets/modals/error_popup.dart';

void main() {
  group('ErrorPopup Classification Tests', () {
    test(
      'classifies SocketException and offline messages as Network Error',
      () {
        expect(
          ErrorPopup.classify(const SocketException('Failed host lookup')),
          AppErrorType.network,
        );
        expect(
          ErrorPopup.classify(
            'ClientException: Failed host lookup: api.supabase.co',
          ),
          AppErrorType.network,
        );
        expect(
          ErrorPopup.classify('Network error: Network is unreachable'),
          AppErrorType.network,
        );
        expect(
          ErrorPopup.classify('No internet connection'),
          AppErrorType.network,
        );
      },
    );

    test('classifies rate limit / 429 as Too many requests', () {
      expect(
        ErrorPopup.classify('AuthException: 429 Too many requests'),
        AppErrorType.tooManyRequests,
      );
      expect(
        ErrorPopup.classify('over_email_send_rate_limit: rate limit exceeded'),
        AppErrorType.tooManyRequests,
      );
      expect(
        ErrorPopup.classify('RESOURCE_EXHAUSTED: quota exceeded'),
        AppErrorType.tooManyRequests,
      );
    });

    test('classifies credentials mismatch as Incorrect login credentials', () {
      expect(
        ErrorPopup.classify('Invalid login credentials'),
        AppErrorType.incorrectCredentials,
      );
      expect(
        ErrorPopup.classify('invalid_grant: wrong password'),
        AppErrorType.incorrectCredentials,
      );
      expect(
        ErrorPopup.classify('user not found'),
        AppErrorType.incorrectCredentials,
      );
    });

    test('classifies invalid email as Invalid Email', () {
      expect(
        ErrorPopup.classify('invalid email format'),
        AppErrorType.invalidEmail,
      );
      expect(
        ErrorPopup.classify('unable to validate email address'),
        AppErrorType.invalidEmail,
      );
    });

    test('classifies server 5xx and timeouts as Something went wrong', () {
      expect(
        ErrorPopup.classify(TimeoutException('Request timed out')),
        AppErrorType.somethingWentWrong,
      );
      expect(
        ErrorPopup.classify('PostgrestException 500: Internal Server Error'),
        AppErrorType.somethingWentWrong,
      );
      expect(
        ErrorPopup.classify('502 Bad Gateway'),
        AppErrorType.somethingWentWrong,
      );
      expect(
        ErrorPopup.classify('503 Service Unavailable'),
        AppErrorType.somethingWentWrong,
      );
    });
  });

  group('ErrorPopup Widget UI Tests', () {
    testWidgets('renders Network Error popup cleanly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => ErrorPopup.showNetworkError(context),
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Network Error'), findsOneWidget);
      expect(
        find.text(
          'No internet connection detected. Please check your connection and try again.',
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Network Error'), findsNothing);
    });

    testWidgets('renders Something went wrong popup cleanly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => ErrorPopup.showSomethingWentWrong(context),
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(
        find.text(
          'Our servers encountered an unexpected issue or the request timed out. Please try again later.',
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    });

    testWidgets('renders Too many requests popup cleanly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => ErrorPopup.showTooManyRequests(context),
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Too many requests'), findsOneWidget);
      expect(
        find.text(
          'You have made too many requests in a short period. Please wait a moment and try again.',
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.hourglass_top_rounded), findsOneWidget);
    });

    testWidgets('renders Incorrect login credentials popup cleanly', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => ErrorPopup.showIncorrectCredentials(context),
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Incorrect login credentials'), findsOneWidget);
      expect(
        find.text(
          'The email address or password you entered is incorrect. Please check your credentials and try again.',
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.lock_person_rounded), findsOneWidget);
    });

    testWidgets('renders Invalid Email popup cleanly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => ErrorPopup.showInvalidEmail(context),
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Invalid Email'), findsOneWidget);
      expect(
        find.text(
          'Please enter a valid email address format (e.g. user@example.com).',
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.mark_email_unread_rounded), findsOneWidget);
    });

    testWidgets('supports onRetry callback', (tester) async {
      bool retryTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => ErrorPopup.showNetworkError(
                context,
                onRetry: () => retryTriggered = true,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(retryTriggered, isTrue);
      expect(find.text('Network Error'), findsNothing);
    });
  });
}
