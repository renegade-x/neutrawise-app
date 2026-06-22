import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neutrawise/domain/models/leaderboard_entry.dart';
import 'package:neutrawise/providers/auth_provider.dart';
import 'package:neutrawise/data/repositories/user_repository.dart';

final leaderboardRepositoryProvider = Provider(
  (ref) => LeaderboardRepository(Supabase.instance.client),
);

final leaderboardProvider =
    FutureProvider.family<List<LeaderboardEntry>, String>((ref, type) async {
      final authState = ref.watch(authProvider);
      final user = authState.user;
      if (user == null) return [];

      final profile = await ref
          .watch(userRepositoryProvider)
          .getUserProfile(user.id);
      final repo = ref.watch(leaderboardRepositoryProvider);
      return repo.getLeaderboard(type: type, city: profile?.city);
    });

class LeaderboardRepository {
  final SupabaseClient _client;

  LeaderboardRepository(this._client);

  Future<List<LeaderboardEntry>> getLeaderboard({
    required String type,
    String? city,
    int limit = 100,
  }) async {
    try {
      if (type == 'global') {
        final List<dynamic> response = await _client
            .from('users')
            .select('id, name, avatar_url, xp, level')
            .order('xp', ascending: false)
            .limit(limit);

        return response.asMap().entries.map((entry) {
          final index = entry.key;
          final json = Map<String, dynamic>.from(entry.value);
          json['rank'] = index + 1;
          return LeaderboardEntry.fromJson(json);
        }).toList();
      } else if (type == 'city') {
        if (city == null || city.isEmpty) return [];
        final List<dynamic> response = await _client
            .from('users')
            .select('id, name, avatar_url, xp, level')
            .eq('city', city)
            .order('xp', ascending: false)
            .limit(limit);

        return response.asMap().entries.map((entry) {
          final index = entry.key;
          final json = Map<String, dynamic>.from(entry.value);
          json['rank'] = index + 1;
          return LeaderboardEntry.fromJson(json);
        }).toList();
      } else if (type == 'weekly_sprint') {
        // Calculate start of current week (Monday)
        final now = DateTime.now();
        final daysToMonday = now.weekday - 1;
        final monday = now.subtract(Duration(days: daysToMonday));
        final startOfWeek = DateTime(
          monday.year,
          monday.month,
          monday.day,
        ).toIso8601String().substring(0, 10);

        // Fetch logs for this week
        final List<dynamic> logs = await _client
            .from('daily_logs')
            .select('user_id, xp_earned, users(name, avatar_url, level)')
            .gte('date', startOfWeek);

        // Aggregate in Dart
        final Map<String, Map<String, dynamic>> userAggregates = {};
        for (var log in logs) {
          final userId = log['user_id'] as String;
          final xpEarned = log['xp_earned'] as int? ?? 0;
          final userData = log['users'] as Map<String, dynamic>?;

          if (userData == null) continue;

          if (!userAggregates.containsKey(userId)) {
            userAggregates[userId] = {
              'id': userId,
              'name': userData['name'],
              'avatar_url': userData['avatar_url'],
              'level': userData['level'] ?? 1,
              'xp': 0,
            };
          }
          userAggregates[userId]!['xp'] =
              (userAggregates[userId]!['xp'] as int) + xpEarned;
        }

        final sortedList = userAggregates.values.toList()
          ..sort((a, b) => (b['xp'] as int).compareTo(a['xp'] as int));

        if (sortedList.isEmpty) {
          // Fallback to global leaderboard if no logs logged this week
          return getLeaderboard(type: 'global', limit: limit);
        }

        return sortedList.asMap().entries.map((entry) {
          final index = entry.key;
          final json = entry.value;
          json['rank'] = index + 1;
          return LeaderboardEntry.fromJson(json);
        }).toList();
      } else {
        // Friends (Mutual follow network, empty in v1, fallback to global)
        return getLeaderboard(type: 'global', limit: limit);
      }
    } catch (e) {
      // In case of error, return empty list
      return [];
    }
  }
}
