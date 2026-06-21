// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'daily_log.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TransportEntry {

 String get mode; double get distanceKm;@JsonKey(name: 'calculated_co2') double? get calculatedCo2;
/// Create a copy of TransportEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TransportEntryCopyWith<TransportEntry> get copyWith => _$TransportEntryCopyWithImpl<TransportEntry>(this as TransportEntry, _$identity);

  /// Serializes this TransportEntry to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TransportEntry&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.distanceKm, distanceKm) || other.distanceKm == distanceKm)&&(identical(other.calculatedCo2, calculatedCo2) || other.calculatedCo2 == calculatedCo2));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,mode,distanceKm,calculatedCo2);

@override
String toString() {
  return 'TransportEntry(mode: $mode, distanceKm: $distanceKm, calculatedCo2: $calculatedCo2)';
}


}

/// @nodoc
abstract mixin class $TransportEntryCopyWith<$Res>  {
  factory $TransportEntryCopyWith(TransportEntry value, $Res Function(TransportEntry) _then) = _$TransportEntryCopyWithImpl;
@useResult
$Res call({
 String mode, double distanceKm,@JsonKey(name: 'calculated_co2') double? calculatedCo2
});




}
/// @nodoc
class _$TransportEntryCopyWithImpl<$Res>
    implements $TransportEntryCopyWith<$Res> {
  _$TransportEntryCopyWithImpl(this._self, this._then);

  final TransportEntry _self;
  final $Res Function(TransportEntry) _then;

/// Create a copy of TransportEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? mode = null,Object? distanceKm = null,Object? calculatedCo2 = freezed,}) {
  return _then(_self.copyWith(
mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as String,distanceKm: null == distanceKm ? _self.distanceKm : distanceKm // ignore: cast_nullable_to_non_nullable
as double,calculatedCo2: freezed == calculatedCo2 ? _self.calculatedCo2 : calculatedCo2 // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

}


/// Adds pattern-matching-related methods to [TransportEntry].
extension TransportEntryPatterns on TransportEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TransportEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TransportEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TransportEntry value)  $default,){
final _that = this;
switch (_that) {
case _TransportEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TransportEntry value)?  $default,){
final _that = this;
switch (_that) {
case _TransportEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String mode,  double distanceKm, @JsonKey(name: 'calculated_co2')  double? calculatedCo2)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TransportEntry() when $default != null:
return $default(_that.mode,_that.distanceKm,_that.calculatedCo2);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String mode,  double distanceKm, @JsonKey(name: 'calculated_co2')  double? calculatedCo2)  $default,) {final _that = this;
switch (_that) {
case _TransportEntry():
return $default(_that.mode,_that.distanceKm,_that.calculatedCo2);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String mode,  double distanceKm, @JsonKey(name: 'calculated_co2')  double? calculatedCo2)?  $default,) {final _that = this;
switch (_that) {
case _TransportEntry() when $default != null:
return $default(_that.mode,_that.distanceKm,_that.calculatedCo2);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TransportEntry implements TransportEntry {
  const _TransportEntry({required this.mode, required this.distanceKm, @JsonKey(name: 'calculated_co2') this.calculatedCo2});
  factory _TransportEntry.fromJson(Map<String, dynamic> json) => _$TransportEntryFromJson(json);

@override final  String mode;
@override final  double distanceKm;
@override@JsonKey(name: 'calculated_co2') final  double? calculatedCo2;

/// Create a copy of TransportEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TransportEntryCopyWith<_TransportEntry> get copyWith => __$TransportEntryCopyWithImpl<_TransportEntry>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TransportEntryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TransportEntry&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.distanceKm, distanceKm) || other.distanceKm == distanceKm)&&(identical(other.calculatedCo2, calculatedCo2) || other.calculatedCo2 == calculatedCo2));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,mode,distanceKm,calculatedCo2);

@override
String toString() {
  return 'TransportEntry(mode: $mode, distanceKm: $distanceKm, calculatedCo2: $calculatedCo2)';
}


}

/// @nodoc
abstract mixin class _$TransportEntryCopyWith<$Res> implements $TransportEntryCopyWith<$Res> {
  factory _$TransportEntryCopyWith(_TransportEntry value, $Res Function(_TransportEntry) _then) = __$TransportEntryCopyWithImpl;
@override @useResult
$Res call({
 String mode, double distanceKm,@JsonKey(name: 'calculated_co2') double? calculatedCo2
});




}
/// @nodoc
class __$TransportEntryCopyWithImpl<$Res>
    implements _$TransportEntryCopyWith<$Res> {
  __$TransportEntryCopyWithImpl(this._self, this._then);

  final _TransportEntry _self;
  final $Res Function(_TransportEntry) _then;

/// Create a copy of TransportEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? mode = null,Object? distanceKm = null,Object? calculatedCo2 = freezed,}) {
  return _then(_TransportEntry(
mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as String,distanceKm: null == distanceKm ? _self.distanceKm : distanceKm // ignore: cast_nullable_to_non_nullable
as double,calculatedCo2: freezed == calculatedCo2 ? _self.calculatedCo2 : calculatedCo2 // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}


/// @nodoc
mixin _$FoodEntry {

 String get mealSlot; String get foodName; String get category; String get servingSize; double get grams;@JsonKey(name: 'co2_per_100g') double? get co2Per100g;@JsonKey(name: 'calculated_co2') double? get calculatedCo2;@JsonKey(name: 'off_barcode') String? get offBarcode;
/// Create a copy of FoodEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FoodEntryCopyWith<FoodEntry> get copyWith => _$FoodEntryCopyWithImpl<FoodEntry>(this as FoodEntry, _$identity);

  /// Serializes this FoodEntry to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FoodEntry&&(identical(other.mealSlot, mealSlot) || other.mealSlot == mealSlot)&&(identical(other.foodName, foodName) || other.foodName == foodName)&&(identical(other.category, category) || other.category == category)&&(identical(other.servingSize, servingSize) || other.servingSize == servingSize)&&(identical(other.grams, grams) || other.grams == grams)&&(identical(other.co2Per100g, co2Per100g) || other.co2Per100g == co2Per100g)&&(identical(other.calculatedCo2, calculatedCo2) || other.calculatedCo2 == calculatedCo2)&&(identical(other.offBarcode, offBarcode) || other.offBarcode == offBarcode));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,mealSlot,foodName,category,servingSize,grams,co2Per100g,calculatedCo2,offBarcode);

@override
String toString() {
  return 'FoodEntry(mealSlot: $mealSlot, foodName: $foodName, category: $category, servingSize: $servingSize, grams: $grams, co2Per100g: $co2Per100g, calculatedCo2: $calculatedCo2, offBarcode: $offBarcode)';
}


}

/// @nodoc
abstract mixin class $FoodEntryCopyWith<$Res>  {
  factory $FoodEntryCopyWith(FoodEntry value, $Res Function(FoodEntry) _then) = _$FoodEntryCopyWithImpl;
@useResult
$Res call({
 String mealSlot, String foodName, String category, String servingSize, double grams,@JsonKey(name: 'co2_per_100g') double? co2Per100g,@JsonKey(name: 'calculated_co2') double? calculatedCo2,@JsonKey(name: 'off_barcode') String? offBarcode
});




}
/// @nodoc
class _$FoodEntryCopyWithImpl<$Res>
    implements $FoodEntryCopyWith<$Res> {
  _$FoodEntryCopyWithImpl(this._self, this._then);

  final FoodEntry _self;
  final $Res Function(FoodEntry) _then;

/// Create a copy of FoodEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? mealSlot = null,Object? foodName = null,Object? category = null,Object? servingSize = null,Object? grams = null,Object? co2Per100g = freezed,Object? calculatedCo2 = freezed,Object? offBarcode = freezed,}) {
  return _then(_self.copyWith(
mealSlot: null == mealSlot ? _self.mealSlot : mealSlot // ignore: cast_nullable_to_non_nullable
as String,foodName: null == foodName ? _self.foodName : foodName // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,servingSize: null == servingSize ? _self.servingSize : servingSize // ignore: cast_nullable_to_non_nullable
as String,grams: null == grams ? _self.grams : grams // ignore: cast_nullable_to_non_nullable
as double,co2Per100g: freezed == co2Per100g ? _self.co2Per100g : co2Per100g // ignore: cast_nullable_to_non_nullable
as double?,calculatedCo2: freezed == calculatedCo2 ? _self.calculatedCo2 : calculatedCo2 // ignore: cast_nullable_to_non_nullable
as double?,offBarcode: freezed == offBarcode ? _self.offBarcode : offBarcode // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [FoodEntry].
extension FoodEntryPatterns on FoodEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FoodEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FoodEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FoodEntry value)  $default,){
final _that = this;
switch (_that) {
case _FoodEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FoodEntry value)?  $default,){
final _that = this;
switch (_that) {
case _FoodEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String mealSlot,  String foodName,  String category,  String servingSize,  double grams, @JsonKey(name: 'co2_per_100g')  double? co2Per100g, @JsonKey(name: 'calculated_co2')  double? calculatedCo2, @JsonKey(name: 'off_barcode')  String? offBarcode)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FoodEntry() when $default != null:
return $default(_that.mealSlot,_that.foodName,_that.category,_that.servingSize,_that.grams,_that.co2Per100g,_that.calculatedCo2,_that.offBarcode);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String mealSlot,  String foodName,  String category,  String servingSize,  double grams, @JsonKey(name: 'co2_per_100g')  double? co2Per100g, @JsonKey(name: 'calculated_co2')  double? calculatedCo2, @JsonKey(name: 'off_barcode')  String? offBarcode)  $default,) {final _that = this;
switch (_that) {
case _FoodEntry():
return $default(_that.mealSlot,_that.foodName,_that.category,_that.servingSize,_that.grams,_that.co2Per100g,_that.calculatedCo2,_that.offBarcode);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String mealSlot,  String foodName,  String category,  String servingSize,  double grams, @JsonKey(name: 'co2_per_100g')  double? co2Per100g, @JsonKey(name: 'calculated_co2')  double? calculatedCo2, @JsonKey(name: 'off_barcode')  String? offBarcode)?  $default,) {final _that = this;
switch (_that) {
case _FoodEntry() when $default != null:
return $default(_that.mealSlot,_that.foodName,_that.category,_that.servingSize,_that.grams,_that.co2Per100g,_that.calculatedCo2,_that.offBarcode);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FoodEntry implements FoodEntry {
  const _FoodEntry({required this.mealSlot, required this.foodName, required this.category, required this.servingSize, required this.grams, @JsonKey(name: 'co2_per_100g') this.co2Per100g, @JsonKey(name: 'calculated_co2') this.calculatedCo2, @JsonKey(name: 'off_barcode') this.offBarcode});
  factory _FoodEntry.fromJson(Map<String, dynamic> json) => _$FoodEntryFromJson(json);

@override final  String mealSlot;
@override final  String foodName;
@override final  String category;
@override final  String servingSize;
@override final  double grams;
@override@JsonKey(name: 'co2_per_100g') final  double? co2Per100g;
@override@JsonKey(name: 'calculated_co2') final  double? calculatedCo2;
@override@JsonKey(name: 'off_barcode') final  String? offBarcode;

/// Create a copy of FoodEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FoodEntryCopyWith<_FoodEntry> get copyWith => __$FoodEntryCopyWithImpl<_FoodEntry>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FoodEntryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FoodEntry&&(identical(other.mealSlot, mealSlot) || other.mealSlot == mealSlot)&&(identical(other.foodName, foodName) || other.foodName == foodName)&&(identical(other.category, category) || other.category == category)&&(identical(other.servingSize, servingSize) || other.servingSize == servingSize)&&(identical(other.grams, grams) || other.grams == grams)&&(identical(other.co2Per100g, co2Per100g) || other.co2Per100g == co2Per100g)&&(identical(other.calculatedCo2, calculatedCo2) || other.calculatedCo2 == calculatedCo2)&&(identical(other.offBarcode, offBarcode) || other.offBarcode == offBarcode));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,mealSlot,foodName,category,servingSize,grams,co2Per100g,calculatedCo2,offBarcode);

@override
String toString() {
  return 'FoodEntry(mealSlot: $mealSlot, foodName: $foodName, category: $category, servingSize: $servingSize, grams: $grams, co2Per100g: $co2Per100g, calculatedCo2: $calculatedCo2, offBarcode: $offBarcode)';
}


}

/// @nodoc
abstract mixin class _$FoodEntryCopyWith<$Res> implements $FoodEntryCopyWith<$Res> {
  factory _$FoodEntryCopyWith(_FoodEntry value, $Res Function(_FoodEntry) _then) = __$FoodEntryCopyWithImpl;
@override @useResult
$Res call({
 String mealSlot, String foodName, String category, String servingSize, double grams,@JsonKey(name: 'co2_per_100g') double? co2Per100g,@JsonKey(name: 'calculated_co2') double? calculatedCo2,@JsonKey(name: 'off_barcode') String? offBarcode
});




}
/// @nodoc
class __$FoodEntryCopyWithImpl<$Res>
    implements _$FoodEntryCopyWith<$Res> {
  __$FoodEntryCopyWithImpl(this._self, this._then);

  final _FoodEntry _self;
  final $Res Function(_FoodEntry) _then;

/// Create a copy of FoodEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? mealSlot = null,Object? foodName = null,Object? category = null,Object? servingSize = null,Object? grams = null,Object? co2Per100g = freezed,Object? calculatedCo2 = freezed,Object? offBarcode = freezed,}) {
  return _then(_FoodEntry(
mealSlot: null == mealSlot ? _self.mealSlot : mealSlot // ignore: cast_nullable_to_non_nullable
as String,foodName: null == foodName ? _self.foodName : foodName // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,servingSize: null == servingSize ? _self.servingSize : servingSize // ignore: cast_nullable_to_non_nullable
as String,grams: null == grams ? _self.grams : grams // ignore: cast_nullable_to_non_nullable
as double,co2Per100g: freezed == co2Per100g ? _self.co2Per100g : co2Per100g // ignore: cast_nullable_to_non_nullable
as double?,calculatedCo2: freezed == calculatedCo2 ? _self.calculatedCo2 : calculatedCo2 // ignore: cast_nullable_to_non_nullable
as double?,offBarcode: freezed == offBarcode ? _self.offBarcode : offBarcode // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$DailyLog {

@JsonKey(name: 'user_id') String get userId; String get date;@JsonKey(name: 'transport_entries') List<TransportEntry> get transportEntries;@JsonKey(name: 'transport_co2') double get transportCo2;@JsonKey(name: 'food_entries') List<FoodEntry> get foodEntries;@JsonKey(name: 'food_co2') double get foodCo2;@JsonKey(name: 'energy_deviations') List<String> get energyDeviations;@JsonKey(name: 'energy_co2') double get energyCo2;@JsonKey(name: 'total_daily_co2') double get totalDailyCo2;@JsonKey(name: 'baseline_co2') double get baselineCo2;@JsonKey(name: 'co2_saved_vs_baseline') double get co2SavedVsBaseline;@JsonKey(name: 'percent_vs_baseline') double get percentVsBaseline;@JsonKey(name: 'xp_earned') int get xpEarned;@JsonKey(name: 'emission_factor_version') String get emissionFactorVersion;@JsonKey(name: 'sync_status', includeToJson: false, includeFromJson: false) String get syncStatus;
/// Create a copy of DailyLog
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DailyLogCopyWith<DailyLog> get copyWith => _$DailyLogCopyWithImpl<DailyLog>(this as DailyLog, _$identity);

  /// Serializes this DailyLog to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DailyLog&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.date, date) || other.date == date)&&const DeepCollectionEquality().equals(other.transportEntries, transportEntries)&&(identical(other.transportCo2, transportCo2) || other.transportCo2 == transportCo2)&&const DeepCollectionEquality().equals(other.foodEntries, foodEntries)&&(identical(other.foodCo2, foodCo2) || other.foodCo2 == foodCo2)&&const DeepCollectionEquality().equals(other.energyDeviations, energyDeviations)&&(identical(other.energyCo2, energyCo2) || other.energyCo2 == energyCo2)&&(identical(other.totalDailyCo2, totalDailyCo2) || other.totalDailyCo2 == totalDailyCo2)&&(identical(other.baselineCo2, baselineCo2) || other.baselineCo2 == baselineCo2)&&(identical(other.co2SavedVsBaseline, co2SavedVsBaseline) || other.co2SavedVsBaseline == co2SavedVsBaseline)&&(identical(other.percentVsBaseline, percentVsBaseline) || other.percentVsBaseline == percentVsBaseline)&&(identical(other.xpEarned, xpEarned) || other.xpEarned == xpEarned)&&(identical(other.emissionFactorVersion, emissionFactorVersion) || other.emissionFactorVersion == emissionFactorVersion)&&(identical(other.syncStatus, syncStatus) || other.syncStatus == syncStatus));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,userId,date,const DeepCollectionEquality().hash(transportEntries),transportCo2,const DeepCollectionEquality().hash(foodEntries),foodCo2,const DeepCollectionEquality().hash(energyDeviations),energyCo2,totalDailyCo2,baselineCo2,co2SavedVsBaseline,percentVsBaseline,xpEarned,emissionFactorVersion,syncStatus);

@override
String toString() {
  return 'DailyLog(userId: $userId, date: $date, transportEntries: $transportEntries, transportCo2: $transportCo2, foodEntries: $foodEntries, foodCo2: $foodCo2, energyDeviations: $energyDeviations, energyCo2: $energyCo2, totalDailyCo2: $totalDailyCo2, baselineCo2: $baselineCo2, co2SavedVsBaseline: $co2SavedVsBaseline, percentVsBaseline: $percentVsBaseline, xpEarned: $xpEarned, emissionFactorVersion: $emissionFactorVersion, syncStatus: $syncStatus)';
}


}

/// @nodoc
abstract mixin class $DailyLogCopyWith<$Res>  {
  factory $DailyLogCopyWith(DailyLog value, $Res Function(DailyLog) _then) = _$DailyLogCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'user_id') String userId, String date,@JsonKey(name: 'transport_entries') List<TransportEntry> transportEntries,@JsonKey(name: 'transport_co2') double transportCo2,@JsonKey(name: 'food_entries') List<FoodEntry> foodEntries,@JsonKey(name: 'food_co2') double foodCo2,@JsonKey(name: 'energy_deviations') List<String> energyDeviations,@JsonKey(name: 'energy_co2') double energyCo2,@JsonKey(name: 'total_daily_co2') double totalDailyCo2,@JsonKey(name: 'baseline_co2') double baselineCo2,@JsonKey(name: 'co2_saved_vs_baseline') double co2SavedVsBaseline,@JsonKey(name: 'percent_vs_baseline') double percentVsBaseline,@JsonKey(name: 'xp_earned') int xpEarned,@JsonKey(name: 'emission_factor_version') String emissionFactorVersion,@JsonKey(name: 'sync_status', includeToJson: false, includeFromJson: false) String syncStatus
});




}
/// @nodoc
class _$DailyLogCopyWithImpl<$Res>
    implements $DailyLogCopyWith<$Res> {
  _$DailyLogCopyWithImpl(this._self, this._then);

  final DailyLog _self;
  final $Res Function(DailyLog) _then;

/// Create a copy of DailyLog
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? userId = null,Object? date = null,Object? transportEntries = null,Object? transportCo2 = null,Object? foodEntries = null,Object? foodCo2 = null,Object? energyDeviations = null,Object? energyCo2 = null,Object? totalDailyCo2 = null,Object? baselineCo2 = null,Object? co2SavedVsBaseline = null,Object? percentVsBaseline = null,Object? xpEarned = null,Object? emissionFactorVersion = null,Object? syncStatus = null,}) {
  return _then(_self.copyWith(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,transportEntries: null == transportEntries ? _self.transportEntries : transportEntries // ignore: cast_nullable_to_non_nullable
as List<TransportEntry>,transportCo2: null == transportCo2 ? _self.transportCo2 : transportCo2 // ignore: cast_nullable_to_non_nullable
as double,foodEntries: null == foodEntries ? _self.foodEntries : foodEntries // ignore: cast_nullable_to_non_nullable
as List<FoodEntry>,foodCo2: null == foodCo2 ? _self.foodCo2 : foodCo2 // ignore: cast_nullable_to_non_nullable
as double,energyDeviations: null == energyDeviations ? _self.energyDeviations : energyDeviations // ignore: cast_nullable_to_non_nullable
as List<String>,energyCo2: null == energyCo2 ? _self.energyCo2 : energyCo2 // ignore: cast_nullable_to_non_nullable
as double,totalDailyCo2: null == totalDailyCo2 ? _self.totalDailyCo2 : totalDailyCo2 // ignore: cast_nullable_to_non_nullable
as double,baselineCo2: null == baselineCo2 ? _self.baselineCo2 : baselineCo2 // ignore: cast_nullable_to_non_nullable
as double,co2SavedVsBaseline: null == co2SavedVsBaseline ? _self.co2SavedVsBaseline : co2SavedVsBaseline // ignore: cast_nullable_to_non_nullable
as double,percentVsBaseline: null == percentVsBaseline ? _self.percentVsBaseline : percentVsBaseline // ignore: cast_nullable_to_non_nullable
as double,xpEarned: null == xpEarned ? _self.xpEarned : xpEarned // ignore: cast_nullable_to_non_nullable
as int,emissionFactorVersion: null == emissionFactorVersion ? _self.emissionFactorVersion : emissionFactorVersion // ignore: cast_nullable_to_non_nullable
as String,syncStatus: null == syncStatus ? _self.syncStatus : syncStatus // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [DailyLog].
extension DailyLogPatterns on DailyLog {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DailyLog value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DailyLog() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DailyLog value)  $default,){
final _that = this;
switch (_that) {
case _DailyLog():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DailyLog value)?  $default,){
final _that = this;
switch (_that) {
case _DailyLog() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'user_id')  String userId,  String date, @JsonKey(name: 'transport_entries')  List<TransportEntry> transportEntries, @JsonKey(name: 'transport_co2')  double transportCo2, @JsonKey(name: 'food_entries')  List<FoodEntry> foodEntries, @JsonKey(name: 'food_co2')  double foodCo2, @JsonKey(name: 'energy_deviations')  List<String> energyDeviations, @JsonKey(name: 'energy_co2')  double energyCo2, @JsonKey(name: 'total_daily_co2')  double totalDailyCo2, @JsonKey(name: 'baseline_co2')  double baselineCo2, @JsonKey(name: 'co2_saved_vs_baseline')  double co2SavedVsBaseline, @JsonKey(name: 'percent_vs_baseline')  double percentVsBaseline, @JsonKey(name: 'xp_earned')  int xpEarned, @JsonKey(name: 'emission_factor_version')  String emissionFactorVersion, @JsonKey(name: 'sync_status', includeToJson: false, includeFromJson: false)  String syncStatus)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DailyLog() when $default != null:
return $default(_that.userId,_that.date,_that.transportEntries,_that.transportCo2,_that.foodEntries,_that.foodCo2,_that.energyDeviations,_that.energyCo2,_that.totalDailyCo2,_that.baselineCo2,_that.co2SavedVsBaseline,_that.percentVsBaseline,_that.xpEarned,_that.emissionFactorVersion,_that.syncStatus);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'user_id')  String userId,  String date, @JsonKey(name: 'transport_entries')  List<TransportEntry> transportEntries, @JsonKey(name: 'transport_co2')  double transportCo2, @JsonKey(name: 'food_entries')  List<FoodEntry> foodEntries, @JsonKey(name: 'food_co2')  double foodCo2, @JsonKey(name: 'energy_deviations')  List<String> energyDeviations, @JsonKey(name: 'energy_co2')  double energyCo2, @JsonKey(name: 'total_daily_co2')  double totalDailyCo2, @JsonKey(name: 'baseline_co2')  double baselineCo2, @JsonKey(name: 'co2_saved_vs_baseline')  double co2SavedVsBaseline, @JsonKey(name: 'percent_vs_baseline')  double percentVsBaseline, @JsonKey(name: 'xp_earned')  int xpEarned, @JsonKey(name: 'emission_factor_version')  String emissionFactorVersion, @JsonKey(name: 'sync_status', includeToJson: false, includeFromJson: false)  String syncStatus)  $default,) {final _that = this;
switch (_that) {
case _DailyLog():
return $default(_that.userId,_that.date,_that.transportEntries,_that.transportCo2,_that.foodEntries,_that.foodCo2,_that.energyDeviations,_that.energyCo2,_that.totalDailyCo2,_that.baselineCo2,_that.co2SavedVsBaseline,_that.percentVsBaseline,_that.xpEarned,_that.emissionFactorVersion,_that.syncStatus);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'user_id')  String userId,  String date, @JsonKey(name: 'transport_entries')  List<TransportEntry> transportEntries, @JsonKey(name: 'transport_co2')  double transportCo2, @JsonKey(name: 'food_entries')  List<FoodEntry> foodEntries, @JsonKey(name: 'food_co2')  double foodCo2, @JsonKey(name: 'energy_deviations')  List<String> energyDeviations, @JsonKey(name: 'energy_co2')  double energyCo2, @JsonKey(name: 'total_daily_co2')  double totalDailyCo2, @JsonKey(name: 'baseline_co2')  double baselineCo2, @JsonKey(name: 'co2_saved_vs_baseline')  double co2SavedVsBaseline, @JsonKey(name: 'percent_vs_baseline')  double percentVsBaseline, @JsonKey(name: 'xp_earned')  int xpEarned, @JsonKey(name: 'emission_factor_version')  String emissionFactorVersion, @JsonKey(name: 'sync_status', includeToJson: false, includeFromJson: false)  String syncStatus)?  $default,) {final _that = this;
switch (_that) {
case _DailyLog() when $default != null:
return $default(_that.userId,_that.date,_that.transportEntries,_that.transportCo2,_that.foodEntries,_that.foodCo2,_that.energyDeviations,_that.energyCo2,_that.totalDailyCo2,_that.baselineCo2,_that.co2SavedVsBaseline,_that.percentVsBaseline,_that.xpEarned,_that.emissionFactorVersion,_that.syncStatus);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DailyLog extends DailyLog {
  const _DailyLog({@JsonKey(name: 'user_id') required this.userId, required this.date, @JsonKey(name: 'transport_entries') final  List<TransportEntry> transportEntries = const [], @JsonKey(name: 'transport_co2') this.transportCo2 = 0.0, @JsonKey(name: 'food_entries') final  List<FoodEntry> foodEntries = const [], @JsonKey(name: 'food_co2') this.foodCo2 = 0.0, @JsonKey(name: 'energy_deviations') final  List<String> energyDeviations = const [], @JsonKey(name: 'energy_co2') this.energyCo2 = 0.0, @JsonKey(name: 'total_daily_co2') this.totalDailyCo2 = 0.0, @JsonKey(name: 'baseline_co2') this.baselineCo2 = 0.0, @JsonKey(name: 'co2_saved_vs_baseline') this.co2SavedVsBaseline = 0.0, @JsonKey(name: 'percent_vs_baseline') this.percentVsBaseline = 0.0, @JsonKey(name: 'xp_earned') this.xpEarned = 0, @JsonKey(name: 'emission_factor_version') this.emissionFactorVersion = '1.0', @JsonKey(name: 'sync_status', includeToJson: false, includeFromJson: false) this.syncStatus = 'pending'}): _transportEntries = transportEntries,_foodEntries = foodEntries,_energyDeviations = energyDeviations,super._();
  factory _DailyLog.fromJson(Map<String, dynamic> json) => _$DailyLogFromJson(json);

@override@JsonKey(name: 'user_id') final  String userId;
@override final  String date;
 final  List<TransportEntry> _transportEntries;
@override@JsonKey(name: 'transport_entries') List<TransportEntry> get transportEntries {
  if (_transportEntries is EqualUnmodifiableListView) return _transportEntries;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_transportEntries);
}

@override@JsonKey(name: 'transport_co2') final  double transportCo2;
 final  List<FoodEntry> _foodEntries;
@override@JsonKey(name: 'food_entries') List<FoodEntry> get foodEntries {
  if (_foodEntries is EqualUnmodifiableListView) return _foodEntries;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_foodEntries);
}

@override@JsonKey(name: 'food_co2') final  double foodCo2;
 final  List<String> _energyDeviations;
@override@JsonKey(name: 'energy_deviations') List<String> get energyDeviations {
  if (_energyDeviations is EqualUnmodifiableListView) return _energyDeviations;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_energyDeviations);
}

@override@JsonKey(name: 'energy_co2') final  double energyCo2;
@override@JsonKey(name: 'total_daily_co2') final  double totalDailyCo2;
@override@JsonKey(name: 'baseline_co2') final  double baselineCo2;
@override@JsonKey(name: 'co2_saved_vs_baseline') final  double co2SavedVsBaseline;
@override@JsonKey(name: 'percent_vs_baseline') final  double percentVsBaseline;
@override@JsonKey(name: 'xp_earned') final  int xpEarned;
@override@JsonKey(name: 'emission_factor_version') final  String emissionFactorVersion;
@override@JsonKey(name: 'sync_status', includeToJson: false, includeFromJson: false) final  String syncStatus;

/// Create a copy of DailyLog
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DailyLogCopyWith<_DailyLog> get copyWith => __$DailyLogCopyWithImpl<_DailyLog>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DailyLogToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DailyLog&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.date, date) || other.date == date)&&const DeepCollectionEquality().equals(other._transportEntries, _transportEntries)&&(identical(other.transportCo2, transportCo2) || other.transportCo2 == transportCo2)&&const DeepCollectionEquality().equals(other._foodEntries, _foodEntries)&&(identical(other.foodCo2, foodCo2) || other.foodCo2 == foodCo2)&&const DeepCollectionEquality().equals(other._energyDeviations, _energyDeviations)&&(identical(other.energyCo2, energyCo2) || other.energyCo2 == energyCo2)&&(identical(other.totalDailyCo2, totalDailyCo2) || other.totalDailyCo2 == totalDailyCo2)&&(identical(other.baselineCo2, baselineCo2) || other.baselineCo2 == baselineCo2)&&(identical(other.co2SavedVsBaseline, co2SavedVsBaseline) || other.co2SavedVsBaseline == co2SavedVsBaseline)&&(identical(other.percentVsBaseline, percentVsBaseline) || other.percentVsBaseline == percentVsBaseline)&&(identical(other.xpEarned, xpEarned) || other.xpEarned == xpEarned)&&(identical(other.emissionFactorVersion, emissionFactorVersion) || other.emissionFactorVersion == emissionFactorVersion)&&(identical(other.syncStatus, syncStatus) || other.syncStatus == syncStatus));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,userId,date,const DeepCollectionEquality().hash(_transportEntries),transportCo2,const DeepCollectionEquality().hash(_foodEntries),foodCo2,const DeepCollectionEquality().hash(_energyDeviations),energyCo2,totalDailyCo2,baselineCo2,co2SavedVsBaseline,percentVsBaseline,xpEarned,emissionFactorVersion,syncStatus);

