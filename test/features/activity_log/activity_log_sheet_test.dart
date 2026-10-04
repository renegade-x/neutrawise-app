import 'package:flutter_test/flutter_test.dart';
import 'package:neutrawise/domain/models/daily_log.dart';
import 'package:neutrawise/domain/models/user_profile.dart';
import 'package:neutrawise/domain/co2_engine/co2_calculator.dart';

void main() {
  transportModeTests();

  group('ActivityLogSheet Engine Integration Tests', () {
    final mockProfile = const UserProfile(
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
      // Unconfirmed energy still counts the typical-day baseline:
      // 5.0 kWh * 0.45 = 2.25 kg
      expect(resultLog.energyCo2, closeTo(2.25, 0.01));
      expect(resultLog.totalDailyCo2, closeTo(2.95, 0.01));
    });

    test(
      'Process Pakistani food entries with un-normalized categories like grains, legumes, poultry',
      () {
        final foodEntries = [
          const FoodEntry(
            mealSlot: 'Breakfast',
            foodName: 'Aloo Paratha',
            category: 'grains',
            servingSize: 'medium',
            grams: 200.0,
          ),
          const FoodEntry(
            mealSlot: 'Lunch',
            foodName: 'Daal Chawal',
            category: 'legumes',
            servingSize: 'medium',
            grams: 300.0,
            co2Per100g: 0.6,
          ),
          const FoodEntry(
            mealSlot: 'Dinner',
            foodName: 'Chicken Biryani',
            category: 'poultry_chicken',
            servingSize: 'medium',
            grams: 350.0,
            co2Per100g: 1.8,
          ),
        ];

        final resultLog = CO2Calculator.processDailyLog(
          mockProfile,
          '2026-05-24',
          [],
          foodEntries,
          [],
          false,
          0,
        );

        // Aloo Paratha: (200g * 1.6 / 1000) = 0.32 kg
        // Daal Chawal: (300g * 0.6 / 1000) = 0.18 kg
        // Chicken Biryani: (350g * 1.8 / 1000) = 0.63 kg
        // Total Food CO2 = 0.32 + 0.18 + 0.63 = 1.13 kg
        expect(resultLog.foodEntries[0].calculatedCo2, closeTo(0.32, 0.01));
        expect(resultLog.foodEntries[1].calculatedCo2, closeTo(0.18, 0.01));
        expect(resultLog.foodEntries[2].calculatedCo2, closeTo(0.63, 0.01));
        expect(resultLog.foodCo2, closeTo(1.13, 0.01));
      },
    );
  });
}

void transportModeTests() {
  group('Transport factor follows the logged mode', () {
    const busCommuter = UserProfile(
      id: 'u-bus',
      name: 'Bus Commuter',
      primaryTransport: 'bus',
      transportFactor: 0.089,
      dailyEnergyBaselineKwh: 5.0,
      dailyHeatingBaselineCo2: 0.0,
      gridIntensity: 0.45,
      totalDailyBaselineCo2: 8.0,
    );
    const carOwner = UserProfile(
      id: 'u-car',
      name: 'Car Owner',
      primaryTransport: 'car',
      transportFactor: 0.30,
      dailyEnergyBaselineKwh: 5.0,
      dailyHeatingBaselineCo2: 0.0,
      gridIntensity: 0.45,
      totalDailyBaselineCo2: 12.0,
    );

    DailyLog log(UserProfile p, String mode) => CO2Calculator.processDailyLog(
      p,
      '2026-05-24',
      [TransportEntry(mode: mode, distanceKm: 10.0)],
      [],
      [],
      false,
      0,
    );

    test('bus commuter logging a car trip is not given the bus factor', () {
      // Default medium petrol car: 0.23 kg/km
      expect(log(busCommuter, 'car').transportCo2, closeTo(2.3, 0.01));
    });

    test('car owner logging a car trip uses the registered vehicle factor', () {
      expect(log(carOwner, 'car').transportCo2, closeTo(3.0, 0.01));
    });

    test('car owner taking a bus uses the bus factor', () {
      expect(log(carOwner, 'bus').transportCo2, closeTo(0.89, 0.01));
    });

    test('bus commuter logging an EV trip uses the grid-based EV default', () {
      // 0.18 kWh/km * 0.45 kg/kWh * 10 km = 0.81 kg
      expect(log(busCommuter, 'ev').transportCo2, closeTo(0.81, 0.01));
    });
  });
}
