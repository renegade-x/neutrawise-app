import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:neutrawise/domain/models/daily_log.dart';
import 'package:neutrawise/data/repositories/activity_repository.dart';
import 'package:neutrawise/data/repositories/user_repository.dart';

final syncManagerProvider = Provider<SyncManager>((ref) {
  final activityRepo = ref.watch(activityRepositoryProvider);
  final userRepo = ref.watch(userRepositoryProvider);
  final manager = SyncManager(activityRepo, userRepo);
  ref.onDispose(manager.dispose);
  return manager;
});

class SyncManager {
  final ActivityRepository _activityRepo;
  final UserRepository _userRepo;
  late Box<String> _offlineBox;
  late Box<String> _rewardsBox;
  bool _isInitialized = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  SyncManager(this._activityRepo, this._userRepo);

  /// Stops listening for connectivity changes.
  void dispose() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }

  Future<void> init() async {
    if (_isInitialized) return;
    _offlineBox = await Hive.openBox<String>('offline_logs');
    _rewardsBox = await Hive.openBox<String>('pending_rewards');
    _isInitialized = true;

    // Listen to network changes (a previous listener is replaced, never leaked)
    await _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      if (results.isNotEmpty && !results.contains(ConnectivityResult.none)) {
        syncPendingLogs();
      }
    });

    // Attempt initial sync
    syncPendingLogs();
  }

  Future<void> saveLog(DailyLog log) async {
    if (!_isInitialized) await init();

    // Save locally first as pending
    final pendingLog = log.copyWith(syncStatus: 'pending');
    final key = '${log.userId}_${log.date}';
    await _offlineBox.put(key, jsonEncode(pendingLog.toJson()));

    // Attempt immediate sync
    await syncPendingLogs();
  }

  Future<void> syncPendingLogs() async {
    if (!_isInitialized) return;

    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return;

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) return;

    final keys = _offlineBox.keys.toList();
    for (var key in keys) {
      final jsonStr = _offlineBox.get(key);
      if (jsonStr != null) {
        try {
          final log = DailyLog.fromJson(jsonDecode(jsonStr));
          // Only attempt to sync logs belonging to the currently logged in user
          if (log.userId != currentUserId) {
            continue;
          }

          if (log.syncStatus == 'pending') {
            await _activityRepo.upsertDailyLog(log);
            // Mark as synced locally
            await _offlineBox.put(
              key.toString(),
              jsonEncode(log.copyWith(syncStatus: 'synced').toJson()),
            );
          }
        } catch (e) {
          if (e is PostgrestException && e.code == '42501') {
            // Row-level security violation: purge stale/orphaned log key from local box
            debugPrint('Purging log $key due to RLS error (42501): $e');
            await _offlineBox.delete(key);
          } else {
            debugPrint('Error syncing log $key: $e');
          }
        }
      }
    }

    await syncPendingRewards();
  }

  /// Remembers rewards (XP, streak, CO2 saved) that could not be applied
  /// because the device was offline. Several offline edits of the same day
  /// are merged: the latest XP wins and CO2-saved deltas add up.
  Future<void> queueRewards({
    required String userId,
    required String date,
    required bool isFullLog,
    required int logXp,
    required double co2SavedDelta,
  }) async {
    if (!_isInitialized) await init();
    final key = '${userId}_$date';
    var delta = co2SavedDelta;
    final existing = _rewardsBox.get(key);
    if (existing != null) {
      try {
        delta += ((jsonDecode(existing) as Map)['co2SavedDelta'] as num)
            .toDouble();
      } catch (_) {
        // Corrupt entry - replace it.
      }
    }
    await _rewardsBox.put(
      key,
      jsonEncode({
        'userId': userId,
        'date': date,
        'isFullLog': isFullLog,
        'logXp': logXp,
        'co2SavedDelta': delta,
      }),
    );
  }

  /// Applies queued rewards for the signed-in user. The server only accepts
  /// logs from the last day, so older entries are dropped (that is the
  /// anti-cheat rule, not an error).
  Future<void> syncPendingRewards() async {
    if (!_isInitialized) return;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final key in _rewardsBox.keys.toList()) {
      final raw = _rewardsBox.get(key);
      if (raw == null) continue;
      try {
        final entry = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        if (entry['userId'] != currentUserId) continue;

        final date = DateTime.tryParse(entry['date'] as String? ?? '');
        if (date == null || today.difference(date).inDays > 1) {
          await _rewardsBox.delete(key);
          continue;
        }

        await _userRepo.submitLogRewards(
          date: entry['date'] as String,
          isFullLog: entry['isFullLog'] as bool? ?? false,
          logXp: (entry['logXp'] as num?)?.toInt() ?? 0,
          co2SavedDelta: (entry['co2SavedDelta'] as num?)?.toDouble() ?? 0.0,
        );
        await _rewardsBox.delete(key);
      } catch (e) {
        if (e is PostgrestException && e.code == '22023') {
          // Rejected by validation (e.g. date too old): will never succeed.
          await _rewardsBox.delete(key);
        } else {
          debugPrint('Error syncing rewards $key: $e');
        }
      }
    }
  }

  List<DailyLog> getLocalLogs() {
    if (!_isInitialized) return [];
    return _offlineBox.values
        .map((str) => DailyLog.fromJson(jsonDecode(str)))
        .toList();
  }
}
