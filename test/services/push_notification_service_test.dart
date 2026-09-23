import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neutrawise/services/push_notification_service.dart';
import 'package:neutrawise/features/dashboard/screens/dashboard_screen.dart';

void main() {
  setUpAll(() {
    WidgetsFlutterBinding.ensureInitialized();
  });

  group('PushNotificationService Event Routing & Handlers Tests', () {
    test('routes daily_log_reminder to Dashboard tab 0', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Initial state is tab 0
      expect(container.read(activeTabProvider), 0);

      // Set to tab 2
      container.read(activeTabProvider.notifier).setTab(2);
      expect(container.read(activeTabProvider), 2);

      // Handle daily_log_reminder notification tap
      await PushNotificationService.handleNotificationTap(container, {
        'type': 'daily_log_reminder',
      });
      expect(container.read(activeTabProvider), 0);
    });

    test(
      'routes final_log_warning and streak_expiration to Dashboard tab 0',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        container.read(activeTabProvider.notifier).setTab(1);
        await PushNotificationService.handleNotificationTap(container, {
          'type': 'final_log_warning',
          'streak': 5,
        });
        expect(container.read(activeTabProvider), 0);

        container.read(activeTabProvider.notifier).setTab(2);
        await PushNotificationService.handleNotificationTap(container, {
          'type': 'streak_expiration',
          'streak': 5,
        });
        expect(container.read(activeTabProvider), 0);
      },
    );

    test('routes weekly_summary to Insights tab 1', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(activeTabProvider.notifier).setTab(0);
      await PushNotificationService.handleNotificationTap(container, {
        'type': 'weekly_summary',
        'co2_saved': 12.5,
        'streak': 7,
      });
      expect(container.read(activeTabProvider), 1);
    });

    test(
      'routes challenge_reminder and leaderboard_overtaken to Gamification tab 2',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        container.read(activeTabProvider.notifier).setTab(0);
        await PushNotificationService.handleNotificationTap(container, {
          'type': 'challenge_reminder',
          'challenge_name': 'No Car Day',
          'day': 1,
        });
        expect(container.read(activeTabProvider), 2);

        container.read(activeTabProvider.notifier).setTab(0);
        await PushNotificationService.handleNotificationTap(container, {
          'type': 'leaderboard_overtaken',
          'overtaker_name': 'Sarah',
        });
        expect(container.read(activeTabProvider), 2);
      },
    );

    test('routes quiz_available to Gamification tab 2', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(activeTabProvider.notifier).setTab(0);
      await PushNotificationService.handleNotificationTap(container, {
        'type': 'quiz_available',
      });
      expect(container.read(activeTabProvider), 2);
    });

    test('routes streak_milestone to Home tab 0', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(activeTabProvider.notifier).setTab(2);
      await PushNotificationService.handleNotificationTap(container, {
        'type': 'streak_milestone',
        'streak_days': 14,
        'xp': 50,
      });
      expect(container.read(activeTabProvider), 0);
    });

    test(
      'routes challenge_complete, level_up, badge_earned to Gamification tab 2',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        container.read(activeTabProvider.notifier).setTab(0);
        await PushNotificationService.handleNotificationTap(container, {
          'type': 'challenge_complete',
          'challenge_name': 'Vegan Week',
          'xp': 200,
        });
        expect(container.read(activeTabProvider), 2);

        container.read(activeTabProvider.notifier).setTab(0);
        await PushNotificationService.handleNotificationTap(container, {
          'type': 'level_up',
          'new_level': 3,
          'level_title': 'Eco Warrior',
        });
        expect(container.read(activeTabProvider), 2);

        container.read(activeTabProvider.notifier).setTab(0);
        await PushNotificationService.handleNotificationTap(container, {
          'type': 'badge_earned',
          'badge_name': 'First Step',
        });
        expect(container.read(activeTabProvider), 2);
      },
    );

    test('handles unknown or null notification data safely', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(activeTabProvider.notifier).setTab(2);

      // Null payload
      await PushNotificationService.handleNotificationTap(container, null);
      expect(container.read(activeTabProvider), 2);

      // Unknown type payload defaults to tab 0
      await PushNotificationService.handleNotificationTap(container, {
        'type': 'unrecognized_custom_event',
      });
      expect(container.read(activeTabProvider), 0);
    });

    test(
      'initialize and requestPermission execute safely without crash in headless environment',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        // Should complete without uncaught exceptions
        await expectLater(
          PushNotificationService.initialize(container),
          completes,
        );
        final permissionResult =
            await PushNotificationService.requestPermission();
        expect(permissionResult, isA<bool>());
      },
    );
  });
}
