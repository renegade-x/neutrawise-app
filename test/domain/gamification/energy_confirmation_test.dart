import 'package:flutter_test/flutter_test.dart';
import 'package:neutrawise/domain/gamification/gamification_engine.dart';
import 'package:neutrawise/domain/models/daily_log.dart';

DailyLog _log({
  bool confirmed = false,
  List<String> deviations = const [],
  double energyCo2 = 2.25,
  bool withTransport = true,
  bool withFood = true,
}) {
  return DailyLog(
    userId: 'u1',
    date: '2026-10-03',
    transportEntries: withTransport
        ? const [TransportEntry(mode: 'bus', distanceKm: 5.0)]
        : const [],
    transportCo2: withTransport ? 0.45 : 0.0,
    foodEntries: withFood
        ? const [
            FoodEntry(
              foodName: 'Lentils',
              mealSlot: 'lunch',
              category: 'legumes',
              servingSize: 'medium',
              grams: 250,
            ),
          ]
        : const [],
    foodCo2: withFood ? 0.3 : 0.0,
    energyDeviations: deviations,
    energyCo2: energyCo2,
    energyConfirmed: confirmed,
    totalDailyCo2: 3.0,
    baselineCo2: 5.0,
    co2SavedVsBaseline: 2.0,
    percentVsBaseline: -40.0,
    xpEarned: 0,
  );
}

void main() {
  group('Energy confirmation is independent of baseline energy CO2', () {
    test('baseline energy CO2 alone does not count as confirmed', () {
      final log = _log();
      expect(GamificationEngine.isEnergyConfirmed(log), isFalse);
      expect(GamificationEngine.isFullLog(log), isFalse);
    });

    test('explicit confirmation counts', () {
      expect(
        GamificationEngine.isEnergyConfirmed(_log(confirmed: true)),
        isTrue,
      );
      expect(GamificationEngine.isFullLog(_log(confirmed: true)), isTrue);
    });

    test('a selected deviation counts', () {
      final log = _log(deviations: const ['no_ac']);
      expect(GamificationEngine.isEnergyConfirmed(log), isTrue);
    });

    test('transport + food without energy confirmation earns partial XP', () {
      final result = GamificationEngine.awardDailyXP(
        dailyResult: _log(),
        fullLogStreakDays: 0,
        level: 1,
        alreadyAwardedForDate: 0,
      );
      expect(result['isFullLog'], isFalse);
      expect(result['newTotal'], 20);
    });
  });
}
