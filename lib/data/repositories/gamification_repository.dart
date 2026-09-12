import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neutrawise/domain/models/daily_log.dart';
import 'package:neutrawise/domain/gamification/gamification_engine.dart';

final gamificationRepositoryProvider = Provider<GamificationRepository>((ref) {
  return GamificationRepository(Supabase.instance.client);
});

final userBadgesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      userId,
    ) async {
      final repo = ref.watch(gamificationRepositoryProvider);
      return repo.getUserBadges(userId);
    });

final activeChallengesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      userId,
    ) async {
      final repo = ref.watch(gamificationRepositoryProvider);
      return repo.getActiveChallenges(userId);
    });

final userChallengesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      userId,
    ) async {
      final repo = ref.watch(gamificationRepositoryProvider);
      return repo.getAllUserChallenges(userId);
    });

final todayChallengeQualificationsProvider =
    FutureProvider.family<Map<String, bool>, String>((ref, userId) async {
      final repo = ref.watch(gamificationRepositoryProvider);
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      return repo.getTodayChallengeQualifications(userId, todayStr);
    });

final availableChallengesCatalogProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
      final repo = ref.watch(gamificationRepositoryProvider);
      return repo.getAvailableChallengesCatalog();
    });

final badgeCatalogProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final repo = ref.watch(gamificationRepositoryProvider);
  return repo.getBadgeCatalog();
});

class GamificationRepository {
  final SupabaseClient _client;
  final Map<String, Map<String, bool>> _memoryDailyProgress = {};

  GamificationRepository(this._client);

