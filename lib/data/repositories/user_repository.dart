import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neutrawise/domain/models/user_profile.dart';

final userRepositoryProvider = Provider(
  (ref) => UserRepository(Supabase.instance.client),
);

final userProfileProvider = FutureProvider.family<UserProfile?, String>((
  ref,
  userId,
) async {
  return ref.watch(userRepositoryProvider).getUserProfile(userId);
});

class UserRepository {
  final SupabaseClient _client;

  UserRepository(this._client);

  Future<UserProfile?> getUserProfile(String userId) async {
    try {
      final response = await _client
          .from('users')
          .select()
          .eq('id', userId)
          .single();
      var profile = UserProfile.fromJson(response);

      final now = DateTime.now();

      // 1. Calculate active days dynamically from the time user signed up
      bool profileChanged = false;
      int calculatedDaysActive = profile.daysActive;
      if (profile.createdAt == null) {
        profile = profile.copyWith(createdAt: DateTime.now().toIso8601String());
        calculatedDaysActive = 1;
        profileChanged = true;
      } else {
        final signupDateTime = DateTime.parse(profile.createdAt!);
        final signupDate = DateTime(
          signupDateTime.year,
          signupDateTime.month,
          signupDateTime.day,
        );
        final todayDate = DateTime(now.year, now.month, now.day);
        calculatedDaysActive = todayDate.difference(signupDate).inDays + 1;
      }
      if (calculatedDaysActive < 1) calculatedDaysActive = 1;

      // 2. Check latest activity log to handle streak expiry
      int newStreak = profile.currentStreak;
      final latestLog = await _client
          .from('daily_logs')
          .select('created_at')
          .eq('user_id', userId)
          .order('date', ascending: false)
          .limit(1)
          .maybeSingle();

      if (latestLog != null) {
        final lastLogTimeStr = latestLog['created_at'] as String?;
        if (lastLogTimeStr != null) {
          final lastLogTime = DateTime.parse(lastLogTimeStr);
          // Resets to zero after 24hrs since last log
          if (now.difference(lastLogTime).inSeconds >= 24 * 3600) {
            newStreak = 0;
          }
        }
      } else {
        // No logs yet -> streak should be 0
        newStreak = 0;
      }

      // If either daysActive or currentStreak or createdAt has changed, save the profile to keep the database in sync
      if (calculatedDaysActive != profile.daysActive ||
          newStreak != profile.currentStreak ||
          profileChanged) {
        profile = profile.copyWith(
          daysActive: calculatedDaysActive,
          currentStreak: newStreak,
        );
        await saveUserProfile(profile);
      }

      return profile;
    } catch (e) {
      return null;
    }
  }

  Future<void> saveUserProfile(UserProfile profile) async {
    final json = profile.toJson();
    if (profile.createdAt == null) {
      json.remove('created_at');
    }
    await _client.from('users').upsert(json);
  }

  Future<Map<String, dynamic>> getNotificationPreferences(String userId) async {
    try {
      final response = await _client
          .from('notification_preferences')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (response != null) {
        return Map<String, dynamic>.from(response);
      }
      // Return defaults if none exist
      return {
        'daily_log_reminder': true,
        'streak_warnings': true,
        'challenge_reminders': true,
        'leaderboard_overtake': true,
        'quiz_available': true,
        'badge_earned': true,
        'level_up': true,
        'weekly_summary': true,
      };
    } catch (e) {
      return {};
    }
  }

  Future<void> saveNotificationPreferences(
    String userId,
    Map<String, dynamic> prefs,
  ) async {
    final payload = Map<String, dynamic>.from(prefs);
    payload['user_id'] = userId;
    await _client
        .from('notification_preferences')
        .upsert(payload, onConflict: 'user_id');
  }
}
