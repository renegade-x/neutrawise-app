// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_profile.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$UserProfile {

 String get id; String get name; String? get email; String? get city;@JsonKey(name: 'country_code') String? get countryCode;@JsonKey(name: 'avatar_url') String? get avatarUrl;/// Transport profile
@JsonKey(name: 'primary_transport') String? get primaryTransport;@JsonKey(name: 'fuel_type') String? get fuelType;@JsonKey(name: 'engine_size') String? get engineSize;@JsonKey(name: 'vehicle_age') String? get vehicleAge;@JsonKey(name: 'vehicle_model') String? get vehicleModel;@JsonKey(name: 'avg_daily_km') double? get avgDailyKm;@JsonKey(name: 'transport_factor') double? get transportFactor;/// Energy profile
@JsonKey(name: 'home_type') String? get homeType; int? get residents;@JsonKey(name: 'heating_type') String? get heatingType;@JsonKey(name: 'has_solar') bool? get hasSolar;@JsonKey(name: 'daily_energy_baseline_kwh') double? get dailyEnergyBaselineKwh;@JsonKey(name: 'daily_heating_baseline_co2') double? get dailyHeatingBaselineCo2;@JsonKey(name: 'daily_energy_baseline_co2') double? get dailyEnergyBaselineCo2;@JsonKey(name: 'grid_intensity') double? get gridIntensity;/// Food profile
@JsonKey(name: 'dietary_preference') String? get dietaryPreference;@JsonKey(name: 'daily_food_baseline_co2') double? get dailyFoodBaselineCo2;/// Aggregate
@JsonKey(name: 'total_daily_baseline_co2') double? get totalDailyBaselineCo2;/// Gamification
 int get xp; int get level;@JsonKey(name: 'current_streak') int get currentStreak;@JsonKey(name: 'longest_streak') int get longestStreak;@JsonKey(name: 'days_active') int get daysActive;@JsonKey(name: 'streak_freeze_count') int get streakFreezeCount;@JsonKey(name: 'total_co2_saved') double get totalCo2Saved;
/// Create a copy of UserProfile
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserProfileCopyWith<UserProfile> get copyWith => _$UserProfileCopyWithImpl<UserProfile>(this as UserProfile, _$identity);

  /// Serializes this UserProfile to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserProfile&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.email, email) || other.email == email)&&(identical(other.city, city) || other.city == city)&&(identical(other.countryCode, countryCode) || other.countryCode == countryCode)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.primaryTransport, primaryTransport) || other.primaryTransport == primaryTransport)&&(identical(other.fuelType, fuelType) || other.fuelType == fuelType)&&(identical(other.engineSize, engineSize) || other.engineSize == engineSize)&&(identical(other.vehicleAge, vehicleAge) || other.vehicleAge == vehicleAge)&&(identical(other.vehicleModel, vehicleModel) || other.vehicleModel == vehicleModel)&&(identical(other.avgDailyKm, avgDailyKm) || other.avgDailyKm == avgDailyKm)&&(identical(other.transportFactor, transportFactor) || other.transportFactor == transportFactor)&&(identical(other.homeType, homeType) || other.homeType == homeType)&&(identical(other.residents, residents) || other.residents == residents)&&(identical(other.heatingType, heatingType) || other.heatingType == heatingType)&&(identical(other.hasSolar, hasSolar) || other.hasSolar == hasSolar)&&(identical(other.dailyEnergyBaselineKwh, dailyEnergyBaselineKwh) || other.dailyEnergyBaselineKwh == dailyEnergyBaselineKwh)&&(identical(other.dailyHeatingBaselineCo2, dailyHeatingBaselineCo2) || other.dailyHeatingBaselineCo2 == dailyHeatingBaselineCo2)&&(identical(other.dailyEnergyBaselineCo2, dailyEnergyBaselineCo2) || other.dailyEnergyBaselineCo2 == dailyEnergyBaselineCo2)&&(identical(other.gridIntensity, gridIntensity) || other.gridIntensity == gridIntensity)&&(identical(other.dietaryPreference, dietaryPreference) || other.dietaryPreference == dietaryPreference)&&(identical(other.dailyFoodBaselineCo2, dailyFoodBaselineCo2) || other.dailyFoodBaselineCo2 == dailyFoodBaselineCo2)&&(identical(other.totalDailyBaselineCo2, totalDailyBaselineCo2) || other.totalDailyBaselineCo2 == totalDailyBaselineCo2)&&(identical(other.xp, xp) || other.xp == xp)&&(identical(other.level, level) || other.level == level)&&(identical(other.currentStreak, currentStreak) || other.currentStreak == currentStreak)&&(identical(other.longestStreak, longestStreak) || other.longestStreak == longestStreak)&&(identical(other.daysActive, daysActive) || other.daysActive == daysActive)&&(identical(other.streakFreezeCount, streakFreezeCount) || other.streakFreezeCount == streakFreezeCount)&&(identical(other.totalCo2Saved, totalCo2Saved) || other.totalCo2Saved == totalCo2Saved));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,name,email,city,countryCode,avatarUrl,primaryTransport,fuelType,engineSize,vehicleAge,vehicleModel,avgDailyKm,transportFactor,homeType,residents,heatingType,hasSolar,dailyEnergyBaselineKwh,dailyHeatingBaselineCo2,dailyEnergyBaselineCo2,gridIntensity,dietaryPreference,dailyFoodBaselineCo2,totalDailyBaselineCo2,xp,level,currentStreak,longestStreak,daysActive,streakFreezeCount,totalCo2Saved]);

