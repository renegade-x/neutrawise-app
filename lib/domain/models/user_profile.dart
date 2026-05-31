import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_profile.freezed.dart';
part 'user_profile.g.dart';

@freezed
abstract class UserProfile with _$UserProfile {
  const factory UserProfile({
    required String id,
    required String name,
    String? email,
    String? city,
    @JsonKey(name: 'country_code') String? countryCode,
    @JsonKey(name: 'avatar_url') String? avatarUrl,
    
    /// Transport profile
    @JsonKey(name: 'primary_transport') String? primaryTransport,
    @JsonKey(name: 'fuel_type') String? fuelType,
    @JsonKey(name: 'engine_size') String? engineSize,
    @JsonKey(name: 'vehicle_age') String? vehicleAge,
    @JsonKey(name: 'vehicle_model') String? vehicleModel,
    @JsonKey(name: 'avg_daily_km') double? avgDailyKm,
    @JsonKey(name: 'transport_factor') double? transportFactor,
    
    /// Energy profile
    @JsonKey(name: 'home_type') String? homeType,
    int? residents,
    @JsonKey(name: 'heating_type') String? heatingType,
    @JsonKey(name: 'has_solar') bool? hasSolar,
    @JsonKey(name: 'daily_energy_baseline_kwh') double? dailyEnergyBaselineKwh,
    @JsonKey(name: 'daily_heating_baseline_co2') double? dailyHeatingBaselineCo2,
    @JsonKey(name: 'daily_energy_baseline_co2') double? dailyEnergyBaselineCo2,
    @JsonKey(name: 'grid_intensity') double? gridIntensity,
    
    /// Food profile
    @JsonKey(name: 'dietary_preference') String? dietaryPreference,
    @JsonKey(name: 'daily_food_baseline_co2') double? dailyFoodBaselineCo2,
    
    /// Aggregate
    @JsonKey(name: 'total_daily_baseline_co2') double? totalDailyBaselineCo2,
    
    /// Gamification
    @Default(0) int xp,
    @Default(1) int level,
    @JsonKey(name: 'current_streak') @Default(0) int currentStreak,
    @JsonKey(name: 'longest_streak') @Default(0) int longestStreak,
    @JsonKey(name: 'days_active') @Default(0) int daysActive,
    @JsonKey(name: 'streak_freeze_count') @Default(0) int streakFreezeCount,
    
    @JsonKey(name: 'total_co2_saved') @Default(0.0) double totalCo2Saved,
  }) = _UserProfile;

  factory UserProfile.fromJson(Map<String, dynamic> json) => _$UserProfileFromJson(json);
}
