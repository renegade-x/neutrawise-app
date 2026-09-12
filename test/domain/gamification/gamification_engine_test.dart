import 'package:flutter_test/flutter_test.dart';
import 'package:neutrawise/domain/gamification/gamification_engine.dart';
import 'package:neutrawise/domain/models/daily_log.dart';

void main() {
  group('GamificationEngine Tests (Version 3.0 Spec)', () {
    group('Scenario 1: Daily Log XP & Multipliers', () {
      test('Full log, 0 streak, level 1, 0% savings -> 50 XP', () {
        const log = DailyLog(
          userId: 'u1',
          date: '2026-08-23',
          transportEntries: [TransportEntry(mode: 'bus', distanceKm: 10.0)],
          transportCo2: 1.0,
          foodEntries: [
            FoodEntry(
              foodName: 'Item',
              mealSlot: 'lunch',
              category: 'vegetables',
              servingSize: '1 portion',
              grams: 300,
            ),
          ],
          foodCo2: 0.5,
          energyDeviations: ['unplugged_devices'],
          energyCo2: 2.0,
          totalDailyCo2: 3.5,
          baselineCo2: 3.5,
          co2SavedVsBaseline: 0.0,
          percentVsBaseline: 0.0,
          xpEarned: 0,
        );

        final result = GamificationEngine.awardDailyXP(
          dailyResult: log,
          fullLogStreakDays: 0,
          level: 1,
          alreadyAwardedForDate: 0,
        );

        expect(result['isFullLog'], true);
        expect(result['baseXP'], 50);
        expect(result['streakMult'], 1.00);
        expect(result['levelMult'], 1.00);
        expect(result['preBonus'], 50);
        expect(result['perfBonus'], 0);
        expect(result['newTotal'], 50);
      });

      test(
        'Full log, 14 full log streak (x1.25), level 5 (x1.10), -20% savings (+15 XP) -> 105 XP',
        () {
          const log = DailyLog(
            userId: 'u1',
            date: '2026-08-23',
            transportEntries: [
              TransportEntry(mode: 'cycling', distanceKm: 5.0),
            ],
            transportCo2: 0.0,
            foodEntries: [
              FoodEntry(
                foodName: 'Tofu',
                mealSlot: 'lunch',
                category: 'tofu',
                servingSize: '1 portion',
                grams: 200,
              ),
            ],
            foodCo2: 0.2,
            energyDeviations: ['no_ac'],
            energyCo2: 1.0,
            totalDailyCo2: 1.2,
            baselineCo2: 1.5,
            co2SavedVsBaseline: 0.3,
            percentVsBaseline: -20.0,
            xpEarned: 0,
          );

          final result = GamificationEngine.awardDailyXP(
            dailyResult: log,
            fullLogStreakDays: 14,
            level: 5,
            alreadyAwardedForDate: 0,
          );

          expect(result['isFullLog'], true);
          expect(result['streakMult'], 1.25);
          expect(result['levelMult'], 1.10);
          expect(result['preBonus'], 69);
          expect(result['perfBonus'], 15);
          expect(result['newTotal'], 84);
        },
      );

      test(
        'Partial log (transport only) -> 20 XP base, no multipliers or perf bonus',
        () {
          const log = DailyLog(
            userId: 'u1',
            date: '2026-08-23',
            transportEntries: [TransportEntry(mode: 'bus', distanceKm: 10.0)],
            transportCo2: 1.0,
            foodEntries: [],
            foodCo2: 0.0,
            energyDeviations: [],
            energyCo2: 0.0,
            totalDailyCo2: 1.0,
            baselineCo2: 3.0,
            co2SavedVsBaseline: 2.0,
            percentVsBaseline: -66.6,
            xpEarned: 0,
          );

          final result = GamificationEngine.awardDailyXP(
            dailyResult: log,
            fullLogStreakDays: 30,
            level: 9,
            alreadyAwardedForDate: 0,
          );

          expect(result['isFullLog'], false);
          expect(result['baseXP'], 20);
          expect(result['streakMult'], 1.00);
          expect(result['levelMult'], 1.20);
          expect(result['preBonus'], 24);
          expect(result['perfBonus'], 0);
          expect(result['newTotal'], 24);
        },
      );

      test(
        'Delta update: log updated from partial (20 XP) to full (84 XP) -> delta 64 XP',
        () {
          const log = DailyLog(
            userId: 'u1',
            date: '2026-08-23',
            transportEntries: [
              TransportEntry(mode: 'cycling', distanceKm: 5.0),
            ],
            transportCo2: 0.0,
            foodEntries: [
              FoodEntry(
                foodName: 'Tofu',
                mealSlot: 'lunch',
                category: 'tofu',
                servingSize: '1 portion',
                grams: 200,
              ),
            ],
            foodCo2: 0.2,
            energyDeviations: ['no_ac'],
            energyCo2: 1.0,
            totalDailyCo2: 1.2,
            baselineCo2: 1.5,
            co2SavedVsBaseline: 0.3,
            percentVsBaseline: -20.0,
            xpEarned: 0,
          );

          final result = GamificationEngine.awardDailyXP(
            dailyResult: log,
            fullLogStreakDays: 14,
            level: 5,
            alreadyAwardedForDate: 20,
          );

          expect(result['newTotal'], 84);
          expect(result['deltaXP'], 64);
        },
      );
    });

    group('Scenario 2: Level Progression & Capability Gating', () {
      test('getLevelFromXp exact thresholds', () {
        expect(GamificationEngine.getLevelFromXp(0), 1);
        expect(GamificationEngine.getLevelFromXp(499), 1);
        expect(GamificationEngine.getLevelFromXp(500), 2);
        expect(GamificationEngine.getLevelFromXp(1500), 3);
        expect(GamificationEngine.getLevelFromXp(3000), 4);
        expect(GamificationEngine.getLevelFromXp(5000), 5);
        expect(GamificationEngine.getLevelFromXp(8000), 6);
        expect(GamificationEngine.getLevelFromXp(12000), 7);
        expect(GamificationEngine.getLevelFromXp(17000), 8);
        expect(GamificationEngine.getLevelFromXp(23000), 9);
        expect(GamificationEngine.getLevelFromXp(31000), 10);
      });

      test('Challenge slots per level', () {
        expect(GamificationEngine.getChallengeSlotsForLevel(1), 1);
        expect(GamificationEngine.getChallengeSlotsForLevel(3), 1);
        expect(GamificationEngine.getChallengeSlotsForLevel(4), 2);
        expect(GamificationEngine.getChallengeSlotsForLevel(5), 2);
        expect(GamificationEngine.getChallengeSlotsForLevel(6), 3);
        expect(GamificationEngine.getChallengeSlotsForLevel(8), 3);
        expect(GamificationEngine.getChallengeSlotsForLevel(9), 4);
        expect(GamificationEngine.getChallengeSlotsForLevel(10), 4);
      });

      test('Gating helpers (Hard challenges, Quiz bonus, Streak Freeze)', () {
        expect(GamificationEngine.areHardChallengesUnlocked(5), false);
        expect(GamificationEngine.areHardChallengesUnlocked(6), true);

        expect(GamificationEngine.isQuizPerfectBonusUnlocked(4), false);
        expect(GamificationEngine.isQuizPerfectBonusUnlocked(5), true);

        expect(GamificationEngine.isStreakFreezeUnlocked(3), false);
        expect(GamificationEngine.isStreakFreezeUnlocked(4), true);
      });
    });

    group('Scenario 3: Challenge Strategy & Decay / Cooldown', () {
      test('LOG_FIELD_ZERO strategy (No Car Day)', () {
        const carLog = DailyLog(
          userId: 'u1',
          date: '2026-08-23',
          transportEntries: [TransportEntry(mode: 'car', distanceKm: 15.0)],
          transportCo2: 3.5,
          foodEntries: [],
          foodCo2: 0.0,
          energyDeviations: [],
          energyCo2: 0.0,
          totalDailyCo2: 3.5,
          baselineCo2: 3.5,
          co2SavedVsBaseline: 0.0,
          percentVsBaseline: 0.0,
          xpEarned: 0,
        );

        const noCarLog = DailyLog(
          userId: 'u1',
          date: '2026-08-23',
          transportEntries: [TransportEntry(mode: 'bus', distanceKm: 15.0)],
          transportCo2: 0.8,
          foodEntries: [],
          foodCo2: 0.0,
          energyDeviations: [],
          energyCo2: 0.0,
          totalDailyCo2: 0.8,
          baselineCo2: 3.5,
          co2SavedVsBaseline: 2.7,
          percentVsBaseline: -77.0,
          xpEarned: 0,
        );

        final passedWithCar = GamificationEngine.evaluateStrategy(
          strategy: 'LOG_FIELD_ZERO',
          params: {'field': 'car_km'},
          dailyResult: carLog,
        );
        expect(passedWithCar, false);

        final passedNoCar = GamificationEngine.evaluateStrategy(
          strategy: 'LOG_FIELD_ZERO',
          params: {'field': 'car_km'},
          dailyResult: noCarLog,
        );
        expect(passedNoCar, true);
      });

      test('Challenge XP Decay on repeat completions', () {
        expect(
          GamificationEngine.calculateChallengeXpReward(
            baseXP: 200,
            completionNumber: 1,
          ),
          200,
        );
        expect(
          GamificationEngine.calculateChallengeXpReward(
            baseXP: 200,
            completionNumber: 2,
          ),
          180,
        );
        expect(
          GamificationEngine.calculateChallengeXpReward(
            baseXP: 200,
            completionNumber: 3,
          ),
          160,
        );
        expect(
          GamificationEngine.calculateChallengeXpReward(
            baseXP: 200,
            completionNumber: 6,
          ),
          100,
        );
      });

      test('Challenge Cooldown growth on repeat completions', () {
        expect(
          GamificationEngine.calculateCooldownDays(
            difficulty: 'Medium',
            durationType: 'multi_day',
            completionNumber: 1,
          ),
          30,
        );
        expect(
          GamificationEngine.calculateCooldownDays(
            difficulty: 'Medium',
            durationType: 'multi_day',
            completionNumber: 2,
          ),
          45,
        );
        expect(
          GamificationEngine.calculateCooldownDays(
            difficulty: 'Medium',
            durationType: 'multi_day',
            completionNumber: 5,
          ),
          90,
        );
      });

      test('Challenge XP Decay floor at 50% minimum', () {
        // 50% floor on 200 base XP is 100 XP
        expect(
          GamificationEngine.calculateChallengeXpReward(
            baseXP: 200,
            completionNumber: 10,
          ),
          100,
        );
        expect(
          GamificationEngine.calculateChallengeXpReward(
            baseXP: 200,
            completionNumber: 100,
          ),
          100,
        );
      });

      test('Challenge Cooldown max cap at 3.0x base multiplier', () {
        // Hard base = 90 days * 3.0 max mult = 270 days
        expect(
          GamificationEngine.calculateCooldownDays(
            difficulty: 'Hard',
            durationType: 'multi_day',
            completionNumber: 10,
          ),
          270,
        );
      });
    });

    group('Scenario 4: Performance Bonus Tiering (Positive & Negative)', () {
      test('Savings < 5% -> 0 bonus (Negative)', () {
        const log = DailyLog(
          userId: 'u1',
          date: '2026-08-23',
          transportEntries: [TransportEntry(mode: 'bus', distanceKm: 5)],
          foodEntries: [
            FoodEntry(
              foodName: 'Rice',
              mealSlot: 'lunch',
              category: 'grains',
              servingSize: '1 portion',
              grams: 200,
            ),
          ],
          energyDeviations: ['no_ac'],
          energyConfirmed: true,
          totalDailyCo2: 1.95,
          baselineCo2: 2.0,
          percentVsBaseline: -2.5,
        );

        final result = GamificationEngine.awardDailyXP(
          dailyResult: log,
          fullLogStreakDays: 0,
          level: 1,
          alreadyAwardedForDate: 0,
        );
        expect(result['perfBonus'], 0);
      });

      test('Savings 5-14.9% -> 8 bonus (Positive)', () {
        const log = DailyLog(
          userId: 'u1',
          date: '2026-08-23',
          transportEntries: [TransportEntry(mode: 'bus', distanceKm: 5)],
          foodEntries: [
            FoodEntry(
              foodName: 'Rice',
              mealSlot: 'lunch',
              category: 'grains',
              servingSize: '1 portion',
              grams: 200,
            ),
          ],
          energyDeviations: ['no_ac'],
          energyConfirmed: true,
          totalDailyCo2: 1.8,
          baselineCo2: 2.0,
          percentVsBaseline: -10.0,
        );

        final result = GamificationEngine.awardDailyXP(
          dailyResult: log,
          fullLogStreakDays: 0,
          level: 1,
          alreadyAwardedForDate: 0,
        );
        expect(result['perfBonus'], 8);
      });

      test('Savings 15-29.9% -> 15 bonus (Positive)', () {
        const log = DailyLog(
          userId: 'u1',
          date: '2026-08-23',
          transportEntries: [TransportEntry(mode: 'bus', distanceKm: 5)],
          foodEntries: [
            FoodEntry(
              foodName: 'Rice',
              mealSlot: 'lunch',
              category: 'grains',
              servingSize: '1 portion',
              grams: 200,
            ),
          ],
          energyDeviations: ['no_ac'],
          energyConfirmed: true,
          totalDailyCo2: 1.6,
          baselineCo2: 2.0,
          percentVsBaseline: -20.0,
        );

        final result = GamificationEngine.awardDailyXP(
          dailyResult: log,
          fullLogStreakDays: 0,
          level: 1,
          alreadyAwardedForDate: 0,
        );
        expect(result['perfBonus'], 15);
      });

      test('Savings >= 30% -> 25 bonus (Positive)', () {
        const log = DailyLog(
          userId: 'u1',
          date: '2026-08-23',
          transportEntries: [TransportEntry(mode: 'bus', distanceKm: 5)],
          foodEntries: [
            FoodEntry(
              foodName: 'Rice',
              mealSlot: 'lunch',
              category: 'grains',
              servingSize: '1 portion',
              grams: 200,
            ),
          ],
          energyDeviations: ['no_ac'],
          energyConfirmed: true,
          totalDailyCo2: 1.2,
          baselineCo2: 2.0,
          percentVsBaseline: -40.0,
        );

        final result = GamificationEngine.awardDailyXP(
          dailyResult: log,
          fullLogStreakDays: 0,
          level: 1,
          alreadyAwardedForDate: 0,
        );
        expect(result['perfBonus'], 25);
      });

      test(
        'Unconfirmed energy log -> Partial log (20 XP base) even with food/transport (Negative)',
        () {
          const log = DailyLog(
            userId: 'u1',
            date: '2026-08-23',
            transportEntries: [TransportEntry(mode: 'bus', distanceKm: 5)],
            foodEntries: [
              FoodEntry(
                foodName: 'Rice',
                mealSlot: 'lunch',
                category: 'grains',
                servingSize: '1 portion',
                grams: 200,
              ),
            ],
            energyDeviations: [],
            energyConfirmed: false,
            energyCo2: 0.0,
            totalDailyCo2: 1.0,
            baselineCo2: 2.0,
            percentVsBaseline: -50.0,
          );

          final result = GamificationEngine.awardDailyXP(
            dailyResult: log,
            fullLogStreakDays: 10,
            level: 5,
            alreadyAwardedForDate: 0,
          );
          expect(result['isFullLog'], false);
          expect(result['baseXP'], 20);
          expect(result['perfBonus'], 0);
        },
      );
    });

    group('Scenario 5: Strategy Evaluator Edge Cases (Positive & Negative)', () {
      test(
        'LOG_FIELD_ZERO fails for EV, motorcycle, taxi, rideshare (Negative)',
        () {
          const evLog = DailyLog(
            userId: 'u1',
            date: '2026-08-23',
            transportEntries: [TransportEntry(mode: 'ev', distanceKm: 12.0)],
            energyConfirmed: true,
          );

          const taxiLog = DailyLog(
            userId: 'u1',
            date: '2026-08-23',
            transportEntries: [TransportEntry(mode: 'taxi', distanceKm: 5.0)],
            energyConfirmed: true,
          );

          expect(
            GamificationEngine.evaluateStrategy(
              strategy: 'LOG_FIELD_ZERO',
              params: {'field': 'car_km'},
              dailyResult: evLog,
            ),
            false,
          );
          expect(
            GamificationEngine.evaluateStrategy(
              strategy: 'LOG_FIELD_ZERO',
              params: {'field': 'car_km'},
              dailyResult: taxiLog,
            ),
            false,
          );
        },
      );

      test(
        'LOG_TAG_PRESENT matches case-insensitive aliases cold_shower vs cold_showers (Positive & Negative)',
        () {
          const presentLog = DailyLog(
            userId: 'u1',
            date: '2026-08-23',
            energyDeviations: ['Cold_Showers'],
            energyConfirmed: true,
          );

          const absentLog = DailyLog(
            userId: 'u1',
            date: '2026-08-23',
            energyDeviations: ['unplugged_devices'],
            energyConfirmed: true,
          );

          expect(
            GamificationEngine.evaluateStrategy(
              strategy: 'LOG_TAG_PRESENT',
              params: {'tag': 'cold_shower'},
              dailyResult: presentLog,
            ),
            true,
          );
          expect(
            GamificationEngine.evaluateStrategy(
              strategy: 'LOG_TAG_PRESENT',
              params: {'tag': 'cold_shower'},
              dailyResult: absentLog,
            ),
            false,
          );
        },
      );

      test(
        'LOG_TAG_ABSENT passes when tag absent, fails when tag present (Positive & Negative)',
        () {
          const logWithAc = DailyLog(
            userId: 'u1',
            date: '2026-08-23',
            energyDeviations: ['ac_used'],
            energyConfirmed: true,
          );

          const logWithoutAc = DailyLog(
            userId: 'u1',
            date: '2026-08-23',
            energyDeviations: ['cold_shower'],
            energyConfirmed: true,
          );

          expect(
            GamificationEngine.evaluateStrategy(
              strategy: 'LOG_TAG_ABSENT',
              params: {'tag': 'ac_used'},
              dailyResult: logWithAc,
            ),
            false,
          );
          expect(
            GamificationEngine.evaluateStrategy(
              strategy: 'LOG_TAG_ABSENT',
              params: {'tag': 'ac_used'},
              dailyResult: logWithoutAc,
            ),
            true,
          );
        },
      );
    });
  });
}
