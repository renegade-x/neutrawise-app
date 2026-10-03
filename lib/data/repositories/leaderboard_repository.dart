import 'package:flutter/foundation.dart';
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

      final profileAsync = ref.watch(userProfileProvider(user.id));
      final profile = profileAsync.value;
      final repo = ref.watch(leaderboardRepositoryProvider);
      return repo.getLeaderboard(type: type, city: profile?.city);
    });

class LeaderboardRepository {
  final SupabaseClient _client;

  LeaderboardRepository(this._client);

  /// Fetches a leaderboard through the `get_leaderboard` database function.
  ///
  /// The function returns only public leaderboard fields (name, avatar, xp,
  /// level, rank), so other users' profiles and logs are never readable
  /// directly from the client.
  Future<List<LeaderboardEntry>> getLeaderboard({
    required String type,
    String? city,
    int limit = 100,
  }) async {
    try {
      // 'friends' has no data in v1 and falls back to global.
      final rpcType = (type == 'city' || type == 'weekly_sprint')
          ? type
          : 'global';

      if (rpcType == 'city' && (city == null || city.trim().isEmpty)) {
        return [];
      }

      final List<dynamic> response = await _client.rpc(
        'get_leaderboard',
        params: {
          'p_type': rpcType,
          'p_city': city?.trim(),
          'p_limit': limit,
        },
      );

      final entries = response
          .map(
            (row) =>
                LeaderboardEntry.fromJson(Map<String, dynamic>.from(row as Map)),
          )
          .toList();

      // Fall back to the global board if nobody has logged this week.
      if (rpcType == 'weekly_sprint' && entries.isEmpty) {
        return await getLeaderboard(type: 'global', limit: limit);
      }

      return entries;
    } catch (e) {
      debugPrint('Error loading leaderboard ($type): $e');
      return [];
    }
  }
}