  /// Exact 15 Challenges specified in Section 6.7 of NeutraWise Gamification v2 Spec
  static const List<Map<String, dynamic>> defaultChallenges = [
    // Transport 🚗 (7)
    {
      'id': 'no_car_day',
      'name': 'No Car Day',
      'category': 'Transport',
      'difficulty': 'Easy',
      'duration': 1,
      'duration_days': 1,
      'required_days': 1,
      'consecutive': false,
      'xp': 100,
      'strategy': 'LOG_FIELD_ZERO',
      'completion_criteria': {'field': 'car_km'},
      'strategy_params': {'field': 'car_km'},
    },
    {
      'id': 'no_car_weekend',
      'name': 'No Car Weekend',
      'category': 'Transport',
      'difficulty': 'Easy',
      'duration': 2,
      'duration_days': 2,
      'required_days': 2,
      'consecutive': true,
      'xp': 100,
      'strategy': 'LOG_FIELD_ZERO',
      'completion_criteria': {'field': 'car_km', 'start_day': 'saturday'},
      'strategy_params': {'field': 'car_km', 'start_day': 'saturday'},
    },
    {
      'id': 'walk_7_days',
      'name': 'Walk 7 Days',
      'category': 'Transport',
      'difficulty': 'Easy',
      'duration': 10,
      'duration_days': 10,
      'required_days': 7,
      'consecutive': false,
      'xp': 100,
      'strategy': 'TRANSPORT_ANY_MATCH',
      'completion_criteria': {
        'accepted_values': ['walking'],
      },
      'strategy_params': {
        'accepted_values': ['walking'],
      },
    },
    {
      'id': 'cycle_to_work_week',
      'name': 'Cycle to Work Week',
      'category': 'Transport',
      'difficulty': 'Medium',
      'duration': 7,
      'duration_days': 7,
      'required_days': 5,
      'consecutive': false,
      'xp': 200,
      'strategy': 'TRANSPORT_ANY_MATCH',
      'completion_criteria': {
        'accepted_values': ['cycling'],
      },
      'strategy_params': {
        'accepted_values': ['cycling'],
      },
    },
    {
      'id': 'no_car_week',
      'name': 'No Car Week',
      'category': 'Transport',
      'difficulty': 'Medium',
      'duration': 10,
      'duration_days': 10,
      'required_days': 7,
      'consecutive': true,
      'xp': 200,
      'strategy': 'LOG_FIELD_ZERO',
      'completion_criteria': {'field': 'car_km'},
      'strategy_params': {'field': 'car_km'},
    },
    {
      'id': 'carpool_champion',
      'name': 'Carpool Champion',
      'category': 'Transport',
      'difficulty': 'Medium',
      'duration': 7,
      'duration_days': 7,
      'required_days': 5,
      'consecutive': false,
      'xp': 200,
      'strategy': 'TRANSPORT_ANY_MATCH',
      'completion_criteria': {
        'accepted_values': ['rideshare'],
      },
      'strategy_params': {
        'accepted_values': ['rideshare'],
      },
    },
    {
      'id': 'public_transport_month',
      'name': 'Public Transport Month',
      'category': 'Transport',
      'difficulty': 'Hard',
      'duration': 35,
      'duration_days': 35,
      'required_days': 30,
      'consecutive': true,
      'xp': 400,
      'strategy': 'TRANSPORT_ALL_MATCH',
      'completion_criteria': {
        'accepted_values': ['bus', 'train', 'metro', 'tram', 'ferry'],
      },
      'strategy_params': {
        'accepted_values': ['bus', 'train', 'metro', 'tram', 'ferry'],
      },
    },
    // Food 🥗 (3)
    {
      'id': 'meat_free_day',
      'name': 'Meat-Free Day',
      'category': 'Food',
      'difficulty': 'Easy',
      'duration': 1,
      'duration_days': 1,
      'required_days': 1,
      'consecutive': false,
      'xp': 100,
      'strategy': 'FOOD_NONE_MATCH',
      'completion_criteria': {
        'excluded_values': [
          'beef',
          'pork',
          'poultry',
          'chicken',
          'lamb',
          'fish',
          'seafood',
        ],
      },
      'strategy_params': {
        'excluded_values': [
          'beef',
          'pork',
          'poultry',
          'chicken',
          'lamb',
          'fish',
          'seafood',
        ],
      },
    },
    {
      'id': 'plant_based_week',
      'name': 'Plant-Based Week',
      'category': 'Food',
      'difficulty': 'Medium',
      'duration': 9,
      'duration_days': 9,
      'required_days': 7,
      'consecutive': true,
      'xp': 200,
      'strategy': 'FOOD_ALL_MATCH',
      'completion_criteria': {
        'accepted_values': [
          'vegetables',
          'legumes',
          'tofu',
          'soy',
          'fruit',
          'grains',
          'nuts',
          'seeds',
        ],
      },
      'strategy_params': {
        'accepted_values': [
          'vegetables',
          'legumes',
          'tofu',
          'soy',
          'fruit',
          'grains',
          'nuts',
          'seeds',
        ],
      },
    },
    {
      'id': 'vegan_challenge',
      'name': 'Vegan Challenge',
      'category': 'Food',
      'difficulty': 'Hard',
      'duration': 35,
      'duration_days': 35,
      'required_days': 30,
      'consecutive': true,
      'xp': 400,
      'strategy': 'FOOD_ALL_MATCH',
      'completion_criteria': {
        'accepted_values': [
          'vegetables',
          'legumes',
          'tofu',
          'soy',
          'fruit',
          'grains',
          'nuts',
          'seeds',
        ],
      },
      'strategy_params': {
        'accepted_values': [
          'vegetables',
          'legumes',
          'tofu',
          'soy',
          'fruit',
          'grains',
          'nuts',
          'seeds',
        ],
      },
    },
    // Energy ⚡ (4)
    {
      'id': 'unplug_day',
      'name': 'Unplug Day',
      'category': 'Energy',
      'difficulty': 'Easy',
      'duration': 1,
      'duration_days': 1,
      'required_days': 1,
      'consecutive': false,
      'xp': 100,
      'strategy': 'LOG_TAG_PRESENT',
      'completion_criteria': {'tag': 'unplugged_devices'},
      'strategy_params': {'tag': 'unplugged_devices'},
    },
    {
      'id': 'cold_shower_week',
      'name': 'Cold Shower Week',
      'category': 'Energy',
      'difficulty': 'Easy',
      'duration': 10,
      'duration_days': 10,
      'required_days': 7,
      'consecutive': false,
      'xp': 100,
      'strategy': 'LOG_TAG_PRESENT',
      'completion_criteria': {'tag': 'cold_shower'},
      'strategy_params': {'tag': 'cold_shower'},
    },
    {
      'id': 'screen_time_cutback',
      'name': 'Screen Time Cutback',
      'category': 'Energy',
      'difficulty': 'Easy',
      'duration': 10,
      'duration_days': 10,
      'required_days': 7,
      'consecutive': false,
      'xp': 100,
      'strategy': 'LOG_TAG_PRESENT',
      'completion_criteria': {'tag': 'low_screen_time'},
      'strategy_params': {'tag': 'low_screen_time'},
    },
    {
      'id': 'no_ac_week',
      'name': 'No AC Week',
      'category': 'Energy',
      'difficulty': 'Medium',
      'duration': 7,
      'duration_days': 7,
      'required_days': 7,
      'consecutive': true,
      'xp': 200,
      'strategy': 'LOG_TAG_ABSENT',
      'completion_criteria': {'tag': 'ac_used'},
      'strategy_params': {'tag': 'ac_used'},
    },
    // Nature 🌳 (1)
    {
      'id': '100_day_green_journey',
      'name': '100-Day Green Journey',
      'category': 'Nature',
      'difficulty': 'Hard',
      'duration': 100,
      'duration_days': 100,
      'required_days': 100,
      'consecutive': true,
      'xp': 400,
      'strategy': 'APP_BEHAVIOR',
      'completion_criteria': {'metric': 'consecutive_active_days'},
      'strategy_params': {'metric': 'consecutive_active_days'},
    },
  ];

