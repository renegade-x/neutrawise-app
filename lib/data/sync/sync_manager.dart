import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:neutrawise/domain/models/daily_log.dart';
import 'package:neutrawise/data/repositories/activity_repository.dart';

final syncManagerProvider = Provider<SyncManager>((ref) {
  final activityRepo = ref.watch(activityRepositoryProvider);
  return SyncManager(activityRepo);
});

class SyncManager {
  final ActivityRepository _activityRepo;
  late Box<String> _offlineBox;
  bool _isInitialized = false;

  SyncManager(this._activityRepo);

  Future<void> init() async {
    if (_isInitialized) return;
    _offlineBox = await Hive.openBox<String>('offline_logs');
    _isInitialized = true;

    // Listen to network changes
    Connectivity().onConnectivityChanged.listen((
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

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) return;

    final keys = _offlineBox.keys.toList();
    for (var key in keys) {
      final jsonStr = _offlineBox.get(key);
      if (jsonStr != null) {
        try {
          final log = DailyLog.fromJson(jsonDecode(jsonStr));
          if (log.syncStatus == 'pending') {
            await _activityRepo.upsertDailyLog(log);
            // Mark as synced locally
            await _offlineBox.put(
              key,
              jsonEncode(log.copyWith(syncStatus: 'synced').toJson()),
            );
          }
        } catch (e) {
          // Log error, keep as pending
          print('Error syncing log $key: $e');
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
