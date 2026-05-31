import 'emission_factors.dart';
import '../models/sign_up_profile_input.dart';

class CO2Calculator {
  static Map<String, dynamic> processSignUpProfile(SignUpProfileInput input) {
    // 1. Transport Factor
    double transportFactor = 0.0;
    
    if (input.primaryTransport == 'car') {
      final key = 'car_${input.fuelType}_${input.engineSize}';
      final baseFactor = EmissionFactors.baseTransportFactors[key] ?? 0.23;
      final ageMultiplier = EmissionFactors.vehicleAgeMultipliers[input.vehicleAge] ?? 1.0;
      transportFactor = baseFactor * ageMultiplier;
    } else if (input.primaryTransport == 'ev') {
      transportFactor = EmissionFactors.baseTransportFactors['ev_efficiency']! * EmissionFactors.gridIntensityPK;
    } else {
      transportFactor = EmissionFactors.baseTransportFactors[input.primaryTransport] ?? 0.0;
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
    final dailyFoodCo2 = EmissionFactors.dietaryFactors[input.dietaryPreference] ?? 5.5;

    final totalDailyBaseline = dailyTransportCo2 + dailyEnergyCo2 + dailyHeatingCo2 + dailyFoodCo2;

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
}
