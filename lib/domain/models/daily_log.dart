import 'package:freezed_annotation/freezed_annotation.dart';

part 'daily_log.freezed.dart';
part 'daily_log.g.dart';

@freezed
abstract class TransportEntry with _$TransportEntry {
  const factory TransportEntry({
    required String mode,
    required double distanceKm,
    @JsonKey(name: 'calculated_co2') double? calculatedCo2,
  }) = _TransportEntry;

  factory TransportEntry.fromJson(Map<String, dynamic> json) =>
      _$TransportEntryFromJson(json);
}

@freezed
abstract class FoodEntry with _$FoodEntry {
  const factory FoodEntry({
    required String mealSlot,
    required String foodName,
    required String category,
    required String servingSize,
    required double grams,
    @JsonKey(name: 'co2_per_100g') double? co2Per100g,
    @JsonKey(name: 'calculated_co2') double? calculatedCo2,
    @JsonKey(name: 'off_barcode') String? offBarcode,
  }) = _FoodEntry;

  factory FoodEntry.fromJson(Map<String, dynamic> json) =>
      _$FoodEntryFromJson(json);
}

@freezed
abstract class DailyLog with _$DailyLog {
  const DailyLog._();

  const factory DailyLog({
    @JsonKey(name: 'user_id') required String userId,
    required String date,

    @JsonKey(name: 'transport_entries')
    @Default([])
    List<TransportEntry> transportEntries,
    @JsonKey(name: 'transport_co2') @Default(0.0) double transportCo2,

    @JsonKey(name: 'food_entries') @Default([]) List<FoodEntry> foodEntries,
    @JsonKey(name: 'food_co2') @Default(0.0) double foodCo2,

    @JsonKey(name: 'energy_deviations')
    @Default([])
    List<String> energyDeviations,
    @JsonKey(name: 'energy_co2') @Default(0.0) double energyCo2,

    @JsonKey(name: 'total_daily_co2') @Default(0.0) double totalDailyCo2,
    @JsonKey(name: 'baseline_co2') @Default(0.0) double baselineCo2,
    @JsonKey(name: 'co2_saved_vs_baseline')
    @Default(0.0)
    double co2SavedVsBaseline,
    @JsonKey(name: 'percent_vs_baseline')
    @Default(0.0)
    double percentVsBaseline,
    @JsonKey(name: 'xp_earned') @Default(0) int xpEarned,

    @JsonKey(name: 'emission_factor_version')
    @Default('1.0')
    String emissionFactorVersion,

    @JsonKey(name: 'sync_status', includeToJson: false, includeFromJson: false)
    @Default('pending')
    String syncStatus,
  }) = _DailyLog;

  factory DailyLog.fromJson(Map<String, dynamic> json) =>
      _$DailyLogFromJson(json);

  Map<String, dynamic> toSupabaseJson() {
    final map = toJson();
    map.remove('sync_status');
    map['transport_entries'] = transportEntries.map((e) => e.toJson()).toList();
    map['food_entries'] = foodEntries.map((e) => e.toJson()).toList();
    return map;
  }
}
