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

class GamificationRepository {
  final SupabaseClient _client;

  GamificationRepository(this._client);

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
