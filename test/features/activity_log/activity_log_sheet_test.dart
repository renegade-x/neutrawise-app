import 'package:flutter_test/flutter_test.dart';
import 'package:neutrawise/domain/models/daily_log.dart';
import 'package:neutrawise/domain/models/user_profile.dart';
import 'package:neutrawise/domain/co2_engine/co2_calculator.dart';

void main() {
  group('ActivityLogSheet Engine Integration Tests', () {
    final mockProfile = UserProfile(
      id: 'test-user-123',
      name: 'Eco User',
      transportFactor: 0.23,
      dailyEnergyBaselineKwh: 5.0,
      dailyEnergyBaselineCo2: 2.25,
      dailyHeatingBaselineCo2: 0.0,
      gridIntensity: 0.45,
      dailyFoodBaselineCo2: 5.5,
      totalDailyBaselineCo2: 12.35,
      currentStreak: 4,
      xp: 150,
      level: 2,
      hasSolar: false,
    );

    test('Process daily log with travel, food, and energy deviations', () {
      final transportEntries = [
        const TransportEntry(mode: 'car', distanceKm: 15.0),
        const TransportEntry(mode: 'bus', distanceKm: 10.0),
      ];

      final foodEntries = [
        const FoodEntry(
          mealSlot: 'Lunch',
          foodName: 'Chicken Salad',
          category: 'poultry_chicken',
          servingSize: 'medium',
          grams: 250.0,
        ),
      ];

      final energyDeviations = ['no_ac', 'cold_showers'];
      final energyConfirmed = true;

      final resultLog = CO2Calculator.processDailyLog(
        mockProfile,
        '2026-05-24',
        transportEntries,
        foodEntries,
        energyDeviations,
        energyConfirmed,
        mockProfile.currentStreak,
      );

      // Transport CO2:
      // Car (15km * 0.23) = 3.45 kg
      // Bus (10km * 0.089) = 0.89 kg
      // Total Transport = 4.34 kg
      expect(resultLog.transportCo2, closeTo(4.34, 0.01));

      // Food CO2:
      // Poultry Chicken (250g * 9.9 / 1000) = 2.475 kg
      expect(resultLog.foodCo2, closeTo(2.475, 0.01));

      // Energy CO2:
      // Baseline 5.0 kWh - 5.0 (no_ac) - 1.5 (cold_showers) = -1.5 kWh -> clamped to 0.0 kWh
      // 0.0 kWh * 0.45 = 0.0 kg
      expect(resultLog.energyCo2, 0.0);

      // Total Daily CO2: 4.34 + 2.475 + 0.0 = 6.815 kg
      expect(resultLog.totalDailyCo2, closeTo(6.815, 0.01));

      // Savings: 12.35 - 6.815 = 5.535 kg
      expect(resultLog.co2SavedVsBaseline, closeTo(5.535, 0.01));

      // XP: Log includes travel + food + energy (50 XP base * streak 1.25 multiplier = 62 XP + savings bonus)
      expect(resultLog.xpEarned, greaterThan(50));
    });

    test('Process partial daily log without energy confirmation', () {
      final transportEntries = [
        const TransportEntry(mode: 'metro', distanceKm: 20.0),
      ];

      final resultLog = CO2Calculator.processDailyLog(
        mockProfile,
        '2026-05-24',
        transportEntries,
        [],
        [],
        false, // unconfirmed energy
        0,
      );

      // Metro CO2: 20km * 0.035 = 0.70 kg
      expect(resultLog.transportCo2, closeTo(0.70, 0.01));
      expect(resultLog.foodCo2, 0.0);
      expect(resultLog.energyCo2, 0.0);
      expect(resultLog.totalDailyCo2, closeTo(0.70, 0.01));
    });
  });
}