@override
String toString() {
  return 'UserProfile(id: $id, name: $name, email: $email, city: $city, countryCode: $countryCode, avatarUrl: $avatarUrl, primaryTransport: $primaryTransport, fuelType: $fuelType, engineSize: $engineSize, vehicleAge: $vehicleAge, vehicleModel: $vehicleModel, avgDailyKm: $avgDailyKm, transportFactor: $transportFactor, homeType: $homeType, residents: $residents, heatingType: $heatingType, hasSolar: $hasSolar, dailyEnergyBaselineKwh: $dailyEnergyBaselineKwh, dailyHeatingBaselineCo2: $dailyHeatingBaselineCo2, dailyEnergyBaselineCo2: $dailyEnergyBaselineCo2, gridIntensity: $gridIntensity, dietaryPreference: $dietaryPreference, dailyFoodBaselineCo2: $dailyFoodBaselineCo2, totalDailyBaselineCo2: $totalDailyBaselineCo2, xp: $xp, level: $level, currentStreak: $currentStreak, longestStreak: $longestStreak, daysActive: $daysActive, streakFreezeCount: $streakFreezeCount, totalCo2Saved: $totalCo2Saved)';
}


}

/// @nodoc
abstract mixin class $UserProfileCopyWith<$Res>  {
  factory $UserProfileCopyWith(UserProfile value, $Res Function(UserProfile) _then) = _$UserProfileCopyWithImpl;
@useResult
$Res call({
 String id, String name, String? email, String? city,@JsonKey(name: 'country_code') String? countryCode,@JsonKey(name: 'avatar_url') String? avatarUrl,@JsonKey(name: 'primary_transport') String? primaryTransport,@JsonKey(name: 'fuel_type') String? fuelType,@JsonKey(name: 'engine_size') String? engineSize,@JsonKey(name: 'vehicle_age') String? vehicleAge,@JsonKey(name: 'vehicle_model') String? vehicleModel,@JsonKey(name: 'avg_daily_km') double? avgDailyKm,@JsonKey(name: 'transport_factor') double? transportFactor,@JsonKey(name: 'home_type') String? homeType, int? residents,@JsonKey(name: 'heating_type') String? heatingType,@JsonKey(name: 'has_solar') bool? hasSolar,@JsonKey(name: 'daily_energy_baseline_kwh') double? dailyEnergyBaselineKwh,@JsonKey(name: 'daily_heating_baseline_co2') double? dailyHeatingBaselineCo2,@JsonKey(name: 'daily_energy_baseline_co2') double? dailyEnergyBaselineCo2,@JsonKey(name: 'grid_intensity') double? gridIntensity,@JsonKey(name: 'dietary_preference') String? dietaryPreference,@JsonKey(name: 'daily_food_baseline_co2') double? dailyFoodBaselineCo2,@JsonKey(name: 'total_daily_baseline_co2') double? totalDailyBaselineCo2, int xp, int level,@JsonKey(name: 'current_streak') int currentStreak,@JsonKey(name: 'longest_streak') int longestStreak,@JsonKey(name: 'days_active') int daysActive,@JsonKey(name: 'streak_freeze_count') int streakFreezeCount,@JsonKey(name: 'total_co2_saved') double totalCo2Saved
});




}
/// @nodoc
class _$UserProfileCopyWithImpl<$Res>
    implements $UserProfileCopyWith<$Res> {
  _$UserProfileCopyWithImpl(this._self, this._then);

  final UserProfile _self;
  final $Res Function(UserProfile) _then;

/// Create a copy of UserProfile
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? email = freezed,Object? city = freezed,Object? countryCode = freezed,Object? avatarUrl = freezed,Object? primaryTransport = freezed,Object? fuelType = freezed,Object? engineSize = freezed,Object? vehicleAge = freezed,Object? vehicleModel = freezed,Object? avgDailyKm = freezed,Object? transportFactor = freezed,Object? homeType = freezed,Object? residents = freezed,Object? heatingType = freezed,Object? hasSolar = freezed,Object? dailyEnergyBaselineKwh = freezed,Object? dailyHeatingBaselineCo2 = freezed,Object? dailyEnergyBaselineCo2 = freezed,Object? gridIntensity = freezed,Object? dietaryPreference = freezed,Object? dailyFoodBaselineCo2 = freezed,Object? totalDailyBaselineCo2 = freezed,Object? xp = null,Object? level = null,Object? currentStreak = null,Object? longestStreak = null,Object? daysActive = null,Object? streakFreezeCount = null,Object? totalCo2Saved = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,city: freezed == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String?,countryCode: freezed == countryCode ? _self.countryCode : countryCode // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,primaryTransport: freezed == primaryTransport ? _self.primaryTransport : primaryTransport // ignore: cast_nullable_to_non_nullable
as String?,fuelType: freezed == fuelType ? _self.fuelType : fuelType // ignore: cast_nullable_to_non_nullable
as String?,engineSize: freezed == engineSize ? _self.engineSize : engineSize // ignore: cast_nullable_to_non_nullable
as String?,vehicleAge: freezed == vehicleAge ? _self.vehicleAge : vehicleAge // ignore: cast_nullable_to_non_nullable
as String?,vehicleModel: freezed == vehicleModel ? _self.vehicleModel : vehicleModel // ignore: cast_nullable_to_non_nullable
as String?,avgDailyKm: freezed == avgDailyKm ? _self.avgDailyKm : avgDailyKm // ignore: cast_nullable_to_non_nullable
as double?,transportFactor: freezed == transportFactor ? _self.transportFactor : transportFactor // ignore: cast_nullable_to_non_nullable
as double?,homeType: freezed == homeType ? _self.homeType : homeType // ignore: cast_nullable_to_non_nullable
as String?,residents: freezed == residents ? _self.residents : residents // ignore: cast_nullable_to_non_nullable
as int?,heatingType: freezed == heatingType ? _self.heatingType : heatingType // ignore: cast_nullable_to_non_nullable
as String?,hasSolar: freezed == hasSolar ? _self.hasSolar : hasSolar // ignore: cast_nullable_to_non_nullable
as bool?,dailyEnergyBaselineKwh: freezed == dailyEnergyBaselineKwh ? _self.dailyEnergyBaselineKwh : dailyEnergyBaselineKwh // ignore: cast_nullable_to_non_nullable
as double?,dailyHeatingBaselineCo2: freezed == dailyHeatingBaselineCo2 ? _self.dailyHeatingBaselineCo2 : dailyHeatingBaselineCo2 // ignore: cast_nullable_to_non_nullable
as double?,dailyEnergyBaselineCo2: freezed == dailyEnergyBaselineCo2 ? _self.dailyEnergyBaselineCo2 : dailyEnergyBaselineCo2 // ignore: cast_nullable_to_non_nullable
as double?,gridIntensity: freezed == gridIntensity ? _self.gridIntensity : gridIntensity // ignore: cast_nullable_to_non_nullable
as double?,dietaryPreference: freezed == dietaryPreference ? _self.dietaryPreference : dietaryPreference // ignore: cast_nullable_to_non_nullable
as String?,dailyFoodBaselineCo2: freezed == dailyFoodBaselineCo2 ? _self.dailyFoodBaselineCo2 : dailyFoodBaselineCo2 // ignore: cast_nullable_to_non_nullable
as double?,totalDailyBaselineCo2: freezed == totalDailyBaselineCo2 ? _self.totalDailyBaselineCo2 : totalDailyBaselineCo2 // ignore: cast_nullable_to_non_nullable
as double?,xp: null == xp ? _self.xp : xp // ignore: cast_nullable_to_non_nullable
as int,level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as int,currentStreak: null == currentStreak ? _self.currentStreak : currentStreak // ignore: cast_nullable_to_non_nullable
as int,longestStreak: null == longestStreak ? _self.longestStreak : longestStreak // ignore: cast_nullable_to_non_nullable
as int,daysActive: null == daysActive ? _self.daysActive : daysActive // ignore: cast_nullable_to_non_nullable
as int,streakFreezeCount: null == streakFreezeCount ? _self.streakFreezeCount : streakFreezeCount // ignore: cast_nullable_to_non_nullable
as int,totalCo2Saved: null == totalCo2Saved ? _self.totalCo2Saved : totalCo2Saved // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [UserProfile].
extension UserProfilePatterns on UserProfile {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UserProfile value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UserProfile() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UserProfile value)  $default,){
final _that = this;
switch (_that) {
case _UserProfile():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UserProfile value)?  $default,){
final _that = this;
switch (_that) {
case _UserProfile() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String? email,  String? city, @JsonKey(name: 'country_code')  String? countryCode, @JsonKey(name: 'avatar_url')  String? avatarUrl, @JsonKey(name: 'primary_transport')  String? primaryTransport, @JsonKey(name: 'fuel_type')  String? fuelType, @JsonKey(name: 'engine_size')  String? engineSize, @JsonKey(name: 'vehicle_age')  String? vehicleAge, @JsonKey(name: 'vehicle_model')  String? vehicleModel, @JsonKey(name: 'avg_daily_km')  double? avgDailyKm, @JsonKey(name: 'transport_factor')  double? transportFactor, @JsonKey(name: 'home_type')  String? homeType,  int? residents, @JsonKey(name: 'heating_type')  String? heatingType, @JsonKey(name: 'has_solar')  bool? hasSolar, @JsonKey(name: 'daily_energy_baseline_kwh')  double? dailyEnergyBaselineKwh, @JsonKey(name: 'daily_heating_baseline_co2')  double? dailyHeatingBaselineCo2, @JsonKey(name: 'daily_energy_baseline_co2')  double? dailyEnergyBaselineCo2, @JsonKey(name: 'grid_intensity')  double? gridIntensity, @JsonKey(name: 'dietary_preference')  String? dietaryPreference, @JsonKey(name: 'daily_food_baseline_co2')  double? dailyFoodBaselineCo2, @JsonKey(name: 'total_daily_baseline_co2')  double? totalDailyBaselineCo2,  int xp,  int level, @JsonKey(name: 'current_streak')  int currentStreak, @JsonKey(name: 'longest_streak')  int longestStreak, @JsonKey(name: 'days_active')  int daysActive, @JsonKey(name: 'streak_freeze_count')  int streakFreezeCount, @JsonKey(name: 'total_co2_saved')  double totalCo2Saved)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UserProfile() when $default != null:
return $default(_that.id,_that.name,_that.email,_that.city,_that.countryCode,_that.avatarUrl,_that.primaryTransport,_that.fuelType,_that.engineSize,_that.vehicleAge,_that.vehicleModel,_that.avgDailyKm,_that.transportFactor,_that.homeType,_that.residents,_that.heatingType,_that.hasSolar,_that.dailyEnergyBaselineKwh,_that.dailyHeatingBaselineCo2,_that.dailyEnergyBaselineCo2,_that.gridIntensity,_that.dietaryPreference,_that.dailyFoodBaselineCo2,_that.totalDailyBaselineCo2,_that.xp,_that.level,_that.currentStreak,_that.longestStreak,_that.daysActive,_that.streakFreezeCount,_that.totalCo2Saved);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String? email,  String? city, @JsonKey(name: 'country_code')  String? countryCode, @JsonKey(name: 'avatar_url')  String? avatarUrl, @JsonKey(name: 'primary_transport')  String? primaryTransport, @JsonKey(name: 'fuel_type')  String? fuelType, @JsonKey(name: 'engine_size')  String? engineSize, @JsonKey(name: 'vehicle_age')  String? vehicleAge, @JsonKey(name: 'vehicle_model')  String? vehicleModel, @JsonKey(name: 'avg_daily_km')  double? avgDailyKm, @JsonKey(name: 'transport_factor')  double? transportFactor, @JsonKey(name: 'home_type')  String? homeType,  int? residents, @JsonKey(name: 'heating_type')  String? heatingType, @JsonKey(name: 'has_solar')  bool? hasSolar, @JsonKey(name: 'daily_energy_baseline_kwh')  double? dailyEnergyBaselineKwh, @JsonKey(name: 'daily_heating_baseline_co2')  double? dailyHeatingBaselineCo2, @JsonKey(name: 'daily_energy_baseline_co2')  double? dailyEnergyBaselineCo2, @JsonKey(name: 'grid_intensity')  double? gridIntensity, @JsonKey(name: 'dietary_preference')  String? dietaryPreference, @JsonKey(name: 'daily_food_baseline_co2')  double? dailyFoodBaselineCo2, @JsonKey(name: 'total_daily_baseline_co2')  double? totalDailyBaselineCo2,  int xp,  int level, @JsonKey(name: 'current_streak')  int currentStreak, @JsonKey(name: 'longest_streak')  int longestStreak, @JsonKey(name: 'days_active')  int daysActive, @JsonKey(name: 'streak_freeze_count')  int streakFreezeCount, @JsonKey(name: 'total_co2_saved')  double totalCo2Saved)  $default,) {final _that = this;
switch (_that) {
case _UserProfile():
return $default(_that.id,_that.name,_that.email,_that.city,_that.countryCode,_that.avatarUrl,_that.primaryTransport,_that.fuelType,_that.engineSize,_that.vehicleAge,_that.vehicleModel,_that.avgDailyKm,_that.transportFactor,_that.homeType,_that.residents,_that.heatingType,_that.hasSolar,_that.dailyEnergyBaselineKwh,_that.dailyHeatingBaselineCo2,_that.dailyEnergyBaselineCo2,_that.gridIntensity,_that.dietaryPreference,_that.dailyFoodBaselineCo2,_that.totalDailyBaselineCo2,_that.xp,_that.level,_that.currentStreak,_that.longestStreak,_that.daysActive,_that.streakFreezeCount,_that.totalCo2Saved);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String? email,  String? city, @JsonKey(name: 'country_code')  String? countryCode, @JsonKey(name: 'avatar_url')  String? avatarUrl, @JsonKey(name: 'primary_transport')  String? primaryTransport, @JsonKey(name: 'fuel_type')  String? fuelType, @JsonKey(name: 'engine_size')  String? engineSize, @JsonKey(name: 'vehicle_age')  String? vehicleAge, @JsonKey(name: 'vehicle_model')  String? vehicleModel, @JsonKey(name: 'avg_daily_km')  double? avgDailyKm, @JsonKey(name: 'transport_factor')  double? transportFactor, @JsonKey(name: 'home_type')  String? homeType,  int? residents, @JsonKey(name: 'heating_type')  String? heatingType, @JsonKey(name: 'has_solar')  bool? hasSolar, @JsonKey(name: 'daily_energy_baseline_kwh')  double? dailyEnergyBaselineKwh, @JsonKey(name: 'daily_heating_baseline_co2')  double? dailyHeatingBaselineCo2, @JsonKey(name: 'daily_energy_baseline_co2')  double? dailyEnergyBaselineCo2, @JsonKey(name: 'grid_intensity')  double? gridIntensity, @JsonKey(name: 'dietary_preference')  String? dietaryPreference, @JsonKey(name: 'daily_food_baseline_co2')  double? dailyFoodBaselineCo2, @JsonKey(name: 'total_daily_baseline_co2')  double? totalDailyBaselineCo2,  int xp,  int level, @JsonKey(name: 'current_streak')  int currentStreak, @JsonKey(name: 'longest_streak')  int longestStreak, @JsonKey(name: 'days_active')  int daysActive, @JsonKey(name: 'streak_freeze_count')  int streakFreezeCount, @JsonKey(name: 'total_co2_saved')  double totalCo2Saved)?  $default,) {final _that = this;
switch (_that) {
case _UserProfile() when $default != null:
return $default(_that.id,_that.name,_that.email,_that.city,_that.countryCode,_that.avatarUrl,_that.primaryTransport,_that.fuelType,_that.engineSize,_that.vehicleAge,_that.vehicleModel,_that.avgDailyKm,_that.transportFactor,_that.homeType,_that.residents,_that.heatingType,_that.hasSolar,_that.dailyEnergyBaselineKwh,_that.dailyHeatingBaselineCo2,_that.dailyEnergyBaselineCo2,_that.gridIntensity,_that.dietaryPreference,_that.dailyFoodBaselineCo2,_that.totalDailyBaselineCo2,_that.xp,_that.level,_that.currentStreak,_that.longestStreak,_that.daysActive,_that.streakFreezeCount,_that.totalCo2Saved);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UserProfile implements UserProfile {
  const _UserProfile({required this.id, required this.name, this.email, this.city, @JsonKey(name: 'country_code') this.countryCode, @JsonKey(name: 'avatar_url') this.avatarUrl, @JsonKey(name: 'primary_transport') this.primaryTransport, @JsonKey(name: 'fuel_type') this.fuelType, @JsonKey(name: 'engine_size') this.engineSize, @JsonKey(name: 'vehicle_age') this.vehicleAge, @JsonKey(name: 'vehicle_model') this.vehicleModel, @JsonKey(name: 'avg_daily_km') this.avgDailyKm, @JsonKey(name: 'transport_factor') this.transportFactor, @JsonKey(name: 'home_type') this.homeType, this.residents, @JsonKey(name: 'heating_type') this.heatingType, @JsonKey(name: 'has_solar') this.hasSolar, @JsonKey(name: 'daily_energy_baseline_kwh') this.dailyEnergyBaselineKwh, @JsonKey(name: 'daily_heating_baseline_co2') this.dailyHeatingBaselineCo2, @JsonKey(name: 'daily_energy_baseline_co2') this.dailyEnergyBaselineCo2, @JsonKey(name: 'grid_intensity') this.gridIntensity, @JsonKey(name: 'dietary_preference') this.dietaryPreference, @JsonKey(name: 'daily_food_baseline_co2') this.dailyFoodBaselineCo2, @JsonKey(name: 'total_daily_baseline_co2') this.totalDailyBaselineCo2, this.xp = 0, this.level = 1, @JsonKey(name: 'current_streak') this.currentStreak = 0, @JsonKey(name: 'longest_streak') this.longestStreak = 0, @JsonKey(name: 'days_active') this.daysActive = 0, @JsonKey(name: 'streak_freeze_count') this.streakFreezeCount = 0, @JsonKey(name: 'total_co2_saved') this.totalCo2Saved = 0.0});
  factory _UserProfile.fromJson(Map<String, dynamic> json) => _$UserProfileFromJson(json);

@override final  String id;
@override final  String name;
@override final  String? email;
@override final  String? city;
@override@JsonKey(name: 'country_code') final  String? countryCode;
@override@JsonKey(name: 'avatar_url') final  String? avatarUrl;
/// Transport profile
@override@JsonKey(name: 'primary_transport') final  String? primaryTransport;
@override@JsonKey(name: 'fuel_type') final  String? fuelType;
@override@JsonKey(name: 'engine_size') final  String? engineSize;
@override@JsonKey(name: 'vehicle_age') final  String? vehicleAge;
@override@JsonKey(name: 'vehicle_model') final  String? vehicleModel;
@override@JsonKey(name: 'avg_daily_km') final  double? avgDailyKm;
@override@JsonKey(name: 'transport_factor') final  double? transportFactor;
/// Energy profile
@override@JsonKey(name: 'home_type') final  String? homeType;
@override final  int? residents;
@override@JsonKey(name: 'heating_type') final  String? heatingType;
@override@JsonKey(name: 'has_solar') final  bool? hasSolar;
@override@JsonKey(name: 'daily_energy_baseline_kwh') final  double? dailyEnergyBaselineKwh;
@override@JsonKey(name: 'daily_heating_baseline_co2') final  double? dailyHeatingBaselineCo2;
@override@JsonKey(name: 'daily_energy_baseline_co2') final  double? dailyEnergyBaselineCo2;
@override@JsonKey(name: 'grid_intensity') final  double? gridIntensity;
/// Food profile
@override@JsonKey(name: 'dietary_preference') final  String? dietaryPreference;
@override@JsonKey(name: 'daily_food_baseline_co2') final  double? dailyFoodBaselineCo2;
/// Aggregate
@override@JsonKey(name: 'total_daily_baseline_co2') final  double? totalDailyBaselineCo2;
/// Gamification
@override@JsonKey() final  int xp;
@override@JsonKey() final  int level;
@override@JsonKey(name: 'current_streak') final  int currentStreak;
@override@JsonKey(name: 'longest_streak') final  int longestStreak;
@override@JsonKey(name: 'days_active') final  int daysActive;
@override@JsonKey(name: 'streak_freeze_count') final  int streakFreezeCount;
@override@JsonKey(name: 'total_co2_saved') final  double totalCo2Saved;

/// Create a copy of UserProfile
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserProfileCopyWith<_UserProfile> get copyWith => __$UserProfileCopyWithImpl<_UserProfile>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UserProfileToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UserProfile&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.email, email) || other.email == email)&&(identical(other.city, city) || other.city == city)&&(identical(other.countryCode, countryCode) || other.countryCode == countryCode)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.primaryTransport, primaryTransport) || other.primaryTransport == primaryTransport)&&(identical(other.fuelType, fuelType) || other.fuelType == fuelType)&&(identical(other.engineSize, engineSize) || other.engineSize == engineSize)&&(identical(other.vehicleAge, vehicleAge) || other.vehicleAge == vehicleAge)&&(identical(other.vehicleModel, vehicleModel) || other.vehicleModel == vehicleModel)&&(identical(other.avgDailyKm, avgDailyKm) || other.avgDailyKm == avgDailyKm)&&(identical(other.transportFactor, transportFactor) || other.transportFactor == transportFactor)&&(identical(other.homeType, homeType) || other.homeType == homeType)&&(identical(other.residents, residents) || other.residents == residents)&&(identical(other.heatingType, heatingType) || other.heatingType == heatingType)&&(identical(other.hasSolar, hasSolar) || other.hasSolar == hasSolar)&&(identical(other.dailyEnergyBaselineKwh, dailyEnergyBaselineKwh) || other.dailyEnergyBaselineKwh == dailyEnergyBaselineKwh)&&(identical(other.dailyHeatingBaselineCo2, dailyHeatingBaselineCo2) || other.dailyHeatingBaselineCo2 == dailyHeatingBaselineCo2)&&(identical(other.dailyEnergyBaselineCo2, dailyEnergyBaselineCo2) || other.dailyEnergyBaselineCo2 == dailyEnergyBaselineCo2)&&(identical(other.gridIntensity, gridIntensity) || other.gridIntensity == gridIntensity)&&(identical(other.dietaryPreference, dietaryPreference) || other.dietaryPreference == dietaryPreference)&&(identical(other.dailyFoodBaselineCo2, dailyFoodBaselineCo2) || other.dailyFoodBaselineCo2 == dailyFoodBaselineCo2)&&(identical(other.totalDailyBaselineCo2, totalDailyBaselineCo2) || other.totalDailyBaselineCo2 == totalDailyBaselineCo2)&&(identical(other.xp, xp) || other.xp == xp)&&(identical(other.level, level) || other.level == level)&&(identical(other.currentStreak, currentStreak) || other.currentStreak == currentStreak)&&(identical(other.longestStreak, longestStreak) || other.longestStreak == longestStreak)&&(identical(other.daysActive, daysActive) || other.daysActive == daysActive)&&(identical(other.streakFreezeCount, streakFreezeCount) || other.streakFreezeCount == streakFreezeCount)&&(identical(other.totalCo2Saved, totalCo2Saved) || other.totalCo2Saved == totalCo2Saved));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,name,email,city,countryCode,avatarUrl,primaryTransport,fuelType,engineSize,vehicleAge,vehicleModel,avgDailyKm,transportFactor,homeType,residents,heatingType,hasSolar,dailyEnergyBaselineKwh,dailyHeatingBaselineCo2,dailyEnergyBaselineCo2,gridIntensity,dietaryPreference,dailyFoodBaselineCo2,totalDailyBaselineCo2,xp,level,currentStreak,longestStreak,daysActive,streakFreezeCount,totalCo2Saved]);

