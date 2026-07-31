import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final gamificationRepositoryProvider = Provider(
  (ref) => GamificationRepository(Supabase.instance.client),
);

// Fetch all earned badges for a user
final userBadgesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      userId,
    ) async {
      final repo = ref.watch(gamificationRepositoryProvider);
      return repo.getUserBadges(userId);
    });

// Fetch active challenges in progress
final activeChallengesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      userId,
    ) async {
      final repo = ref.watch(gamificationRepositoryProvider);
      return repo.getActiveChallenges(userId);
    });

// Fetch all user challenge records (both active and completed)
final userChallengesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      userId,
    ) async {
      final repo = ref.watch(gamificationRepositoryProvider);
      return repo.getAllUserChallenges(userId);
    });

// Fetch all available challenges catalog (Dynamic DB first, static fallback)
final availableChallengesCatalogProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
      final repo = ref.watch(gamificationRepositoryProvider);
      return repo.getAvailableChallengesCatalog();
    });

// Fetch full badge catalog (Dynamic DB first, static fallback)
final badgeCatalogProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final repo = ref.watch(gamificationRepositoryProvider);
  return repo.getBadgeCatalog();
});

class GamificationRepository {
  final SupabaseClient _client;

  GamificationRepository(this._client);

  static const List<Map<String, dynamic>> defaultChallenges = [
    {
      'id': 'car_free_week',
      'name': 'Car-Free Week',
      'category': 'Transport',
      'difficulty': 'Medium',
      'duration': 7,
      'xp': 300,
    },
    {
      'id': 'meatless_mondays',
      'name': 'Meatless Mondays',
      'category': 'Food',
      'difficulty': 'Easy',
      'duration': 30,
      'xp': 200,
    },
    {
      'id': 'zero_vampire_draw',
      'name': 'Zero Vampire Draw',
      'category': 'Energy',
      'difficulty': 'Easy',
      'duration': 14,
      'xp': 150,
    },
    {
      'id': 'vegan_month',
      'name': '30-Day Vegan Challenge',
      'category': 'Food',
      'difficulty': 'Hard',
      'duration': 30,
      'xp': 500,
    },
  ];

  static const List<Map<String, dynamic>> defaultBadgeCatalog = [
    {
      'id': 'b1',
      'badge_name': 'Green Commuter',
      'category': 'Transport',
      'description': 'Logged 10 low-carbon transport journeys',
      'icon_name': 'directions_car',
      'is_special': false,
    },
    {
      'id': 'b2',
      'badge_name': 'Plant Powered',
      'category': 'Food',
      'description': 'Logged 14 plant-based meals',
      'icon_name': 'restaurant',
      'is_special': false,
    },
    {
      'id': 'b3',
      'badge_name': 'Energy Saver',
      'category': 'Energy',
      'description': 'Confirmed household energy deviations 7 times',
      'icon_name': 'bolt',
      'is_special': false,
    },
    {
      'id': 'b4',
      'badge_name': 'Eco Citizen',
      'category': 'General',
      'description': 'Logged activities consistently for 14 days',
      'icon_name': 'eco',
      'is_special': false,
    },
    {
      'id': 'b5',
      'badge_name': 'Zero Waste Hero',
      'category': 'Consumption',
      'description': 'Completed 3 recycling/reuse challenges',
      'icon_name': 'shopping_bag',
      'is_special': false,
    },
    {
      'id': 's1',
      'badge_name': 'Week Warrior ⚔️',
      'category': 'Special',
      'description': 'Maintained a 7-day logging streak',
      'icon_name': 'local_fire_department',
      'is_special': true,
    },
    {
      'id': 's2',
      'badge_name': 'Monthly Maven 📅',
      'category': 'Special',
      'description': 'Maintained a 30-day logging streak',
      'icon_name': 'calendar_today',
      'is_special': true,
    },
    {
      'id': 's3',
      'badge_name': 'Century Eco 💯',
      'category': 'Special',
      'description': 'Saved 100 kg total CO₂',
      'icon_name': 'workspace_premium',
      'is_special': true,
    },
    {
      'id': 's4',
      'badge_name': 'Quiz Whiz 🧠',
      'category': 'Special',
      'description': 'Scored 5 perfect quiz attempts',
      'icon_name': 'psychology',
      'is_special': true,
    },
    {
      'id': 's5',
      'badge_name': 'All-Rounder 🌟',
      'category': 'Special',
      'description': 'Logged in all categories within a single week',
      'icon_name': 'star',
      'is_special': true,
    },
    {
      'id': 's6',
      'badge_name': 'Carbon Neutral 🌳',
      'category': 'Special',
      'description': 'Offset 100% of weekly baseline emissions',
      'icon_name': 'park',
      'is_special': true,
    },
    {
      'id': 's7',
      'badge_name': 'Leaderboard Leader 👑',
      'category': 'Special',
      'description': 'Reached #1 on the Global Leaderboard',
      'icon_name': 'emoji_events',
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
            'duration': map['duration_days'] as int? ?? 7,
            'xp': map['xp_reward'] as int? ?? 100,
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
      return List<Map<String, dynamic>>.from(response);
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
    await _client.from('user_challenges').upsert({
      'user_id': userId,
      'challenge_id': challenge['id'],
      'challenge_name': challenge['name'],
      'category': challenge['category'],
      'difficulty': challenge['difficulty'],
      'duration_days': challenge['duration'],
      'xp_reward': challenge['xp'],
      'progress_percent': 0,
      'started_at': DateTime.now().toIso8601String(),
      'completed_at': null,
    });
  }

  Future<void> updateChallengeProgress(
    String userId,
    String challengeId,
    int progress,
  ) async {
    await _client
        .from('user_challenges')
        .update({'progress_percent': progress})
        .eq('user_id', userId)
        .eq('challenge_id', challengeId);
  }

  Future<void> completeChallenge(String userId, String challengeId) async {
    await _client
        .from('user_challenges')
        .update({
          'progress_percent': 100,
          'completed_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', userId)
        .eq('challenge_id', challengeId);
  }

  Future<int> getCompletedChallengesCount(String userId) async {
    try {
      final response = await _client
          .from('user_challenges')
          .select('id')
          .eq('user_id', userId)
          .not('completed_at', 'is', null);
      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }
}
