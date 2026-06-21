import 'emission_factors.dart';
import '../models/sign_up_profile_input.dart';
import '../models/user_profile.dart';
import '../models/daily_log.dart';

class CO2Calculator {
  static Map<String, dynamic> processSignUpProfile(SignUpProfileInput input) {
    // 1. Transport Factor
    double transportFactor = 0.0;

    if (input.primaryTransport == 'car') {
      final key = 'car_${input.fuelType}_${input.engineSize}';
      final baseFactor = EmissionFactors.baseTransportFactors[key] ?? 0.23;
      final ageMultiplier =
          EmissionFactors.vehicleAgeMultipliers[input.vehicleAge] ?? 1.0;
      transportFactor = baseFactor * ageMultiplier;
    } else if (input.primaryTransport == 'ev') {
      transportFactor =
          EmissionFactors.baseTransportFactors['ev_efficiency']! *
          EmissionFactors.gridIntensityPK;
    } else {
      transportFactor =
          EmissionFactors.baseTransportFactors[input.primaryTransport] ?? 0.0;
    }

    final dailyTransportCo2 = transportFactor * (input.avgDailyKm ?? 0);

    // 2. Energy Factor
    double adjustedKwh = input.monthlyKwh;
    if (input.hasSolar) {
      adjustedKwh = adjustedKwh * 0.75; // 25% reduction estimate for solar
    }

    final dailyKwh = (adjustedKwh / 30) / input.residents;
    final dailyEnergyCo2 = dailyKwh * EmissionFactors.gridIntensityPK;

    // Heating
    double dailyHeatingCo2 = 0.0;
    if (input.heatingType == 'natural_gas') {
      dailyHeatingCo2 = 1.5; // Simplified baseline for gas
    }

    // 3. Food Factor
    final dailyFoodCo2 =
        EmissionFactors.dietaryFactors[input.dietaryPreference] ?? 5.5;

    final totalDailyBaseline =
        dailyTransportCo2 + dailyEnergyCo2 + dailyHeatingCo2 + dailyFoodCo2;

    return {
      'transport_factor': transportFactor,
      'daily_transport_co2': dailyTransportCo2,
      'daily_energy_baseline_kwh': dailyKwh,
      'daily_energy_baseline_co2': dailyEnergyCo2,
      'daily_heating_baseline_co2': dailyHeatingCo2,
      'daily_food_baseline_co2': dailyFoodCo2,
      'total_daily_baseline_co2': totalDailyBaseline,
    };
  }

  static DailyLog processDailyLog(
    UserProfile profile,
    String date,
    List<TransportEntry> transportEntries,
    List<FoodEntry> foodEntries,
    List<String> energyDeviations,
    bool energyConfirmed,
    int streakDays,
  ) {
    // 1. Calculate Transport CO2
    double totalTransportCo2 = 0.0;
    List<TransportEntry> processedTransport = [];
    for (var entry in transportEntries) {
      double factor = 0.0;
      if (entry.mode == 'car' ||
          entry.mode == 'ev' ||
          entry.mode == 'motorcycle') {
        factor = profile.transportFactor ?? 0.0;
      } else {
        factor = EmissionFactors.baseTransportFactors[entry.mode] ?? 0.0;
      }
      final co2 = factor * entry.distanceKm;
      processedTransport.add(entry.copyWith(calculatedCo2: co2));
      totalTransportCo2 += co2;
    }

    // 2. Calculate Food CO2
    double totalFoodCo2 = 0.0;
    List<FoodEntry> processedFood = [];
    for (var entry in foodEntries) {
      double itemCo2 = 0.0;
      if (entry.co2Per100g != null && entry.co2Per100g! > 0) {
        itemCo2 = (entry.co2Per100g! / 1000.0) * (entry.grams / 100.0);
      } else {
        final factorKgPerKg =
            EmissionFactors.foodCategoryFactors[entry.category] ?? 0.4;
        itemCo2 = factorKgPerKg * (entry.grams / 1000.0);
      }
      processedFood.add(entry.copyWith(calculatedCo2: itemCo2));
      totalFoodCo2 += itemCo2;
    }

    // 3. Calculate Energy CO2
    double totalEnergyCo2 = 0.0;
    if (energyConfirmed) {
      double deltaKwh = 0.0;
      for (var deviation in energyDeviations) {
        if (deviation == 'more_than_usual')
          deltaKwh += 2.0;
        else if (deviation == 'less_than_usual')
          deltaKwh -= 2.0;
        else if (deviation == 'no_ac')
          deltaKwh -= 5.0;
        else if (deviation == 'cold_showers')
          deltaKwh -= 1.5;
        else if (deviation == 'unplugged_devices')
          deltaKwh -= 0.5;
        else if (deviation == 'solar_panels_sunny')
          deltaKwh -= 4.0;
        else if (deviation == 'solar_panels_cloudy')
          deltaKwh -= 1.5;
      }

      final dailyBaselineKwh = profile.dailyEnergyBaselineKwh ?? 0.0;
      double totalKwh = dailyBaselineKwh + deltaKwh;
      if (totalKwh < 0) totalKwh = 0.0;

      final gridIntensity =
          profile.gridIntensity ?? EmissionFactors.gridIntensityPK;
      final electricityCO2 = totalKwh * gridIntensity;

      totalEnergyCo2 =
          electricityCO2 + (profile.dailyHeatingBaselineCo2 ?? 0.0);
    }

    // 4. Totals and baseline
    final baselineCo2 = profile.totalDailyBaselineCo2 ?? 0.0;
    final totalDailyCo2 = totalTransportCo2 + totalFoodCo2 + totalEnergyCo2;
    final saved = baselineCo2 - totalDailyCo2;
    final percent = baselineCo2 > 0 ? (saved / baselineCo2) * 100 : 0.0;

    // 5. XP Calculation
    int baseXP = 0;
    if (energyConfirmed &&
        transportEntries.isNotEmpty &&
        foodEntries.isNotEmpty) {
      baseXP = 50;
    } else if (transportEntries.isNotEmpty ||
        foodEntries.isNotEmpty ||
        energyConfirmed) {
      baseXP = 20;
    }

    double streakMultiplier = 1.0;
    if (streakDays >= 30)
      streakMultiplier = 1.5;
    else if (streakDays >= 7)
      streakMultiplier = 1.25;

    int xpEarned = (baseXP * streakMultiplier).round();

    if (xpEarned > 0) {
      if (percent >= 30)
        xpEarned += 25;
      else if (percent >= 15)
        xpEarned += 15;
      else if (percent >= 5)
        xpEarned += 8;
    }

    return DailyLog(
      userId: profile.id,
      date: date,
      transportEntries: processedTransport,
      transportCo2: totalTransportCo2,
      foodEntries: processedFood,
      foodCo2: totalFoodCo2,
      energyDeviations: energyDeviations,
      energyCo2: totalEnergyCo2,
      totalDailyCo2: totalDailyCo2,
      baselineCo2: baselineCo2,
      co2SavedVsBaseline: saved,
      percentVsBaseline: percent,
      xpEarned: xpEarned,
      emissionFactorVersion: '1.0',
      syncStatus: 'pending',
    );
  }
}
