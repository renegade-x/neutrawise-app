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
      return UserProfile.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  Future<void> saveUserProfile(UserProfile profile) async {
    await _client.from('users').upsert(profile.toJson());
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