@override
String toString() {
  return 'DailyLog(userId: $userId, date: $date, transportEntries: $transportEntries, transportCo2: $transportCo2, foodEntries: $foodEntries, foodCo2: $foodCo2, energyDeviations: $energyDeviations, energyCo2: $energyCo2, totalDailyCo2: $totalDailyCo2, baselineCo2: $baselineCo2, co2SavedVsBaseline: $co2SavedVsBaseline, percentVsBaseline: $percentVsBaseline, xpEarned: $xpEarned, emissionFactorVersion: $emissionFactorVersion, syncStatus: $syncStatus)';
}


}

/// @nodoc
abstract mixin class _$DailyLogCopyWith<$Res> implements $DailyLogCopyWith<$Res> {
  factory _$DailyLogCopyWith(_DailyLog value, $Res Function(_DailyLog) _then) = __$DailyLogCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'user_id') String userId, String date,@JsonKey(name: 'transport_entries') List<TransportEntry> transportEntries,@JsonKey(name: 'transport_co2') double transportCo2,@JsonKey(name: 'food_entries') List<FoodEntry> foodEntries,@JsonKey(name: 'food_co2') double foodCo2,@JsonKey(name: 'energy_deviations') List<String> energyDeviations,@JsonKey(name: 'energy_co2') double energyCo2,@JsonKey(name: 'total_daily_co2') double totalDailyCo2,@JsonKey(name: 'baseline_co2') double baselineCo2,@JsonKey(name: 'co2_saved_vs_baseline') double co2SavedVsBaseline,@JsonKey(name: 'percent_vs_baseline') double percentVsBaseline,@JsonKey(name: 'xp_earned') int xpEarned,@JsonKey(name: 'emission_factor_version') String emissionFactorVersion,@JsonKey(name: 'sync_status', includeToJson: false, includeFromJson: false) String syncStatus
});




}
/// @nodoc
class __$DailyLogCopyWithImpl<$Res>
    implements _$DailyLogCopyWith<$Res> {
  __$DailyLogCopyWithImpl(this._self, this._then);

  final _DailyLog _self;
  final $Res Function(_DailyLog) _then;

/// Create a copy of DailyLog
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? userId = null,Object? date = null,Object? transportEntries = null,Object? transportCo2 = null,Object? foodEntries = null,Object? foodCo2 = null,Object? energyDeviations = null,Object? energyCo2 = null,Object? totalDailyCo2 = null,Object? baselineCo2 = null,Object? co2SavedVsBaseline = null,Object? percentVsBaseline = null,Object? xpEarned = null,Object? emissionFactorVersion = null,Object? syncStatus = null,}) {
  return _then(_DailyLog(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,transportEntries: null == transportEntries ? _self._transportEntries : transportEntries // ignore: cast_nullable_to_non_nullable
as List<TransportEntry>,transportCo2: null == transportCo2 ? _self.transportCo2 : transportCo2 // ignore: cast_nullable_to_non_nullable
as double,foodEntries: null == foodEntries ? _self._foodEntries : foodEntries // ignore: cast_nullable_to_non_nullable
as List<FoodEntry>,foodCo2: null == foodCo2 ? _self.foodCo2 : foodCo2 // ignore: cast_nullable_to_non_nullable
as double,energyDeviations: null == energyDeviations ? _self._energyDeviations : energyDeviations // ignore: cast_nullable_to_non_nullable
as List<String>,energyCo2: null == energyCo2 ? _self.energyCo2 : energyCo2 // ignore: cast_nullable_to_non_nullable
as double,totalDailyCo2: null == totalDailyCo2 ? _self.totalDailyCo2 : totalDailyCo2 // ignore: cast_nullable_to_non_nullable
as double,baselineCo2: null == baselineCo2 ? _self.baselineCo2 : baselineCo2 // ignore: cast_nullable_to_non_nullable
as double,co2SavedVsBaseline: null == co2SavedVsBaseline ? _self.co2SavedVsBaseline : co2SavedVsBaseline // ignore: cast_nullable_to_non_nullable
as double,percentVsBaseline: null == percentVsBaseline ? _self.percentVsBaseline : percentVsBaseline // ignore: cast_nullable_to_non_nullable
as double,xpEarned: null == xpEarned ? _self.xpEarned : xpEarned // ignore: cast_nullable_to_non_nullable
as int,emissionFactorVersion: null == emissionFactorVersion ? _self.emissionFactorVersion : emissionFactorVersion // ignore: cast_nullable_to_non_nullable
as String,syncStatus: null == syncStatus ? _self.syncStatus : syncStatus // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