@override
String toString() {
  return 'UserProfile(id: $id, name: $name, email: $email, city: $city, countryCode: $countryCode, avatarUrl: $avatarUrl, primaryTransport: $primaryTransport, fuelType: $fuelType, engineSize: $engineSize, vehicleAge: $vehicleAge, vehicleModel: $vehicleModel, avgDailyKm: $avgDailyKm, transportFactor: $transportFactor, homeType: $homeType, residents: $residents, heatingType: $heatingType, hasSolar: $hasSolar, dailyEnergyBaselineKwh: $dailyEnergyBaselineKwh, dailyHeatingBaselineCo2: $dailyHeatingBaselineCo2, dailyEnergyBaselineCo2: $dailyEnergyBaselineCo2, gridIntensity: $gridIntensity, dietaryPreference: $dietaryPreference, dailyFoodBaselineCo2: $dailyFoodBaselineCo2, totalDailyBaselineCo2: $totalDailyBaselineCo2, xp: $xp, level: $level, currentStreak: $currentStreak, longestStreak: $longestStreak, daysActive: $daysActive, streakFreezeCount: $streakFreezeCount, totalCo2Saved: $totalCo2Saved)';
}


}

/// @nodoc
abstract mixin class _$UserProfileCopyWith<$Res> implements $UserProfileCopyWith<$Res> {
  factory _$UserProfileCopyWith(_UserProfile value, $Res Function(_UserProfile) _then) = __$UserProfileCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String? email, String? city,@JsonKey(name: 'country_code') String? countryCode,@JsonKey(name: 'avatar_url') String? avatarUrl,@JsonKey(name: 'primary_transport') String? primaryTransport,@JsonKey(name: 'fuel_type') String? fuelType,@JsonKey(name: 'engine_size') String? engineSize,@JsonKey(name: 'vehicle_age') String? vehicleAge,@JsonKey(name: 'vehicle_model') String? vehicleModel,@JsonKey(name: 'avg_daily_km') double? avgDailyKm,@JsonKey(name: 'transport_factor') double? transportFactor,@JsonKey(name: 'home_type') String? homeType, int? residents,@JsonKey(name: 'heating_type') String? heatingType,@JsonKey(name: 'has_solar') bool? hasSolar,@JsonKey(name: 'daily_energy_baseline_kwh') double? dailyEnergyBaselineKwh,@JsonKey(name: 'daily_heating_baseline_co2') double? dailyHeatingBaselineCo2,@JsonKey(name: 'daily_energy_baseline_co2') double? dailyEnergyBaselineCo2,@JsonKey(name: 'grid_intensity') double? gridIntensity,@JsonKey(name: 'dietary_preference') String? dietaryPreference,@JsonKey(name: 'daily_food_baseline_co2') double? dailyFoodBaselineCo2,@JsonKey(name: 'total_daily_baseline_co2') double? totalDailyBaselineCo2, int xp, int level,@JsonKey(name: 'current_streak') int currentStreak,@JsonKey(name: 'longest_streak') int longestStreak,@JsonKey(name: 'days_active') int daysActive,@JsonKey(name: 'streak_freeze_count') int streakFreezeCount,@JsonKey(name: 'total_co2_saved') double totalCo2Saved
});




}
/// @nodoc
class __$UserProfileCopyWithImpl<$Res>
    implements _$UserProfileCopyWith<$Res> {
  __$UserProfileCopyWithImpl(this._self, this._then);

  final _UserProfile _self;
  final $Res Function(_UserProfile) _then;

/// Create a copy of UserProfile
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? email = freezed,Object? city = freezed,Object? countryCode = freezed,Object? avatarUrl = freezed,Object? primaryTransport = freezed,Object? fuelType = freezed,Object? engineSize = freezed,Object? vehicleAge = freezed,Object? vehicleModel = freezed,Object? avgDailyKm = freezed,Object? transportFactor = freezed,Object? homeType = freezed,Object? residents = freezed,Object? heatingType = freezed,Object? hasSolar = freezed,Object? dailyEnergyBaselineKwh = freezed,Object? dailyHeatingBaselineCo2 = freezed,Object? dailyEnergyBaselineCo2 = freezed,Object? gridIntensity = freezed,Object? dietaryPreference = freezed,Object? dailyFoodBaselineCo2 = freezed,Object? totalDailyBaselineCo2 = freezed,Object? xp = null,Object? level = null,Object? currentStreak = null,Object? longestStreak = null,Object? daysActive = null,Object? streakFreezeCount = null,Object? totalCo2Saved = null,}) {
  return _then(_UserProfile(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,city: freezed == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String?,countryCode: freezed == countryCode ? _self.countryCode : countryCode // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,primaryTransport: freezed == primaryTransport ? _self.primaryTransport : primaryTransport // ignore: cast_nullable_to_non_nullable
as String?,fuelType: freezed == fuelType ? _self.fuelType : fuelType // ignore: cast_nullable_to_non_nullable
as String?,engineSize: freezed == engineSize ? _self.engineSize : engineSize // ignore: cast_nullable_to_non_nullable
as String?,vehicleAge: freezed == vehicleAge ? _self.vehicleAge : vehicleAge // ignore: cast_nullable_to_non_nullable
as String?,vehicleModel: freezed == vehicleModel ? _self.vehicleModel : vehicleModel // ignore: cast_nullable_to_non_nullable
as String?,avgDailyKm: freezed == avgDailyKm ? _self.avgDailyKm : avgDailyKm // ignore: cast_nullable_to_non_nullable
as double?,transportFactor: freezed == transportFactor ? _self.transportFactor : transportFactor // ignore: cast_nullable_to_non_nullable
as double?,homeType: freezed == homeType ? _self.homeType : homeType // ignore: cast_nullable_to_non_nullable
as String?,residents: freezed == residents ? _self.residents : residents // ignore: cast_nullable_to_non_nullable
as int?,heatingType: freezed == heatingType ? _self.heatingType : heatingType // ignore: cast_nullable_to_non_nullable
as String?,hasSolar: freezed == hasSolar ? _self.hasSolar : hasSolar // ignore: cast_nullable_to_non_nullable
as bool?,dailyEnergyBaselineKwh: freezed == dailyEnergyBaselineKwh ? _self.dailyEnergyBaselineKwh : dailyEnergyBaselineKwh // ignore: cast_nullable_to_non_nullable
as double?,dailyHeatingBaselineCo2: freezed == dailyHeatingBaselineCo2 ? _self.dailyHeatingBaselineCo2 : dailyHeatingBaselineCo2 // ignore: cast_nullable_to_non_nullable
as double?,dailyEnergyBaselineCo2: freezed == dailyEnergyBaselineCo2 ? _self.dailyEnergyBaselineCo2 : dailyEnergyBaselineCo2 // ignore: cast_nullable_to_non_nullable
as double?,gridIntensity: freezed == gridIntensity ? _self.gridIntensity : gridIntensity // ignore: cast_nullable_to_non_nullable
as double?,dietaryPreference: freezed == dietaryPreference ? _self.dietaryPreference : dietaryPreference // ignore: cast_nullable_to_non_nullable
as String?,dailyFoodBaselineCo2: freezed == dailyFoodBaselineCo2 ? _self.dailyFoodBaselineCo2 : dailyFoodBaselineCo2 // ignore: cast_nullable_to_non_nullable
as double?,totalDailyBaselineCo2: freezed == totalDailyBaselineCo2 ? _self.totalDailyBaselineCo2 : totalDailyBaselineCo2 // ignore: cast_nullable_to_non_nullable
as double?,xp: null == xp ? _self.xp : xp // ignore: cast_nullable_to_non_nullable
as int,level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as int,currentStreak: null == currentStreak ? _self.currentStreak : currentStreak // ignore: cast_nullable_to_non_nullable
as int,longestStreak: null == longestStreak ? _self.longestStreak : longestStreak // ignore: cast_nullable_to_non_nullable
as int,daysActive: null == daysActive ? _self.daysActive : daysActive // ignore: cast_nullable_to_non_nullable
as int,streakFreezeCount: null == streakFreezeCount ? _self.streakFreezeCount : streakFreezeCount // ignore: cast_nullable_to_non_nullable
as int,totalCo2Saved: null == totalCo2Saved ? _self.totalCo2Saved : totalCo2Saved // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
