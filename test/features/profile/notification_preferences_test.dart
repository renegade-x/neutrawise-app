import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neutrawise/features/profile/screens/notification_preferences_screen.dart';
import 'package:neutrawise/providers/auth_provider.dart';
import 'package:neutrawise/data/repositories/user_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockUserRepository implements UserRepository {
  Map<String, dynamic> preferences;
  bool saveCalled = false;

  MockUserRepository({Map<String, dynamic>? initialPrefs})
    : preferences =
          initialPrefs ??
          {
            'daily_log_reminder': true,
            'streak_warnings': true,
            'challenge_reminders': false,
            'leaderboard_overtake': true,
            'quiz_available': false,
            'weekly_summary': true,
          };

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<Map<String, dynamic>> getNotificationPreferences(String userId) async {
    return preferences;
  }

  @override
  Future<void> saveNotificationPreferences(
    String userId,
    Map<String, dynamic> prefs,
  ) async {
    saveCalled = true;
    preferences = Map<String, dynamic>.from(prefs);
  }
}

class MockNotificationAuthNotifier extends AuthNotifier {
  @override
  AuthStateData build() {
    return AuthStateData(
      isAuthenticated: true,
      user: const User(
        id: 'test_user_id',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '2026-01-01',
      ),
      loading: false,
      error: null,
      hasProfileSetup: true,
      hasSeenOnboarding: true,
    );
  }
}

void main() {
  group('NotificationPreferencesScreen Tests', () {
    testWidgets('renders all 6 notification preference options cleanly', (
      tester,
    ) async {
      final mockRepo = MockUserRepository();
      final mockAuth = MockNotificationAuthNotifier();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => mockAuth),
            userRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(home: NotificationPreferencesScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Notification Preferences'), findsOneWidget);
      expect(find.text('Daily Log Reminder'), findsOneWidget);
      expect(find.text('Streak Warnings'), findsOneWidget);
      expect(find.text('Challenge Reminders'), findsOneWidget);
      expect(find.text('Leaderboard Overtake'), findsOneWidget);
      expect(find.text('Quiz Notifications'), findsOneWidget);
      expect(find.text('Weekly Summary'), findsOneWidget);
    });

    testWidgets('toggling a notification switch triggers repository save', (
      tester,
    ) async {
      final mockRepo = MockUserRepository(
        initialPrefs: {
          'daily_log_reminder': true,
          'streak_warnings': false,
          'challenge_reminders': false,
          'leaderboard_overtake': true,
          'quiz_available': false,
          'weekly_summary': true,
        },
      );
      final mockAuth = MockNotificationAuthNotifier();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => mockAuth),
            userRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(home: NotificationPreferencesScreen()),
        ),
      );

      await tester.pumpAndSettle();

      final switches = find.byType(Switch);
      expect(switches, findsNWidgets(6));

      // Toggle the first switch (Daily Log Reminder)
      await tester.tap(switches.at(0));
      await tester.pumpAndSettle();

      expect(mockRepo.saveCalled, isTrue);
      expect(mockRepo.preferences['daily_log_reminder'], isFalse);
    });
  });
}
