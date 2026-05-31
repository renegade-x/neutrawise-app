// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_UserProfile _$UserProfileFromJson(Map<String, dynamic> json) => _UserProfile(
  id: json['id'] as String,
  name: json['name'] as String,
  email: json['email'] as String?,
  city: json['city'] as String?,
  countryCode: json['country_code'] as String?,
  avatarUrl: json['avatar_url'] as String?,
  primaryTransport: json['primary_transport'] as String?,
  fuelType: json['fuel_type'] as String?,
  engineSize: json['engine_size'] as String?,
  vehicleAge: json['vehicle_age'] as String?,
  vehicleModel: json['vehicle_model'] as String?,
  avgDailyKm: (json['avg_daily_km'] as num?)?.toDouble(),
  transportFactor: (json['transport_factor'] as num?)?.toDouble(),
  homeType: json['home_type'] as String?,
  residents: (json['residents'] as num?)?.toInt(),
  heatingType: json['heating_type'] as String?,
  hasSolar: json['has_solar'] as bool?,
  dailyEnergyBaselineKwh: (json['daily_energy_baseline_kwh'] as num?)
      ?.toDouble(),
  dailyHeatingBaselineCo2: (json['daily_heating_baseline_co2'] as num?)
      ?.toDouble(),
  dailyEnergyBaselineCo2: (json['daily_energy_baseline_co2'] as num?)
      ?.toDouble(),
  gridIntensity: (json['grid_intensity'] as num?)?.toDouble(),
  dietaryPreference: json['dietary_preference'] as String?,
  dailyFoodBaselineCo2: (json['daily_food_baseline_co2'] as num?)?.toDouble(),
  totalDailyBaselineCo2: (json['total_daily_baseline_co2'] as num?)?.toDouble(),
  xp: (json['xp'] as num?)?.toInt() ?? 0,
  level: (json['level'] as num?)?.toInt() ?? 1,
  currentStreak: (json['current_streak'] as num?)?.toInt() ?? 0,
  longestStreak: (json['longest_streak'] as num?)?.toInt() ?? 0,
  daysActive: (json['days_active'] as num?)?.toInt() ?? 0,
  streakFreezeCount: (json['streak_freeze_count'] as num?)?.toInt() ?? 0,
  totalCo2Saved: (json['total_co2_saved'] as num?)?.toDouble() ?? 0.0,
);

Map<String, dynamic> _$UserProfileToJson(_UserProfile instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'email': instance.email,
      'city': instance.city,
      'country_code': instance.countryCode,
      'avatar_url': instance.avatarUrl,
      'primary_transport': instance.primaryTransport,
      'fuel_type': instance.fuelType,
      'engine_size': instance.engineSize,
      'vehicle_age': instance.vehicleAge,
      'vehicle_model': instance.vehicleModel,
      'avg_daily_km': instance.avgDailyKm,
      'transport_factor': instance.transportFactor,
      'home_type': instance.homeType,
      'residents': instance.residents,
      'heating_type': instance.heatingType,
      'has_solar': instance.hasSolar,
      'daily_energy_baseline_kwh': instance.dailyEnergyBaselineKwh,
      'daily_heating_baseline_co2': instance.dailyHeatingBaselineCo2,
      'daily_energy_baseline_co2': instance.dailyEnergyBaselineCo2,
      'grid_intensity': instance.gridIntensity,
      'dietary_preference': instance.dietaryPreference,
      'daily_food_baseline_co2': instance.dailyFoodBaselineCo2,
      'total_daily_baseline_co2': instance.totalDailyBaselineCo2,
      'xp': instance.xp,
      'level': instance.level,
      'current_streak': instance.currentStreak,
      'longest_streak': instance.longestStreak,
      'days_active': instance.daysActive,
      'streak_freeze_count': instance.streakFreezeCount,
      'total_co2_saved': instance.totalCo2Saved,
    };