  static const List<Map<String, dynamic>> defaultBadgeCatalog = [
    {
      'id': 'b1',
      'badge_name': 'Road to Green 🚗',
      'category': 'Transport',
      'description':
          'Complete Transport challenges (Bronze: 3, Silver: 7, Gold: 12)',
      'icon_name': 'directions_car',
      'is_special': false,
    },
    {
      'id': 'b2',
      'badge_name': 'Conscious Plate 🥗',
      'category': 'Food',
      'description':
          'Complete Food challenges (Bronze: 3, Silver: 7, Gold: 12)',
      'icon_name': 'restaurant',
      'is_special': false,
    },
    {
      'id': 'b3',
      'badge_name': 'Power Saver ⚡',
      'category': 'Energy',
      'description':
          'Complete Energy challenges (Bronze: 3, Silver: 7, Gold: 12)',
      'icon_name': 'bolt',
      'is_special': false,
    },
    {
      'id': 'b4',
      'badge_name': 'Nature Keeper 🌳',
      'category': 'Nature',
      'description':
          'Complete Nature challenges (Bronze: 1, Silver: 2, Gold: 3)',
      'icon_name': 'park',
      'is_special': false,
    },
    {
      'id': 's0',
      'badge_name': 'Eco Newcomer ✨',
      'category': 'Special',
      'description': 'Submitted first daily activity log',
      'icon_name': 'auto_awesome',
      'is_special': true,
    },
    {
      'id': 's1',
      'badge_name': 'Week Warrior 🔥',
      'category': 'Special',
      'description': 'Maintained a 7-day logging streak',
      'icon_name': 'local_fire_department',
      'is_special': true,
    },
    {
      'id': 's2',
      'badge_name': 'Fortnight Fighter 💪',
      'category': 'Special',
      'description': 'Maintained a 14-day logging streak',
      'icon_name': 'fitness_center',
      'is_special': true,
    },
    {
      'id': 's3',
      'badge_name': 'Monthly Maven 🌿',
      'category': 'Special',
      'description': 'Maintained a 30-day logging streak',
      'icon_name': 'calendar_today',
      'is_special': true,
    },
    {
      'id': 's4',
      'badge_name': 'Eco Consistent 🌍',
      'category': 'Special',
      'description': 'Maintained a 60-day logging streak',
      'icon_name': 'public',
      'is_special': true,
    },
    {
      'id': 's5',
      'badge_name': 'Century Eco 🏆',
      'category': 'Special',
      'description': 'Maintained a 100-day logging streak',
      'icon_name': 'workspace_premium',
      'is_special': true,
    },
    {
      'id': 's6',
      'badge_name': 'Quiz Whiz 🧠',
      'category': 'Special',
      'description': 'Scored 5 perfect quiz attempts',
      'icon_name': 'psychology',
      'is_special': true,
    },
    {
      'id': 's7',
      'badge_name': 'All-Rounder 🌟',
      'category': 'Special',
      'description': 'Completed at least 1 challenge in each active category',
      'icon_name': 'star',
      'is_special': true,
    },
    {
      'id': 's8',
      'badge_name': 'Streak Saver 🛡️',
      'category': 'Special',
      'description': 'Used a streak freeze to preserve a streak',
      'icon_name': 'shield',
      'is_special': true,
    },
    {
      'id': 's9',
      'badge_name': 'Carbon Neutral 🌍',
      'category': 'Special',
      'description': 'Reached Level 10 Carbon Neutral mastery',
      'icon_name': 'eco',
      'is_special': true,
    },
    {
      'id': 's10',
      'badge_name': 'Leaderboard Leader 👑',
      'category': 'Special',
      'description': 'Finished Rank #1 on monthly global leaderboard',
      'icon_name': 'emoji_events',
      'is_special': true,
    },
  ];

  /// Fetch available challenges catalog dynamically from DB, or fallback to static defaults
  Future<List<Map<String, dynamic>>> getAvailableChallengesCatalog() async {
    try {
      final List<dynamic> response = await _client.from('challenges').select();
      if (response.isNotEmpty) {
        return response.map((item) {
          final map = Map<String, dynamic>.from(item as Map);
          return {
            'id': map['id'] as String,
            'name': map['name'] as String,
            'category': map['category'] as String,
            'difficulty': map['difficulty'] as String,
            'duration':
                map['duration_days'] as int? ?? map['duration'] as int? ?? 7,
            'duration_days': map['duration_days'] as int? ?? 7,
            'required_days': map['required_days'] as int? ?? 7,
            'consecutive': map['consecutive'] as bool? ?? false,
            'xp': map['xp_reward'] as int? ?? 100,
            'strategy': map['strategy'] as String? ?? 'APP_BEHAVIOR',
            'strategy_params':
                map['completion_criteria'] ?? map['strategy_params'] ?? {},
            'description': map['description'] as String? ?? '',
            'icon_name': map['icon_name'] as String? ?? 'eco',
          };
        }).toList();
      }
    } catch (_) {}
    return defaultChallenges;
  }

