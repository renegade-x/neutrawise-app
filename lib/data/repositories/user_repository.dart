import 'package:flutter/foundation.dart';
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

      // 1. Calculate active days dynamically from signup date
      bool profileNeedsUpdate = false;
      int calculatedDaysActive = profile.daysActive;
      if (profile.createdAt == null) {
        profile = profile.copyWith(createdAt: now.toIso8601String());
        calculatedDaysActive = 1;
        profileNeedsUpdate = true;
      } else {
        final signupDateTime = DateTime.tryParse(profile.createdAt!);
        if (signupDateTime != null) {
          final signupDate = DateTime(
            signupDateTime.year,
            signupDateTime.month,
            signupDateTime.day,
          );
          final todayDate = DateTime(now.year, now.month, now.day);
          calculatedDaysActive = todayDate.difference(signupDate).inDays + 1;
        }
      }
      if (calculatedDaysActive < 1) calculatedDaysActive = 1;

      // 2. Fetch daily logs to dynamically verify and recalculate true streak & last log date
      List<String> logDates = [];
      try {
        final logsResponse = await _client
            .from('daily_logs')
            .select('date')
            .eq('user_id', userId)
            .order('date', ascending: false)
            .limit(100);

        logDates =
            (logsResponse as List)
                .map((item) => (item as Map)['date'] as String?)
                .where((d) => d != null && d.isNotEmpty)
                .cast<String>()
                .toSet()
                .toList()
              ..sort((a, b) => b.compareTo(a));
      } catch (e) {
        debugPrint('Error fetching daily logs for streak calculation: $e');
      }

      int calculatedStreak = profile.effectiveStreak;
      String? latestLogDate = profile.lastLogDate;

      if (logDates.isNotEmpty) {
        latestLogDate = logDates.first;
        calculatedStreak = calculateStreakFromLogDates(
          logDates,
          now,
          profile.streakFreezeHeld,
        );
      } else if (profile.lastLogDate != null) {
        final lastDate = DateTime.tryParse(profile.lastLogDate!);
        if (lastDate != null) {
          final todayDate = DateTime(now.year, now.month, now.day);
          final diff = todayDate
              .difference(DateTime(lastDate.year, lastDate.month, lastDate.day))
              .inDays;
          if (diff > 1 && !profile.streakFreezeHeld) {
            calculatedStreak = 0;
          }
        }
      }

      final calculatedLevel = profile.effectiveLevel;
      if (calculatedLevel != profile.level) {
        profileNeedsUpdate = true;
      }

      if (calculatedDaysActive != profile.daysActive ||
          calculatedStreak != profile.currentStreak ||
          calculatedStreak != profile.streakDays ||
          latestLogDate != profile.lastLogDate ||
          profileNeedsUpdate) {
        profile = profile.copyWith(
          daysActive: calculatedDaysActive,
          currentStreak: calculatedStreak,
          streakDays: calculatedStreak,
          level: calculatedLevel,
          longestStreak: calculatedStreak > profile.longestStreak
              ? calculatedStreak
              : profile.longestStreak,
          lastLogDate: latestLogDate,
        );
        // Save asynchronously in background so response isn't blocked
        saveUserProfile(profile).catchError((e) {
          debugPrint('Background profile sync error: $e');
        });
      }

      return profile;
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
      return null;
    }
  }

  @visibleForTesting
  static int calculateStreakFromLogDates(
    List<String> logDates,
    DateTime now,
    bool streakFreezeHeld,
  ) {
    if (logDates.isEmpty) return 0;

    final today = DateTime(now.year, now.month, now.day);
    final latestLogDateParsed = DateTime.tryParse(logDates.first);

    if (latestLogDateParsed == null) return 0;
    final latestDateOnly = DateTime(
      latestLogDateParsed.year,
      latestLogDateParsed.month,
      latestLogDateParsed.day,
    );

    final daysSinceLatest = today.difference(latestDateOnly).inDays;

    if (daysSinceLatest > 1) {
      if (daysSinceLatest == 2 && streakFreezeHeld) {
        // Streak freeze preserves streak from 2 days ago
      } else {
        return 0; // Streak expired (>1 day missed without freeze)
      }
    }

    int streak = 1;
    DateTime checkDate = latestDateOnly;

    for (int i = 1; i < logDates.length; i++) {
      final prevLogDate = DateTime.tryParse(logDates[i]);
      if (prevLogDate == null) break;
      final prevDateOnly = DateTime(
        prevLogDate.year,
        prevLogDate.month,
        prevLogDate.day,
      );

      final diff = checkDate.difference(prevDateOnly).inDays;
      if (diff == 1) {
        streak++;
        checkDate = prevDateOnly;
      } else if (diff == 0) {
        continue;
      } else if (diff == 2 && streakFreezeHeld && i == 1) {
        streak++;
        checkDate = prevDateOnly;
      } else {
        break;
      }
    }

    // Streak starts on the 2nd consecutive day of logging:
    // 1 day logged -> 0 streak
    // 2 consecutive days logged -> 1 streak
    // 3 consecutive days logged -> 2 streak
    return streak > 1 ? streak - 1 : 0;
  }

  /// Columns that only the server may change (XP, level, streaks, CO2 totals).
  /// They are updated through [submitLogRewards] / [awardXp]; direct client
  /// writes are rejected by database privileges.
  static const Set<String> serverManagedColumns = {
    'xp',
    'lifetime_xp',
    'monthly_xp',
    'level',
    'current_streak',
    'streak_days',
    'longest_streak',
    'full_log_streak_days',
    'last_log_date',
    'streak_freeze_held',
    'streak_freeze_queued',
    'streak_freeze_count',
    'days_active',
    'total_co2_saved',
    'last_daily_xp_date',
    'daily_xp_from_log',
    'daily_xp_from_quiz',
  };

  /// Profile fields a client is allowed to save (everything except the
  /// server-managed columns above).
  @visibleForTesting
  static Map<String, dynamic> editableProfileJson(UserProfile profile) {
    final json = Map<String, dynamic>.from(profile.toJson());
    json.removeWhere((key, _) => serverManagedColumns.contains(key));
    if (profile.createdAt == null) {
      json.remove('created_at');
    }
    return json;
  }

  Future<void> saveUserProfile(UserProfile profile) async {
    try {
      await _client.from('users').upsert(editableProfileJson(profile));
    } catch (e) {
      debugPrint('Error saving user profile: $e');
    }
  }

  /// Applies the rewards for saving a daily log in one atomic server call:
  /// log XP (replaced per date), streak, streak milestones, freeze handling
  /// and CO2 saved. Returns the updated server-side progression values.
  Future<Map<String, dynamic>> submitLogRewards({
    required String date,
    required bool isFullLog,
    required int logXp,
    required double co2SavedDelta,
  }) async {
    final response = await _client.rpc(
      'submit_log_rewards',
      params: {
        'p_date': date,
        'p_is_full_log': isFullLog,
        'p_log_xp': logXp,
        'p_co2_saved_delta': co2SavedDelta,
      },
    );
    return Map<String, dynamic>.from(response as Map);
  }

  /// Reports the device's UTC offset so scheduled notifications (daily
  /// reminder, streak warning, weekly summary, quiz) arrive in local time.
  /// Failures are ignored; the server falls back to a country default.
  Future<void> reportUtcOffset() async {
    try {
      await _client.rpc(
        'set_my_utc_offset',
        params: {'p_minutes': DateTime.now().timeZoneOffset.inMinutes},
      );
    } catch (e) {
      debugPrint('Could not report UTC offset: $e');
    }
  }

  /// Awards quiz or challenge XP. The server pays each [key] only once.
  Future<Map<String, dynamic>> awardXp({
    required String source,
    required String key,
    required int amount,
  }) async {
    final response = await _client.rpc(
      'award_xp',
      params: {'p_source': source, 'p_key': key, 'p_amount': amount},
    );
    return Map<String, dynamic>.from(response as Map);
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
