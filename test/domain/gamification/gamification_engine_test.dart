import 'package:flutter_test/flutter_test.dart';
import 'package:neutrawise/domain/gamification/gamification_engine.dart';

void main() {
  group('GamificationEngine Tests', () {
    group('XP Calculation', () {
      test('Full log, streak 0, level 1, 0% savings', () {
        final xp = GamificationEngine.calculateXp(
          isFullLog: true,
          currentStreak: 0,
          currentLevel: 1,
          co2SavedPercent: 0.0,
        );
        expect(xp, 50); // (50 + 0) * 1.0 * 1.0 = 50
      });

      test('Full log, streak 7, level 1, 20% savings', () {
        final xp = GamificationEngine.calculateXp(
          isFullLog: true,
          currentStreak: 7,
          currentLevel: 1,
          co2SavedPercent: 20.0,
        );
        expect(xp, 81); // (50 + 15) * 1.25 * 1.0 = 81.25 -> 81
      });

      test('Full log, streak 30, level 5, 35% savings', () {
        final xp = GamificationEngine.calculateXp(
          isFullLog: true,
          currentStreak: 30,
          currentLevel: 5,
          co2SavedPercent: 35.0,
        );
        expect(xp, 124); // (50 + 25) * 1.5 * 1.1 = 123.75 -> 124
      });

      test('Partial log, streak 30, level 9, 5% savings', () {
        final xp = GamificationEngine.calculateXp(
          isFullLog: false,
          currentStreak: 30,
          currentLevel: 9,
          co2SavedPercent: 5.0,
        );
        expect(xp, 50); // (20 + 8) * 1.5 * 1.2 = 50.4 -> 50
      });

      test('Daily XP Cap enforcement', () {
        final xp = GamificationEngine.calculateXp(
          isFullLog: true,
          currentStreak: 30,
          currentLevel: 10,
          co2SavedPercent: 100.0,
          dailyXpCap: 100,
        );
        expect(xp, 100);
      });
    });

    group('Level Progression', () {
      test('getLevelFromXp mapping', () {
        expect(GamificationEngine.getLevelFromXp(0), 1);
        expect(GamificationEngine.getLevelFromXp(499), 1);
        expect(GamificationEngine.getLevelFromXp(500), 2);
        expect(GamificationEngine.getLevelFromXp(1499), 2);
        expect(GamificationEngine.getLevelFromXp(1500), 3);
        expect(GamificationEngine.getLevelFromXp(17000), 8);
        expect(GamificationEngine.getLevelFromXp(31000), 10);
        expect(GamificationEngine.getLevelFromXp(50000), 10);
      });

      test('getXpToNextLevel calculation', () {
        expect(GamificationEngine.getXpToNextLevel(1, 0), 500);
        expect(GamificationEngine.getXpToNextLevel(1, 250), 250);
        expect(GamificationEngine.getXpToNextLevel(2, 500), 1000);
        expect(GamificationEngine.getXpToNextLevel(10, 31000), 0);
      });

      test('getLevelTitle mapping', () {
        expect(GamificationEngine.getLevelTitle(1), 'Eco Newcomer');
        expect(GamificationEngine.getLevelTitle(5), 'Eco Advocate');
        expect(GamificationEngine.getLevelTitle(10), 'Carbon Neutral');
        expect(GamificationEngine.getLevelTitle(11), 'Carbon Neutral');
      });
    });

    group('Streak Logic', () {
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      final twoDaysAgo = today.subtract(const Duration(days: 2));

      test('Increment streak on consecutive days', () {
        final streak = GamificationEngine.updateStreak(
          currentStreak: 5,
          lastLogDate: yesterday,
          todayDate: today,
          loggedToday: true,
        );
        expect(streak, 6);
      });

      test('Maintain streak if already logged today', () {
        final streak = GamificationEngine.updateStreak(
          currentStreak: 5,
          lastLogDate: today,
          todayDate: today,
          loggedToday: true,
        );
        expect(streak, 5);
      });

      test('Reset streak to 1 after a gap', () {
        final streak = GamificationEngine.updateStreak(
          currentStreak: 5,
          lastLogDate: twoDaysAgo,
          todayDate: today,
          loggedToday: true,
        );
        expect(streak, 1);
      });

      test('No change to streak if not logged today', () {
        final streak = GamificationEngine.updateStreak(
          currentStreak: 5,
          lastLogDate: yesterday,
          todayDate: today,
          loggedToday: false,
        );
        expect(streak, 5);
      });
    });

    group('5-Day Cycle Streak Logic (calculateNewStreak)', () {
      final now = DateTime.now();

      test('Day 1: First log ever -> streak = 0', () {
        final streak = GamificationEngine.calculateNewStreak(
          currentStreak: 0,
          lastLogTime: null,
          now: now,
          lastLogDateString: null,
          todayDateString: '2026-06-01',
        );
        expect(streak, 0);
      });

      test('Day 2: Log within 24 hours -> streak = 1', () {
        final lastLog = now.subtract(const Duration(hours: 23));
        final streak = GamificationEngine.calculateNewStreak(
          currentStreak: 0,
          lastLogTime: lastLog,
          now: now,
          lastLogDateString: '2026-06-01',
          todayDateString: '2026-06-02',
        );
        expect(streak, 1);
      });

      test('Day 4: Log after gap (> 24 hours) -> streak = 0', () {
        final lastLog = now.subtract(const Duration(hours: 47));
        final streak = GamificationEngine.calculateNewStreak(
          currentStreak: 1,
          lastLogTime: lastLog,
          now: now,
          lastLogDateString: '2026-06-02',
          todayDateString: '2026-06-04',
        );
        expect(streak, 0);
      });

      test('Day 5: Log within 24 hours of Day 4 -> streak = 1', () {
        final lastLog = now.subtract(const Duration(hours: 23));
        final streak = GamificationEngine.calculateNewStreak(
          currentStreak: 0,
          lastLogTime: lastLog,
          now: now,
          lastLogDateString: '2026-06-04',
          todayDateString: '2026-06-05',
        );
        expect(streak, 1);
      });

      test('Log again on the same day -> streak stays the same', () {
        final lastLog = now.subtract(const Duration(hours: 2));
        final streak = GamificationEngine.calculateNewStreak(
          currentStreak: 3,
          lastLogTime: lastLog,
          now: now,
          lastLogDateString: '2026-06-05',
          todayDateString: '2026-06-05',
        );
        expect(streak, 3);
      });
    });
  });
}