  /// Fetch full badge catalog dynamically from DB, or fallback to static defaults
  Future<List<Map<String, dynamic>>> getBadgeCatalog() async {
    try {
      final List<dynamic> response = await _client
          .from('badge_catalog')
          .select();
      if (response.isNotEmpty) {
        return List<Map<String, dynamic>>.from(response);
      }
    } catch (_) {}
    return defaultBadgeCatalog;
  }

  Future<List<Map<String, dynamic>>> getUserBadges(String userId) async {
    try {
      final List<dynamic> response = await _client
          .from('badges')
          .select()
          .eq('user_id', userId);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getActiveChallenges(String userId) async {
    try {
      final List<dynamic> response = await _client
          .from('user_challenges')
          .select()
          .eq('user_id', userId)
          .isFilter('completed_at', null);

      final list = List<Map<String, dynamic>>.from(response);
      return list
          .where(
            (item) =>
                item['status'] != 'failed' && item['status'] != 'completed',
          )
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAllUserChallenges(String userId) async {
    try {
      final List<dynamic> response = await _client
          .from('user_challenges')
          .select()
          .eq('user_id', userId);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  Future<void> enrollInChallenge(
    String userId,
    Map<String, dynamic> challenge,
  ) async {
    final now = DateTime.now();
    final durationDays =
        challenge['duration_days'] as int? ??
        challenge['duration'] as int? ??
        7;
    final requiredDays = challenge['required_days'] as int? ?? durationDays;
    final isConsecutive = challenge['consecutive'] as bool? ?? false;
    final strategy = challenge['strategy'] as String? ?? 'APP_BEHAVIOR';
    final params =
        challenge['strategy_params'] ?? challenge['completion_criteria'] ?? {};

    final fullPayload = {
      'user_id': userId,
      'challenge_id': challenge['id'],
      'challenge_name': challenge['name'],
      'category': challenge['category'],
      'difficulty': challenge['difficulty'],
      'duration_days': durationDays,
      'required_days': requiredDays,
      'consecutive': isConsecutive,
      'strategy': strategy,
      'completion_criteria': params,
      'xp_reward': challenge['xp'] ?? 100,
      'progress_percent': 0,
      'days_passed': 0,
      'status': 'in_progress',
      'started_at': now.toIso8601String(),
      'completed_at': null,
    };

    try {
      await _client.from('user_challenges').upsert(fullPayload);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST204' || e.message.contains('column')) {
        debugPrint(
          'Schema cache mismatch on user_challenges, retrying with legacy columns: ${e.message}',
        );
        final legacyPayload = {
          'user_id': userId,
          'challenge_id': challenge['id'],
          'challenge_name': challenge['name'],
          'category': challenge['category'],
          'difficulty': challenge['difficulty'],
          'duration_days': durationDays,
          'xp_reward': challenge['xp'] ?? 100,
          'progress_percent': 0,
          'started_at': now.toIso8601String(),
          'completed_at': null,
        };
        await _client.from('user_challenges').upsert(legacyPayload);
      } else {
        rethrow;
      }
    } catch (e) {
      debugPrint('Error enrolling in challenge: $e');
    }
  }

  /// Store daily qualification flag for (user_id, challenge_id, date)
  Future<void> upsertDailyChallengeProgress({
    required String userId,
    required String challengeId,
    required String date,
    required bool qualified,
  }) async {
    final key = '$userId:$date';
    _memoryDailyProgress.putIfAbsent(key, () => {})[challengeId] = qualified;

    try {
      await _client.from('challenge_daily_progress').upsert({
        'user_id': userId,
        'challenge_id': challengeId,
        'date': date,
        'qualified': qualified,
      }, onConflict: 'user_id, challenge_id, date');
    } catch (e) {
      if (e is PostgrestException && e.code == 'PGRST205') {
        // Silent fallback to in-memory progress tracking when table does not exist in Supabase schema
      } else {
        debugPrint('Daily challenge progress storage fallback: $e');
      }
    }
  }

  Future<bool> getDailyChallengeQualification({
    required String userId,
    required String challengeId,
    required String date,
  }) async {
    final key = '$userId:$date';
    if (_memoryDailyProgress.containsKey(key) &&
        _memoryDailyProgress[key]!.containsKey(challengeId)) {
      return _memoryDailyProgress[key]![challengeId]!;
    }

    try {
      final response = await _client
          .from('challenge_daily_progress')
          .select('qualified')
          .eq('user_id', userId)
          .eq('challenge_id', challengeId)
          .eq('date', date)
          .maybeSingle();

      if (response != null && response['qualified'] != null) {
        final val = response['qualified'] as bool;
        _memoryDailyProgress.putIfAbsent(key, () => {})[challengeId] = val;
        return val;
      }
    } catch (_) {}

    return false;
  }

  Future<Map<String, bool>> getTodayChallengeQualifications(
    String userId,
    String date,
  ) async {
    final key = '$userId:$date';
    final result = <String, bool>{};

    if (_memoryDailyProgress.containsKey(key)) {
      result.addAll(_memoryDailyProgress[key]!);
    }

    try {
      final List<dynamic> response = await _client
          .from('challenge_daily_progress')
          .select('challenge_id, qualified')
          .eq('user_id', userId)
          .eq('date', date);

      for (final item in response) {
        final cId = item['challenge_id'] as String;
        final val = item['qualified'] as bool;
        result[cId] = val;
        _memoryDailyProgress.putIfAbsent(key, () => {})[cId] = val;
      }
    } catch (_) {}

    return result;
  }

  /// REVISED AUTOMATIC EVALUATION ENGINE (Option B Spec)
  /// Re-evaluates today's qualifying flag on every log submission/update.
  /// Does NOT modify user_challenges.days_passed directly!
  /// Offline Sync Rule: If logDate < today (audited date), skips evaluation. Past audit results remain final!
  Future<List<Map<String, dynamic>>> evaluateChallengesForUser(
    String userId,
    DailyLog dailyLog,
  ) async {
    final List<Map<String, dynamic>> completedChallenges = [];
    try {
      final activeChallenges = await getActiveChallenges(userId);
      if (activeChallenges.isEmpty) return completedChallenges;

      final logDateStr = dailyLog.date.contains('T')
          ? dailyLog.date.split('T')[0]
          : dailyLog.date;
      final logDateTime = DateTime.parse(logDateStr);
      final logDate = DateTime(
        logDateTime.year,
        logDateTime.month,
        logDateTime.day,
      );

      final now = DateTime.now();
      final todayDate = DateTime(now.year, now.month, now.day);

      // OFFLINE SYNC RULE:
      // An offline log that syncs for a past date that has already been audited (logDate < today)
      // does NOT retroactively adjust challenge progress.
      if (logDate.isBefore(todayDate)) {
        debugPrint(
          'Log date $logDateStr is in the past (< today). Skipping challenge evaluation.',
        );
        return completedChallenges;
      }

      final catalogMap = {
        for (var c in defaultChallenges) c['id'] as String: c,
      };

      for (final userChallenge in activeChallenges) {
        final challengeId = userChallenge['challenge_id'] as String;
        final catalogDef = catalogMap[challengeId] ?? {};

        final strategy =
            (userChallenge['strategy'] as String?) ??
            (catalogDef['strategy'] as String?) ??
            'APP_BEHAVIOR';
        final params =
            (userChallenge['completion_criteria'] as Map<String, dynamic>?) ??
            (catalogDef['strategy_params'] as Map<String, dynamic>?) ??
            (catalogDef['completion_criteria'] as Map<String, dynamic>?) ??
            {};
        final windowDays =
            (userChallenge['duration_days'] as int?) ??
            (catalogDef['duration_days'] as int?) ??
            7;

        final startedAtStr = userChallenge['started_at'] as String?;
        final startedAt = startedAtStr != null
            ? DateTime.tryParse(startedAtStr)
            : now;
        final deadlineAt = startedAt?.add(Duration(days: windowDays));

        // Expiration check
        if (deadlineAt != null && now.isAfter(deadlineAt)) {
          await _updateUserChallengeSafe(userId, challengeId, {
            'status': 'failed',
          });
          continue;
        }

        // Evaluate daily strategy
        final passed = GamificationEngine.evaluateStrategy(
          strategy: strategy,
          params: params,
          dailyResult: dailyLog,
        );

        // UPSERT challenge_daily_progress SET qualified = passed
        await upsertDailyChallengeProgress(
          userId: userId,
          challengeId: challengeId,
          date: logDateStr,
          qualified: passed,
        );

        // NOTE: days_passed in user_challenges is NOT modified here.
        // It is only committed during the Midnight Audit.
      }
    } catch (e) {
      debugPrint('Error evaluating challenges for user: $e');
    }
    return completedChallenges;
  }

  /// REVISED MIDNIGHT AUDIT (Option B Spec)
  /// Advances days_passed and handles completion / failure based on daily qualification records.
  Future<List<Map<String, dynamic>>> performMidnightAudit(
    String userId, [
    DateTime? auditDate,
  ]) async {
    final List<Map<String, dynamic>> completedChallenges = [];
    try {
      final targetDate =
          auditDate ?? DateTime.now().subtract(const Duration(days: 1));
      final auditDateStr =
          '${targetDate.year.toString().padLeft(4, '0')}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';

      final activeChallenges = await getActiveChallenges(userId);
      if (activeChallenges.isEmpty) return completedChallenges;

      final catalogMap = {
        for (var c in defaultChallenges) c['id'] as String: c,
      };

      for (final userChallenge in activeChallenges) {
        final challengeId = userChallenge['challenge_id'] as String;
        final catalogDef = catalogMap[challengeId] ?? {};

        final strategy =
            (userChallenge['strategy'] as String?) ??
            (catalogDef['strategy'] as String?) ??
            'APP_BEHAVIOR';
        final requiredDays =
            (userChallenge['required_days'] as int?) ??
            (catalogDef['required_days'] as int?) ??
            (userChallenge['duration_days'] as int?) ??
            (catalogDef['duration_days'] as int?) ??
            1;
        final windowDays =
            (userChallenge['duration_days'] as int?) ??
            (catalogDef['duration_days'] as int?) ??
            requiredDays;
        final isConsecutive =
            (userChallenge['consecutive'] as bool?) ??
            (catalogDef['consecutive'] as bool?) ??
            false;
        final baseXP =
            (userChallenge['xp_reward'] as int?) ??
            (catalogDef['xp'] as int?) ??
            100;
        final difficulty =
            (userChallenge['difficulty'] as String?) ??
            (catalogDef['difficulty'] as String?) ??
            'Easy';
        final category =
            (userChallenge['category'] as String?) ??
            (catalogDef['category'] as String?) ??
            'Transport';

        int currentDaysPassed = (userChallenge['days_passed'] as int?) ?? 0;
        final startedAtStr = userChallenge['started_at'] as String?;
        final startedAt = startedAtStr != null
            ? DateTime.tryParse(startedAtStr)
            : DateTime.now();

        // Read qualification for audit date (false if no record logged)
        final qualified = await getDailyChallengeQualification(
          userId: userId,
          challengeId: challengeId,
          date: auditDateStr,
        );

        if (qualified) {
          currentDaysPassed += 1;
        } else if (isConsecutive || strategy == 'APP_BEHAVIOR') {
          currentDaysPassed = 0;
        }
        // Non-consecutive + not qualified: no change to currentDaysPassed

        final progressPercent = min(
          100,
          ((currentDaysPassed / requiredDays) * 100).toInt(),
        );

        if (currentDaysPassed >= requiredDays) {
          // CHALLENGE COMPLETED!
          final previousCompletions = await _getCompletionCount(
            userId,
            challengeId,
          );
          final completionNumber = previousCompletions + 1;

          final decayedXP = GamificationEngine.calculateDecayedXP(
            baseXP,
            completionNumber,
          );
          final cooldownDays = GamificationEngine.calculateCooldownDays(
            difficulty: difficulty,
            completionNumber: completionNumber,
            durationDays: windowDays,
          );
          final cooldownEndsAt = DateTime.now().add(
            Duration(days: cooldownDays),
          );

          await _updateUserChallengeSafe(userId, challengeId, {
            'days_passed': currentDaysPassed,
            'progress_percent': 100,
            'status': 'completed',
            'completed_at': DateTime.now().toIso8601String(),
            'cooldown_ends_at': cooldownEndsAt.toIso8601String(),
            'completion_number': completionNumber,
            'xp_earned': decayedXP,
          });

          try {
            await _client.from('challenge_completions').insert({
              'user_id': userId,
              'challenge_id': challengeId,
              'completed_at': DateTime.now().toIso8601String(),
              'xp_awarded': decayedXP,
              'completion_num': completionNumber,
            });
          } catch (e) {
            debugPrint('Silent fallback recording challenge_completion: $e');
          }

          await _awardChallengeXpToUser(userId, decayedXP);
          await checkCategoryAndSpecialBadges(userId, category);

          completedChallenges.add({
            ...userChallenge,
            'name':
                userChallenge['challenge_name'] ??
                catalogDef['name'] ??
                'Eco Challenge',
            'xp_earned': decayedXP,
          });
        } else {
          await _updateUserChallengeSafe(userId, challengeId, {
            'days_passed': currentDaysPassed,
            'progress_percent': progressPercent,
          });
        }

        // Window Expiration Check
        if (startedAt != null && currentDaysPassed < requiredDays) {
          final daysSpent = DateTime.now().difference(startedAt).inDays;
          if (daysSpent > windowDays) {
            await _updateUserChallengeSafe(userId, challengeId, {
              'status': 'failed',
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error performing midnight audit: $e');
    }
    return completedChallenges;
  }

  Future<void> _updateUserChallengeSafe(
    String userId,
    String challengeId,
    Map<String, dynamic> updateData,
  ) async {
    try {
      await _client
          .from('user_challenges')
          .update(updateData)
          .eq('user_id', userId)
          .eq('challenge_id', challengeId);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST204' || e.message.contains('column')) {
        debugPrint(
          'Schema mismatch on user_challenges update, retrying safe fields: ${e.message}',
        );
        final safeData = <String, dynamic>{};
        if (updateData.containsKey('progress_percent')) {
          safeData['progress_percent'] = updateData['progress_percent'];
        }
        if (updateData.containsKey('completed_at')) {
          safeData['completed_at'] = updateData['completed_at'];
        }
        if (safeData.isNotEmpty) {
          await _client
              .from('user_challenges')
              .update(safeData)
              .eq('user_id', userId)
              .eq('challenge_id', challengeId);
        }
      } else {
        rethrow;
      }
    } catch (e) {
      debugPrint('Error updating user challenge safely: $e');
    }
  }

  Future<int> _getCompletionCount(String userId, String challengeId) async {
    try {
      final response = await _client
          .from('user_challenges')
          .select('completion_number')
          .eq('user_id', userId)
          .eq('challenge_id', challengeId)
          .maybeSingle();
      if (response != null && response['completion_number'] != null) {
        return response['completion_number'] as int;
      }
    } catch (_) {}
    return 0;
  }

  Future<void> _awardChallengeXpToUser(String userId, int xpAmount) async {
    try {
      final userProfile = await _client
          .from('users')
          .select('lifetime_xp, monthly_xp, xp, level')
          .eq('id', userId)
          .single();

      final currentLifetimeXp =
          (userProfile['lifetime_xp'] as int?) ??
          (userProfile['xp'] as int?) ??
          0;
      final currentMonthlyXp = (userProfile['monthly_xp'] as int?) ?? 0;

      final newLifetimeXp = currentLifetimeXp + xpAmount;
      final newMonthlyXp = currentMonthlyXp + xpAmount;
      final newLevel = GamificationEngine.getLevelFromXp(newLifetimeXp);

      final updatePayload = <String, dynamic>{
        'xp': newLifetimeXp,
        'level': newLevel,
      };
      if (userProfile.containsKey('lifetime_xp')) {
        updatePayload['lifetime_xp'] = newLifetimeXp;
      }
      if (userProfile.containsKey('monthly_xp')) {
        updatePayload['monthly_xp'] = newMonthlyXp;
      }

      await _client.from('users').update(updatePayload).eq('id', userId);
    } catch (e) {
      debugPrint('Error awarding challenge XP to user: $e');
    }
  }

  /// Category Badges (Section 7.1) & All-Rounder Special Badge (Section 7.2)
  Future<void> checkCategoryAndSpecialBadges(
    String userId,
    String category,
  ) async {
    try {
      final completed = await _client
          .from('user_challenges')
          .select('category')
          .eq('user_id', userId)
          .eq('status', 'completed');

      final completedList = List<Map<String, dynamic>>.from(completed as List);
      final categoryCompletions = completedList
          .where(
            (c) =>
                (c['category'] as String?).toString().trim().toLowerCase() ==
                category.trim().toLowerCase(),
          )
          .length;

      // Category Badges Thresholds (Section 7.1)
      if (category.trim().toLowerCase() == 'nature') {
        if (categoryCompletions >= 3) {
          await awardBadge(userId, 'Nature Keeper 🌳', 'Gold', 'Nature');
        } else if (categoryCompletions >= 2) {
          await awardBadge(userId, 'Nature Keeper 🌳', 'Silver', 'Nature');
        } else if (categoryCompletions >= 1) {
          await awardBadge(userId, 'Nature Keeper 🌳', 'Bronze', 'Nature');
        }
      } else if (category.trim().toLowerCase() == 'transport') {
        if (categoryCompletions >= 12) {
          await awardBadge(userId, 'Road to Green 🚗', 'Gold', 'Transport');
        } else if (categoryCompletions >= 7) {
          await awardBadge(userId, 'Road to Green 🚗', 'Silver', 'Transport');
        } else if (categoryCompletions >= 3) {
          await awardBadge(userId, 'Road to Green 🚗', 'Bronze', 'Transport');
        }
      } else if (category.trim().toLowerCase() == 'food') {
        if (categoryCompletions >= 12) {
          await awardBadge(userId, 'Conscious Plate 🥗', 'Gold', 'Food');
        } else if (categoryCompletions >= 7) {
          await awardBadge(userId, 'Conscious Plate 🥗', 'Silver', 'Food');
        } else if (categoryCompletions >= 3) {
          await awardBadge(userId, 'Conscious Plate 🥗', 'Bronze', 'Food');
        }
      } else if (category.trim().toLowerCase() == 'energy') {
        if (categoryCompletions >= 12) {
          await awardBadge(userId, 'Power Saver ⚡', 'Gold', 'Energy');
        } else if (categoryCompletions >= 7) {
          await awardBadge(userId, 'Power Saver ⚡', 'Silver', 'Energy');
        } else if (categoryCompletions >= 3) {
          await awardBadge(userId, 'Power Saver ⚡', 'Bronze', 'Energy');
        }
      }

      // All-Rounder Special Badge (Section 7.2)
      final activeCategories = completedList
          .map(
            (c) => (c['category'] as String?).toString().trim().toLowerCase(),
          )
          .toSet();
      if (activeCategories.containsAll([
        'transport',
        'food',
        'energy',
        'nature',
      ])) {
        await awardBadge(userId, 'All-Rounder 🌟', 'Gold', 'Special');
      }
    } catch (e) {
      debugPrint('Error checking category badges: $e');
    }
  }

  /// Award Leaderboard Leader badge if user achieves Rank 1
  Future<void> checkLeaderboardBadges(String userId, int rank) async {
    if (rank == 1) {
      await awardBadge(userId, 'Leaderboard Leader 👑', 'Special', 'Special');
    }
  }

  /// Evaluate Streak Milestones, Milestone XP, and Special Badges (Sections 3.2, 5.3, 7.2)
  Future<Map<String, dynamic>> processStreakMilestonesAndBadges({
    required String userId,
    required int streakDays,
    required int level,
    required bool isFirstLog,
  }) async {
    int milestoneXpBonus = 0;
    bool freezeAwarded = false;
    bool freezeQueued = false;

    // 1. Eco Newcomer ✨ for first log
    if (isFirstLog) {
      await awardBadge(userId, 'Eco Newcomer ✨', 'Special', 'Special');
    }

    // 2. Carbon Neutral 🌍 for Level 10
    if (level >= 10) {
      await awardBadge(userId, 'Carbon Neutral 🌍', 'Special', 'Special');
    }

    // 3. Streak Milestones & Badges
    if (streakDays == 3) {
      milestoneXpBonus += 25;
    } else if (streakDays == 7) {
      milestoneXpBonus += 75;
      await awardBadge(userId, 'Week Warrior 🔥', 'Special', 'Special');
    } else if (streakDays == 14) {
      milestoneXpBonus += 150;
      await awardBadge(userId, 'Fortnight Fighter 💪', 'Special', 'Special');
    } else if (streakDays == 30) {
      milestoneXpBonus += 300;
      await awardBadge(userId, 'Monthly Maven 🌿', 'Special', 'Special');
      if (level >= 4) {
        freezeAwarded = true;
      } else {
        freezeQueued = true;
      }
    } else if (streakDays == 60) {
      milestoneXpBonus += 600;
      await awardBadge(userId, 'Eco Consistent 🌍', 'Special', 'Special');
    } else if (streakDays == 100) {
      milestoneXpBonus += 1000;
      await awardBadge(userId, 'Century Eco 🏆', 'Special', 'Special');
    }

    return {
      'milestoneXpBonus': milestoneXpBonus,
      'freezeAwarded': freezeAwarded,
      'freezeQueued': freezeQueued,
    };
  }

  Future<void> awardBadge(
    String userId,
    String badgeName,
    String tier,
    String category,
  ) async {
    try {
      await _client.from('badges').upsert({
        'user_id': userId,
        'badge_name': badgeName,
        'tier': tier,
        'category': category,
        'earned_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id, badge_name');
    } catch (e) {
      debugPrint('Error awarding badge $badgeName: $e');
    }
  }

  Future<void> updateChallengeProgress(
    String userId,
    String challengeId,
    int progress,
  ) async {
    await _updateUserChallengeSafe(userId, challengeId, {
      'progress_percent': progress,
    });
  }

  Future<void> completeChallenge(String userId, String challengeId) async {
    await _updateUserChallengeSafe(userId, challengeId, {
      'progress_percent': 100,
      'status': 'completed',
      'completed_at': DateTime.now().toIso8601String(),
    });
  }

  Future<int> getCompletedChallengesCount(String userId) async {
    try {
      final response = await _client
          .from('user_challenges')
          .select('id')
          .eq('user_id', userId)
          .or('status.eq.completed,completed_at.not.is.null');
      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }
}
