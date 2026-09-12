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

  Future<void> saveUserProfile(UserProfile profile) async {
    final json = profile.toJson();
    if (profile.createdAt == null) {
      json.remove('created_at');
    }

    try {
      await _client.from('users').upsert(json);
    } catch (e) {
      if (e is PostgrestException && e.code == 'PGRST204') {
        final sanitized = Map<String, dynamic>.from(json);
        sanitized.remove('daily_xp_from_log');
        sanitized.remove('daily_xp_from_quiz');
        sanitized.remove('last_daily_xp_date');
        sanitized.remove('streak_freeze_queued');

        try {
          await _client.from('users').upsert(sanitized);
        } catch (retryError) {
          final Map<String, dynamic> minimal = {
            'id': profile.id,
            'name': profile.name,
            'current_streak': profile.currentStreak,
            'streak_days': profile.streakDays,
            'days_active': profile.daysActive,
            'xp': profile.effectiveXp,
            'level': profile.level,
          };
          if (profile.lastLogDate != null) {
            minimal['last_log_date'] = profile.lastLogDate;
          }
          try {
            await _client.from('users').upsert(minimal);
          } catch (e2) {
            // Ultra minimal fallback with only base legacy fields
            final ultraMinimal = {
              'id': profile.id,
              'name': profile.name,
              'xp': profile.effectiveXp,
              'level': profile.level,
              'current_streak': profile.currentStreak,
            };
            try {
              await _client.from('users').upsert(ultraMinimal);
            } catch (e3) {
              debugPrint('Failed to save ultra minimal user profile: $e3');
            }
          }
        }
      } else {
        debugPrint('Error saving user profile: $e');
      }
    }
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
