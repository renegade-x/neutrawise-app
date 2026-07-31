import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neutrawise/config/environment.dart';
import 'package:neutrawise/features/dashboard/screens/dashboard_screen.dart';
import 'package:neutrawise/widgets/celebration_modal.dart';
import 'package:neutrawise/providers/auth_provider.dart';
import 'package:neutrawise/domain/gamification/quiz_engine.dart';
import 'package:neutrawise/data/repositories/quiz_repository.dart';
import 'package:neutrawise/features/gamification/widgets/quiz_modal.dart';
import 'package:neutrawise/routing/router.dart';

class PushNotificationService {
  static void initialize(WidgetRef ref) {
    final appId = Environment.onesignalAppId;
    if (appId.isEmpty) {
      debugPrint("OneSignal App ID is empty. Skipping initialization.");
      return;
    }

    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    OneSignal.initialize(appId);

    // Request push notification permission
    OneSignal.Notifications.requestPermission(true);

    // Handle notification tap
    OneSignal.Notifications.addClickListener((event) {
      final data = event.notification.additionalData;
      _handleNotificationTap(ref, data);
    });

    // Handle notification received (foreground)
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      event.notification.display();
    });
  }

  static void login(String userId) {
    final appId = Environment.onesignalAppId;
    if (appId.isEmpty) return;
    OneSignal.login(userId);
    debugPrint("OneSignal logged in with external user ID: $userId");
  }

  static void logout() {
    final appId = Environment.onesignalAppId;
    if (appId.isEmpty) return;
    OneSignal.logout();
    debugPrint("OneSignal logged out");
  }

  static Future<void> _handleNotificationTap(
    WidgetRef ref,
    Map<String, dynamic>? data,
  ) async {
    if (data == null) return;
    final type = data['type'] as String?;
    debugPrint("Notification tapped with type: $type, data: $data");

    final context = rootNavigatorKey.currentContext;

    switch (type) {
      case 'daily_log_reminder':
      case 'final_log_warning':
      case 'streak_expiration':
        ref.read(activeTabProvider.notifier).setTab(0); // Home / Dashboard
        break;

      case 'weekly_summary':
        ref.read(activeTabProvider.notifier).setTab(1); // Insights Screen
        break;

      case 'challenge_reminder':
      case 'leaderboard_overtaken':
        ref
            .read(activeTabProvider.notifier)
            .setTab(2); // Gamification (Eco Club)
        break;

      case 'quiz_available':
        ref
            .read(activeTabProvider.notifier)
            .setTab(2); // Gamification (Eco Club)
        if (context != null) {
          final user = ref.read(authProvider).user;
          if (user != null) {
            final activeQuizData = await ref.read(
              activeQuizProvider(user.id).future,
            );
            final quiz = activeQuizData['quiz'] as Quiz?;
            final status = activeQuizData['status'] as QuizStatus?;
            if (quiz != null &&
                status == QuizStatus.available &&
                context.mounted) {
              QuizModal.show(context, user.id, quiz);
            }
          }
        }
        break;

      case 'streak_milestone':
        ref.read(activeTabProvider.notifier).setTab(0); // Home
        if (context != null) {
          final streakDays = data['streak_days'] ?? 7;
          CelebrationModal.showChallengeComplete(
            context,
            "🔥 $streakDays-Day Streak Milestone!",
            50,
          );
        }
        break;

      case 'challenge_complete':
        ref.read(activeTabProvider.notifier).setTab(2); // Gamification
        if (context != null) {
          final challengeName =
              data['challenge_name'] as String? ?? 'Eco Challenge';
          final xp = data['xp'] is int
              ? data['xp'] as int
              : int.tryParse('${data['xp']}') ?? 100;
          CelebrationModal.showChallengeComplete(context, challengeName, xp);
        }
        break;

      case 'level_up':
        ref.read(activeTabProvider.notifier).setTab(2); // Gamification
        if (context != null) {
          final newLevel = data['new_level'] is int
              ? data['new_level'] as int
              : int.tryParse('${data['new_level']}') ?? 2;
          final levelTitle = data['level_title'] as String? ?? 'Eco Sprout';
          CelebrationModal.showLevelUp(context, newLevel, levelTitle);
        }
        break;

      case 'badge_earned':
        ref.read(activeTabProvider.notifier).setTab(2); // Gamification / Badges
        if (context != null) {
          final badgeName = data['badge_name'] as String? ?? 'Special Badge';
          CelebrationModal.showBadgeEarned(
            context,
            badgeName,
            "Awarded for completing carbon reduction achievements!",
          );
        }
        break;

      default:
        ref.read(activeTabProvider.notifier).setTab(0); // Default Home
    }
  }
}
