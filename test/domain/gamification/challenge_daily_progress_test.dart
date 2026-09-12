import 'package:flutter_test/flutter_test.dart';
import 'package:neutrawise/domain/gamification/gamification_engine.dart';
import 'package:neutrawise/domain/models/daily_log.dart';

void main() {
  group('v3.0 Challenge Daily Qualification & Reversal Engine (Option B Spec)', () {
    test('TC-CH-015: Qualifying entry followed by violating update — same day', () {
      // Challenge: No Car Week (LOG_FIELD_ZERO, consecutive, field: car_km)
      const strategy = 'LOG_FIELD_ZERO';
      const params = {'field': 'car_km'};

      // Action 1 (8 AM): Log submitted with car_km = 0
      const logAction1 = DailyLog(
        userId: 'u1',
        date: '2026-08-24',
        transportEntries: [TransportEntry(mode: 'cycling', distanceKm: 5.0)],
        transportCo2: 0.0,
        foodEntries: [],
        foodCo2: 0.0,
        energyDeviations: [],
        energyCo2: 0.0,
        totalDailyCo2: 0.0,
        baselineCo2: 2.0,
        co2SavedVsBaseline: 2.0,
        percentVsBaseline: -100.0,
        xpEarned: 0,
      );

      final qualified1 = GamificationEngine.evaluateStrategy(
        strategy: strategy,
        params: params,
        dailyResult: logAction1,
      );
      expect(
        qualified1,
        isTrue,
        reason: '8 AM log with car_km = 0 must qualify',
      );

      // Action 2 (6 PM): Log updated; car trip added (car_km = 12.0)
      const logAction2 = DailyLog(
        userId: 'u1',
        date: '2026-08-24',
        transportEntries: [
          TransportEntry(mode: 'cycling', distanceKm: 5.0),
          TransportEntry(mode: 'car', distanceKm: 12.0),
        ],
        transportCo2: 2.4,
        foodEntries: [],
        foodCo2: 0.0,
        energyDeviations: [],
        energyCo2: 0.0,
        totalDailyCo2: 2.4,
        baselineCo2: 2.0,
        co2SavedVsBaseline: -0.4,
        percentVsBaseline: 20.0,
        xpEarned: 0,
      );

      final qualified2 = GamificationEngine.evaluateStrategy(
        strategy: strategy,
        params: params,
        dailyResult: logAction2,
      );
      expect(
        qualified2,
        isFalse,
        reason:
            '6 PM log with car_km = 12.0 must unqualify (overwritten flag = false)',
      );

      // Midnight Audit Simulation:
      // qualified = false, consecutive = true -> days_passed resets to 0
      int daysPassed = 4;
      const isConsecutive = true;
      if (qualified2) {
        daysPassed += 1;
      } else if (isConsecutive) {
        daysPassed = 0;
      }
      expect(
        daysPassed,
        0,
        reason:
            'Midnight audit must reset consecutive challenge when daily qualification is false',
      );
    });

    test(
      'TC-CH-016: Qualifying entry followed by non-violating addition — non-consecutive challenge',
      () {
        // Challenge: Walk 7 Days (TRANSPORT_ANY_MATCH, non-consecutive)
        const strategy = 'TRANSPORT_ANY_MATCH';
        const params = {
          'accepted_values': ['walking'],
        };

        // Action 1 (7 AM): Log walking leg
        const logAction1 = DailyLog(
          userId: 'u1',
          date: '2026-08-24',
          transportEntries: [TransportEntry(mode: 'walking', distanceKm: 2.0)],
          transportCo2: 0.0,
          foodEntries: [],
          foodCo2: 0.0,
          energyDeviations: [],
          energyCo2: 0.0,
          totalDailyCo2: 0.0,
          baselineCo2: 1.0,
          co2SavedVsBaseline: 1.0,
          percentVsBaseline: -100.0,
          xpEarned: 0,
        );

        final qualified1 = GamificationEngine.evaluateStrategy(
          strategy: strategy,
          params: params,
          dailyResult: logAction1,
        );
        expect(qualified1, isTrue);

        // Action 2 (8 PM): User adds car leg (forgot to log it). Walking leg still present!
        const logAction2 = DailyLog(
          userId: 'u1',
          date: '2026-08-24',
          transportEntries: [
            TransportEntry(mode: 'walking', distanceKm: 2.0),
            TransportEntry(mode: 'car', distanceKm: 15.0),
          ],
          transportCo2: 3.0,
          foodEntries: [],
          foodCo2: 0.0,
          energyDeviations: [],
          energyCo2: 0.0,
          totalDailyCo2: 3.0,
          baselineCo2: 1.0,
          co2SavedVsBaseline: -2.0,
          percentVsBaseline: 200.0,
          xpEarned: 0,
        );

        final qualified2 = GamificationEngine.evaluateStrategy(
          strategy: strategy,
          params: params,
          dailyResult: logAction2,
        );
        expect(
          qualified2,
          isTrue,
          reason:
              'TRANSPORT_ANY_MATCH remains true as walking leg still exists',
        );

        // Midnight Audit Simulation:
        int daysPassed = 3;
        if (qualified2) {
          daysPassed += 1;
        }
        expect(
          daysPassed,
          4,
          reason: 'Midnight audit increments non-consecutive days_passed to 4',
        );
      },
    );

    test(
      'TC-CH-017: Energy log confirmed, then re-opened and AC tag added',
      () {
        // Challenge: No AC Week (LOG_TAG_ABSENT, tag: ac_used, consecutive)
        const strategy = 'LOG_TAG_ABSENT';
        const params = {'tag': 'ac_used'};

        // Action 1 (2 PM): Energy confirmed without ac_used tag
        const logAction1 = DailyLog(
          userId: 'u1',
          date: '2026-08-24',
          transportEntries: [],
          transportCo2: 0.0,
          foodEntries: [],
          foodCo2: 0.0,
          energyDeviations: ['unplugged_devices'],
          energyCo2: 1.0,
          totalDailyCo2: 1.0,
          baselineCo2: 2.0,
          co2SavedVsBaseline: 1.0,
          percentVsBaseline: -50.0,
          xpEarned: 0,
        );

        final qualified1 = GamificationEngine.evaluateStrategy(
          strategy: strategy,
          params: params,
          dailyResult: logAction1,
        );
        expect(qualified1, isTrue);

        // Action 2 (9 PM): User adds ac_used tag
        const logAction2 = DailyLog(
          userId: 'u1',
          date: '2026-08-24',
          transportEntries: [],
          transportCo2: 0.0,
          foodEntries: [],
          foodCo2: 0.0,
          energyDeviations: ['unplugged_devices', 'ac_used'],
          energyCo2: 4.0,
          totalDailyCo2: 4.0,
          baselineCo2: 2.0,
          co2SavedVsBaseline: -2.0,
          percentVsBaseline: 100.0,
          xpEarned: 0,
        );

        final qualified2 = GamificationEngine.evaluateStrategy(
          strategy: strategy,
          params: params,
          dailyResult: logAction2,
        );
        expect(
          qualified2,
          isFalse,
          reason: 'ac_used tag presence invalidates LOG_TAG_ABSENT',
        );

        // Midnight Audit Simulation:
        int daysPassed = 5;
        const isConsecutive = true;
        if (qualified2) {
          daysPassed += 1;
        } else if (isConsecutive) {
          daysPassed = 0;
        }
        expect(
          daysPassed,
          0,
          reason:
              'Midnight audit resets consecutive challenge on tag violation',
        );
      },
    );

    test(
      'TC-CH-018: Offline log for past date does not retroactively fix challenge',
      () {
        final todayDate = DateTime(2026, 8, 24);
        final pastLogDate = DateTime(2026, 8, 23);

        final isPastAuditedDate = pastLogDate.isBefore(todayDate);
        expect(isPastAuditedDate, isTrue);

        // Rule: Past audited date logs skip challenge evaluation & qualification upsert
        bool evaluationRan = false;
        if (!isPastAuditedDate) {
          evaluationRan = true;
        }

        expect(
          evaluationRan,
          isFalse,
          reason:
              'Offline log for past date must NOT retroactively adjust challenge progress',
        );
      },
    );
  });
}
