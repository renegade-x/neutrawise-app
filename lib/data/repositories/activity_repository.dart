import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neutrawise/domain/models/daily_log.dart';

final activityRepositoryProvider = Provider(
  (ref) => ActivityRepository(Supabase.instance.client),
);

class ActivityRepository {
  final SupabaseClient _client;

  ActivityRepository(this._client);

  Future<void> upsertDailyLog(DailyLog log) async {
    final payload = log.toSupabaseJson();
    final updatePayload = Map<String, dynamic>.from(payload)
      ..remove('user_id')
      ..remove('date');
    final existing = await _client
        .from('daily_logs')
        .select('id')
        .eq('user_id', log.userId)
        .eq('date', log.date)
        .maybeSingle();

    if (existing != null) {
      await _updateDailyLog(log, updatePayload);
      return;
    }

    try {
      await _client.from('daily_logs').insert(payload);
    } on PostgrestException catch (error) {
      // Another request may have inserted this date after the lookup.
      if (error.code != '23505') rethrow;
      await _updateDailyLog(log, updatePayload);
    }
  }

  Future<void> _updateDailyLog(
    DailyLog log,
    Map<String, dynamic> payload,
  ) async {
    await _client
        .from('daily_logs')
        .update(payload)
        .eq('user_id', log.userId)
        .eq('date', log.date);
  }

  Stream<List<DailyLog>> watchRecentLogs(String userId) {
    return _client
        .from('daily_logs')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('date', ascending: false)
        .limit(7)
        .map((data) => data.map((json) => DailyLog.fromJson(json)).toList());
  }

  Future<DailyLog?> getLogByDate(String userId, String date) async {
    try {
      final response = await _client
          .from('daily_logs')
          .select()
          .eq('user_id', userId)
          .eq('date', date)
          .maybeSingle();
      if (response != null) {
        return DailyLog.fromJson(response);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
