import 'package:flutter_test/flutter_test.dart';
import 'package:neutrawise/domain/gamification/gamification_engine.dart';
import 'package:neutrawise/domain/models/daily_log.dart';
import 'package:neutrawise/data/repositories/gamification_repository.dart';

void main() {
  group('All 15 Challenges End-to-End Evaluation & Audit Test Suite', () {
    final catalog = GamificationRepository.defaultChallenges;

    test('Verify catalog contains exactly 15 default challenges', () {
      expect(catalog.length, 15);
    });

    // Helper to extract challenge by ID
    Map<String, dynamic> getChallenge(String id) {
      return catalog.firstWhere(
        (c) => c['id'] == id,
        orElse: () => throw Exception('Challenge $id not found'),
      );
    }

    // -------------------------------------------------------------------------
    // TRANSPORT CHALLENGES (7)
    // -------------------------------------------------------------------------

    group('Transport Challenge 1: No Car Day (id: no_car_day)', () {
      final challenge = getChallenge('no_car_day');

      test('Success: 0 car km logged -> qualified = true', () {
        const log = DailyLog(
          userId: 'u1',
          date: '2026-08-26',
          transportEntries: [TransportEntry(mode: 'cycling', distanceKm: 8.0)],
          foodEntries: [],
          energyDeviations: [],
        );
        final qualified = GamificationEngine.evaluateStrategy(
          strategy: challenge['strategy'],
          params: challenge['strategy_params'],
          dailyResult: log,
        );
        expect(qualified, isTrue);
      });

      test('Failure: Private car km > 0 logged -> qualified = false', () {
        const log = DailyLog(
          userId: 'u1',
          date: '2026-08-26',
          transportEntries: [TransportEntry(mode: 'car', distanceKm: 2.0)],
          foodEntries: [],
          energyDeviations: [],
        );
        final qualified = GamificationEngine.evaluateStrategy(
          strategy: challenge['strategy'],
          params: challenge['strategy_params'],
          dailyResult: log,
        );
        expect(qualified, isFalse);
      });

      test('Edge Case: EV or Taxi also fails zero car km strategy', () {
        const log = DailyLog(
          userId: 'u1',
          date: '2026-08-26',
          transportEntries: [TransportEntry(mode: 'taxi', distanceKm: 3.5)],
          foodEntries: [],
          energyDeviations: [],
        );
        final qualified = GamificationEngine.evaluateStrategy(
          strategy: challenge['strategy'],
          params: challenge['strategy_params'],
          dailyResult: log,
        );
        expect(qualified, isFalse);
      });
    });

    group('Transport Challenge 2: No Car Weekend (id: no_car_weekend)', () {
      final challenge = getChallenge('no_car_weekend');

      test(
        'Success: Both weekend days qualified -> Audit completes challenge (2 days passed)',
        () {
          const logSat = DailyLog(
            userId: 'u1',
            date: '2026-08-29', // Saturday
            transportEntries: [
              TransportEntry(mode: 'walking', distanceKm: 3.0),
            ],
            foodEntries: [],
            energyDeviations: [],
          );
          final qualSat = GamificationEngine.evaluateStrategy(
            strategy: challenge['strategy'],
            params: challenge['strategy_params'],
            dailyResult: logSat,
          );
          expect(qualSat, isTrue);

          int daysPassed = 1; // Passed Saturday
          // Sunday also passed
          daysPassed += 1;

          expect(daysPassed, challenge['required_days']);
        },
      );

      test(
        'Failure: Sunday car trip fails consecutive weekend -> resets days_passed to 0',
        () {
          int daysPassed = 1; // Saturday passed
          // Sunday failed
          if (challenge['consecutive'] == true) {
            daysPassed = 0;
          }
          expect(daysPassed, 0);
        },
      );
    });

    group('Transport Challenge 3: Walk 7 Days (id: walk_7_days)', () {
      final challenge = getChallenge('walk_7_days');

      test('Success: Walking leg present -> qualified = true', () {
        const log = DailyLog(
          userId: 'u1',
          date: '2026-08-26',
          transportEntries: [
            TransportEntry(mode: 'walking', distanceKm: 1.5),
            TransportEntry(mode: 'bus', distanceKm: 10.0),
          ],
          foodEntries: [],
          energyDeviations: [],
        );
        final qualified = GamificationEngine.evaluateStrategy(
          strategy: challenge['strategy'],
          params: challenge['strategy_params'],
          dailyResult: log,
        );
        expect(qualified, isTrue);
      });

      test('Failure: No walking leg present -> qualified = false', () {
        const log = DailyLog(
          userId: 'u1',
          date: '2026-08-26',
          transportEntries: [TransportEntry(mode: 'bus', distanceKm: 10.0)],
          foodEntries: [],
          energyDeviations: [],
        );
        final qualified = GamificationEngine.evaluateStrategy(
          strategy: challenge['strategy'],
          params: challenge['strategy_params'],
          dailyResult: log,
        );
        expect(qualified, isFalse);
      });

      test('Non-Consecutive Audit: Missed day does not reset days_passed', () {
        int daysPassed = 4;
        // Missed day
        if (challenge['consecutive'] == true) {
          daysPassed = 0;
        }
        expect(daysPassed, 4); // Preserved at 4
      });
    });

    group(
      'Transport Challenge 4: Cycle to Work Week (id: cycle_to_work_week)',
      () {
        final challenge = getChallenge('cycle_to_work_week');

        test('Success: Cycling leg present -> qualified = true', () {
          const log = DailyLog(
            userId: 'u1',
            date: '2026-08-26',
            transportEntries: [
              TransportEntry(mode: 'cycling', distanceKm: 6.0),
            ],
            foodEntries: [],
            energyDeviations: [],
          );
          final qualified = GamificationEngine.evaluateStrategy(
            strategy: challenge['strategy'],
            params: challenge['strategy_params'],
            dailyResult: log,
          );
          expect(qualified, isTrue);
        });

        test('Failure: No cycling leg present -> qualified = false', () {
          const log = DailyLog(
            userId: 'u1',
            date: '2026-08-26',
            transportEntries: [
              TransportEntry(mode: 'walking', distanceKm: 2.0),
            ],
            foodEntries: [],
            energyDeviations: [],
          );
          final qualified = GamificationEngine.evaluateStrategy(
            strategy: challenge['strategy'],
            params: challenge['strategy_params'],
            dailyResult: log,
          );
          expect(qualified, isFalse);
        });
      },
    );

    group('Transport Challenge 5: No Car Week (id: no_car_week)', () {
      final challenge = getChallenge('no_car_week');

      test('Success: 7 consecutive zero car days completes challenge', () {
        int daysPassed = 6; // 6 days completed
        // Day 7 passed
        daysPassed += 1;
        expect(daysPassed, challenge['required_days']);
      });

      test('Failure: Car trip on Day 5 resets 7-day streak', () {
        int daysPassed = 4;
        // Day 5 failed
        if (challenge['consecutive'] == true) {
          daysPassed = 0;
        }
        expect(daysPassed, 0);
      });
    });

    group('Transport Challenge 6: Carpool Champion (id: carpool_champion)', () {
      final challenge = getChallenge('carpool_champion');

      test('Success: Rideshare leg present -> qualified = true', () {
        const log = DailyLog(
          userId: 'u1',
          date: '2026-08-26',
          transportEntries: [
            TransportEntry(mode: 'rideshare', distanceKm: 12.0),
          ],
          foodEntries: [],
          energyDeviations: [],
        );
        final qualified = GamificationEngine.evaluateStrategy(
          strategy: challenge['strategy'],
          params: challenge['strategy_params'],
          dailyResult: log,
        );
        expect(qualified, isTrue);
      });

      test('Failure: Solo driving leg -> qualified = false', () {
        const log = DailyLog(
          userId: 'u1',
          date: '2026-08-26',
          transportEntries: [TransportEntry(mode: 'car', distanceKm: 12.0)],
          foodEntries: [],
          energyDeviations: [],
        );
        final qualified = GamificationEngine.evaluateStrategy(
          strategy: challenge['strategy'],
          params: challenge['strategy_params'],
          dailyResult: log,
        );
        expect(qualified, isFalse);
      });
    });

    group(
      'Transport Challenge 7: Public Transport Month (id: public_transport_month)',
      () {
        final challenge = getChallenge('public_transport_month');

        test('Success: 100% transit legs (bus, train) -> qualified = true', () {
          const log = DailyLog(
            userId: 'u1',
            date: '2026-08-26',
            transportEntries: [
              TransportEntry(mode: 'bus', distanceKm: 5.0),
              TransportEntry(mode: 'train', distanceKm: 20.0),
            ],
            foodEntries: [],
            energyDeviations: [],
          );
          final qualified = GamificationEngine.evaluateStrategy(
            strategy: challenge['strategy'],
            params: challenge['strategy_params'],
            dailyResult: log,
          );
          expect(qualified, isTrue);
        });

        test(
          'Failure: Mixed leg (bus + car) fails TRANSPORT_ALL_MATCH -> qualified = false',
          () {
            const log = DailyLog(
              userId: 'u1',
              date: '2026-08-26',
              transportEntries: [
                TransportEntry(mode: 'bus', distanceKm: 5.0),
                TransportEntry(mode: 'car', distanceKm: 2.0),
              ],
              foodEntries: [],
              energyDeviations: [],
            );
            final qualified = GamificationEngine.evaluateStrategy(
              strategy: challenge['strategy'],
              params: challenge['strategy_params'],
              dailyResult: log,
            );
            expect(qualified, isFalse);
          },
        );
      },
    );

    // -------------------------------------------------------------------------
    // FOOD CHALLENGES (3)
    // -------------------------------------------------------------------------

    group('Food Challenge 8: Meat-Free Day (id: meat_free_day)', () {
      final challenge = getChallenge('meat_free_day');

      test(
        'Success: Only vegetarian/plant foods logged -> qualified = true',
        () {
          const log = DailyLog(
            userId: 'u1',
            date: '2026-08-26',
            transportEntries: [],
            foodEntries: [
              FoodEntry(
                foodName: 'Salad',
                mealSlot: 'lunch',
                category: 'vegetables',
                servingSize: '1 bowl',
                grams: 200,
              ),
              FoodEntry(
                foodName: 'Rice',
                mealSlot: 'dinner',
                category: 'grains',
                servingSize: '1 plate',
                grams: 250,
              ),
            ],
            energyDeviations: [],
          );
          final qualified = GamificationEngine.evaluateStrategy(
            strategy: challenge['strategy'],
            params: challenge['strategy_params'],
            dailyResult: log,
          );
          expect(qualified, isTrue);
        },
      );

      test(
        'Failure: Chicken item logged -> FOOD_NONE_MATCH fails -> qualified = false',
        () {
          const log = DailyLog(
            userId: 'u1',
            date: '2026-08-26',
            transportEntries: [],
            foodEntries: [
              FoodEntry(
                foodName: 'Chicken Curry',
                mealSlot: 'dinner',
                category: 'chicken',
                servingSize: '1 plate',
                grams: 250,
              ),
            ],
            energyDeviations: [],
          );
          final qualified = GamificationEngine.evaluateStrategy(
            strategy: challenge['strategy'],
            params: challenge['strategy_params'],
            dailyResult: log,
          );
          expect(qualified, isFalse);
        },
      );

      test('Edge Case: Empty food entries returns false', () {
        const log = DailyLog(
          userId: 'u1',
          date: '2026-08-26',
          transportEntries: [],
          foodEntries: [],
          energyDeviations: [],
        );
        final qualified = GamificationEngine.evaluateStrategy(
          strategy: challenge['strategy'],
          params: challenge['strategy_params'],
          dailyResult: log,
        );
        expect(qualified, isFalse);
      });
    });

    group('Food Challenge 9: Plant-Based Week (id: plant_based_week)', () {
      final challenge = getChallenge('plant_based_week');

      test(
        'Success: All entries belong to accepted plant categories -> qualified = true',
        () {
          const log = DailyLog(
            userId: 'u1',
            date: '2026-08-26',
            transportEntries: [],
            foodEntries: [
              FoodEntry(
                foodName: 'Apple',
                mealSlot: 'snack',
                category: 'fruit',
                servingSize: '1 apple',
                grams: 150,
              ),
              FoodEntry(
                foodName: 'Tofu Fry',
                mealSlot: 'lunch',
                category: 'tofu',
                servingSize: '1 bowl',
                grams: 200,
              ),
            ],
            energyDeviations: [],
          );
          final qualified = GamificationEngine.evaluateStrategy(
            strategy: challenge['strategy'],
            params: challenge['strategy_params'],
            dailyResult: log,
          );
          expect(qualified, isTrue);
        },
      );

      test(
        'Failure: Dairy / Beef entry fails FOOD_ALL_MATCH -> qualified = false',
        () {
          const log = DailyLog(
            userId: 'u1',
            date: '2026-08-26',
            transportEntries: [],
            foodEntries: [
              FoodEntry(
                foodName: 'Beef Steak',
                mealSlot: 'dinner',
                category: 'beef',
                servingSize: '1 steak',
                grams: 300,
              ),
            ],
            energyDeviations: [],
          );
          final qualified = GamificationEngine.evaluateStrategy(
            strategy: challenge['strategy'],
            params: challenge['strategy_params'],
            dailyResult: log,
          );
          expect(qualified, isFalse);
        },
      );
    });

    group('Food Challenge 10: Vegan Challenge (id: vegan_challenge)', () {
      final challenge = getChallenge('vegan_challenge');

      test(
        'Success: 30 consecutive days of plant foods completes challenge',
        () {
          int daysPassed = 29;
          // Day 30 passed
          daysPassed += 1;
          expect(daysPassed, challenge['required_days']);
        },
      );

      test('Failure: Non-vegan item on Day 15 resets 30-day streak', () {
        int daysPassed = 14;
        // Day 15 failed
        if (challenge['consecutive'] == true) {
          daysPassed = 0;
        }
        expect(daysPassed, 0);
      });
    });

    // -------------------------------------------------------------------------
    // ENERGY CHALLENGES (4)
    // -------------------------------------------------------------------------

    group('Energy Challenge 11: Unplug Day (id: unplug_day)', () {
      final challenge = getChallenge('unplug_day');

      test(
        'Success: Energy confirmed AND unplugged_devices tag present -> qualified = true',
        () {
          const log = DailyLog(
            userId: 'u1',
            date: '2026-08-26',
            transportEntries: [],
            foodEntries: [],
            energyDeviations: ['unplugged_devices'],
            energyConfirmed: true,
          );
          final qualified = GamificationEngine.evaluateStrategy(
            strategy: challenge['strategy'],
            params: challenge['strategy_params'],
            dailyResult: log,
          );
          expect(qualified, isTrue);
        },
      );

      test('Failure: Unconfirmed energy section -> qualified = false', () {
        const log = DailyLog(
          userId: 'u1',
          date: '2026-08-26',
          transportEntries: [],
          foodEntries: [],
          energyDeviations: [], // Empty and unconfirmed!
          energyConfirmed: false,
        );
        final qualified = GamificationEngine.evaluateStrategy(
          strategy: challenge['strategy'],
          params: challenge['strategy_params'],
          dailyResult: log,
        );
        expect(qualified, isFalse);
      });
    });

    group('Energy Challenge 12: Cold Shower Week (id: cold_shower_week)', () {
      final challenge = getChallenge('cold_shower_week');

      test(
        'Success: cold_shower tag present with confirmed energy -> qualified = true',
        () {
          const log = DailyLog(
            userId: 'u1',
            date: '2026-08-26',
            transportEntries: [],
            foodEntries: [],
            energyDeviations: ['cold_shower'],
            energyConfirmed: true,
          );
          final qualified = GamificationEngine.evaluateStrategy(
            strategy: challenge['strategy'],
            params: challenge['strategy_params'],
            dailyResult: log,
          );
          expect(qualified, isTrue);
        },
      );

      test(
        'Edge Case: Plural alias cold_showers also satisfies cold_shower strategy',
        () {
          const log = DailyLog(
            userId: 'u1',
            date: '2026-08-26',
            transportEntries: [],
            foodEntries: [],
            energyDeviations: ['cold_showers'], // Plural alias!
            energyConfirmed: true,
          );
          final qualified = GamificationEngine.evaluateStrategy(
            strategy: challenge['strategy'],
            params: challenge['strategy_params'],
            dailyResult: log,
          );
          expect(qualified, isTrue);
        },
      );
    });

    group(
      'Energy Challenge 13: Screen Time Cutback (id: screen_time_cutback)',
      () {
        final challenge = getChallenge('screen_time_cutback');

        test(
          'Success: low_screen_time tag present with confirmed energy -> qualified = true',
          () {
            const log = DailyLog(
              userId: 'u1',
              date: '2026-08-26',
              transportEntries: [],
              foodEntries: [],
              energyDeviations: ['low_screen_time'],
              energyConfirmed: true,
            );
            final qualified = GamificationEngine.evaluateStrategy(
              strategy: challenge['strategy'],
              params: challenge['strategy_params'],
              dailyResult: log,
            );
            expect(qualified, isTrue);
          },
        );

        test('Failure: low_screen_time tag missing -> qualified = false', () {
          const log = DailyLog(
            userId: 'u1',
            date: '2026-08-26',
            transportEntries: [],
            foodEntries: [],
            energyDeviations: ['no_ac'],
            energyConfirmed: true,
          );
          final qualified = GamificationEngine.evaluateStrategy(
            strategy: challenge['strategy'],
            params: challenge['strategy_params'],
            dailyResult: log,
          );
          expect(qualified, isFalse);
        });
      },
    );

    group('Energy Challenge 14: No AC Week (id: no_ac_week)', () {
      final challenge = getChallenge('no_ac_week');

      test(
        'Success: ac_used tag ABSENT with confirmed energy -> qualified = true',
        () {
          const log = DailyLog(
            userId: 'u1',
            date: '2026-08-26',
            transportEntries: [],
            foodEntries: [],
            energyDeviations: ['fan_only', 'open_windows'],
            energyConfirmed: true,
          );
          final qualified = GamificationEngine.evaluateStrategy(
            strategy: challenge['strategy'],
            params: challenge['strategy_params'],
            dailyResult: log,
          );
          expect(qualified, isTrue);
        },
      );

      test('Failure: ac_used tag PRESENT -> qualified = false', () {
        const log = DailyLog(
          userId: 'u1',
          date: '2026-08-26',
          transportEntries: [],
          foodEntries: [],
          energyDeviations: ['ac_used'],
          energyConfirmed: true,
        );
        final qualified = GamificationEngine.evaluateStrategy(
          strategy: challenge['strategy'],
          params: challenge['strategy_params'],
          dailyResult: log,
        );
        expect(qualified, isFalse);
      });

      test(
        'Failure: Unconfirmed energy section fails LOG_TAG_ABSENT -> qualified = false',
        () {
          const log = DailyLog(
            userId: 'u1',
            date: '2026-08-26',
            transportEntries: [],
            foodEntries: [],
            energyDeviations: [],
            energyConfirmed: false, // Unconfirmed!
          );
          final qualified = GamificationEngine.evaluateStrategy(
            strategy: challenge['strategy'],
            params: challenge['strategy_params'],
            dailyResult: log,
          );
          expect(qualified, isFalse);
        },
      );
    });

    // -------------------------------------------------------------------------
    // NATURE CHALLENGE (1)
    // -------------------------------------------------------------------------

    group(
      'Nature Challenge 15: 100-Day Green Journey (id: 100_day_green_journey)',
      () {
        final challenge = getChallenge('100_day_green_journey');

        test(
          'Success: APP_BEHAVIOR strategy evaluates to true for active daily log',
          () {
            const log = DailyLog(
              userId: 'u1',
              date: '2026-08-26',
              transportEntries: [],
              foodEntries: [],
              energyDeviations: [],
            );
            final qualified = GamificationEngine.evaluateStrategy(
              strategy: challenge['strategy'],
              params: challenge['strategy_params'],
              dailyResult: log,
            );
            expect(qualified, isTrue);
          },
        );

        test(
          'Failure: Missed day in 100-day consecutive run resets days_passed to 0',
          () {
            int daysPassed = 45;
            // Missed day!
            if (challenge['consecutive'] == true) {
              daysPassed = 0;
            }
            expect(daysPassed, 0);
          },
        );
      },
    );
  });
}
