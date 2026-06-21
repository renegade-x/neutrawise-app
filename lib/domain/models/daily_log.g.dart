// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_log.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TransportEntry _$TransportEntryFromJson(Map<String, dynamic> json) =>
    _TransportEntry(
      mode: json['mode'] as String,
      distanceKm: (json['distanceKm'] as num).toDouble(),
      calculatedCo2: (json['calculated_co2'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$TransportEntryToJson(_TransportEntry instance) =>
    <String, dynamic>{
      'mode': instance.mode,
      'distanceKm': instance.distanceKm,
      'calculated_co2': instance.calculatedCo2,
    };

_FoodEntry _$FoodEntryFromJson(Map<String, dynamic> json) => _FoodEntry(
  mealSlot: json['mealSlot'] as String,
  foodName: json['foodName'] as String,
  category: json['category'] as String,
  servingSize: json['servingSize'] as String,
  grams: (json['grams'] as num).toDouble(),
  co2Per100g: (json['co2_per_100g'] as num?)?.toDouble(),
  calculatedCo2: (json['calculated_co2'] as num?)?.toDouble(),
  offBarcode: json['off_barcode'] as String?,
);

Map<String, dynamic> _$FoodEntryToJson(_FoodEntry instance) =>
    <String, dynamic>{
      'mealSlot': instance.mealSlot,
      'foodName': instance.foodName,
      'category': instance.category,
      'servingSize': instance.servingSize,
      'grams': instance.grams,
      'co2_per_100g': instance.co2Per100g,
      'calculated_co2': instance.calculatedCo2,
      'off_barcode': instance.offBarcode,
    };

_DailyLog _$DailyLogFromJson(Map<String, dynamic> json) => _DailyLog(
  userId: json['user_id'] as String,
  date: json['date'] as String,
  transportEntries:
      (json['transport_entries'] as List<dynamic>?)
          ?.map((e) => TransportEntry.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  transportCo2: (json['transport_co2'] as num?)?.toDouble() ?? 0.0,
  foodEntries:
      (json['food_entries'] as List<dynamic>?)
          ?.map((e) => FoodEntry.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  foodCo2: (json['food_co2'] as num?)?.toDouble() ?? 0.0,
  energyDeviations:
      (json['energy_deviations'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  energyCo2: (json['energy_co2'] as num?)?.toDouble() ?? 0.0,
  totalDailyCo2: (json['total_daily_co2'] as num?)?.toDouble() ?? 0.0,
  baselineCo2: (json['baseline_co2'] as num?)?.toDouble() ?? 0.0,
  co2SavedVsBaseline:
      (json['co2_saved_vs_baseline'] as num?)?.toDouble() ?? 0.0,
  percentVsBaseline: (json['percent_vs_baseline'] as num?)?.toDouble() ?? 0.0,
  xpEarned: (json['xp_earned'] as num?)?.toInt() ?? 0,
  emissionFactorVersion: json['emission_factor_version'] as String? ?? '1.0',
);

Map<String, dynamic> _$DailyLogToJson(_DailyLog instance) => <String, dynamic>{
  'user_id': instance.userId,
  'date': instance.date,
  'transport_entries': instance.transportEntries,
  'transport_co2': instance.transportCo2,
  'food_entries': instance.foodEntries,
  'food_co2': instance.foodCo2,
  'energy_deviations': instance.energyDeviations,
  'energy_co2': instance.energyCo2,
  'total_daily_co2': instance.totalDailyCo2,
  'baseline_co2': instance.baselineCo2,
  'co2_saved_vs_baseline': instance.co2SavedVsBaseline,
  'percent_vs_baseline': instance.percentVsBaseline,
  'xp_earned': instance.xpEarned,
  'emission_factor_version': instance.emissionFactorVersion,
};
