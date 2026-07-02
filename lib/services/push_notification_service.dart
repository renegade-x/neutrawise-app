import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neutrawise/config/environment.dart';
import 'package:neutrawise/features/dashboard/screens/dashboard_screen.dart';

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

  static void _handleNotificationTap(
    WidgetRef ref,
    Map<String, dynamic>? data,
  ) {
    if (data == null) return;
    final type = data['type'] as String?;
    debugPrint("Notification tapped with type: $type, data: $data");

    switch (type) {
      case 'daily_log_reminder':
      case 'streak_milestone':
        ref.read(activeTabProvider.notifier).setTab(0); // Home
        break;
      case 'challenge_complete':
      case 'level_up':
      case 'badge_earned':
        ref
            .read(activeTabProvider.notifier)
            .setTab(2); // Eco Club (Gamification)
        break;
      default:
        ref.read(activeTabProvider.notifier).setTab(0); // Default Home
    }
  }
}
