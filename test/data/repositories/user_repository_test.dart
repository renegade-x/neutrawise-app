import 'package:flutter_test/flutter_test.dart';
import 'package:neutrawise/data/repositories/user_repository.dart';

void main() {
  group('UserRepository Streak Engine Tests', () {
    final now = DateTime(2026, 8, 26, 12, 0, 0); // Wednesday, Aug 26

    test('1 single logging day (Aug 26) calculates streak of 0', () {
      final logDates = ['2026-08-26'];
      final streak = UserRepository.calculateStreakFromLogDates(
        logDates,
        now,
        false,
      );
      expect(streak, 0);
    });

    test(
      '3 consecutive logging days (Aug 24, Aug 25, Aug 26) calculates streak of 2',
      () {
        final logDates = ['2026-08-26', '2026-08-25', '2026-08-24'];
        final streak = UserRepository.calculateStreakFromLogDates(
          logDates,
          now,
          false,
        );
        expect(streak, 2);
      },
    );

    test('Active streak from yesterday waiting for today (Aug 24, Aug 25)', () {
      final logDates = ['2026-08-25', '2026-08-24'];
      final streak = UserRepository.calculateStreakFromLogDates(
        logDates,
        now,
        false,
      );
      expect(streak, 1);
    });

    test('Multiple logs on the same date do not double-increment streak', () {
      final logDates = ['2026-08-26', '2026-08-26', '2026-08-25', '2026-08-24'];
      final streak = UserRepository.calculateStreakFromLogDates(
        logDates,
        now,
        false,
      );
      expect(streak, 2);
    });

    test('Broken streak due to missed days (>1 day gap without freeze)', () {
      final logDates = ['2026-08-23', '2026-08-22'];
      final streak = UserRepository.calculateStreakFromLogDates(
        logDates,
        now,
        false,
      );
      expect(streak, 0);
    });

    test('Streak freeze preserves streak across a 1-day missed gap', () {
      final logDates = ['2026-08-24', '2026-08-23'];
      final streak = UserRepository.calculateStreakFromLogDates(
        logDates,
        now,
        true,
      );
      expect(streak, 1);
    });
  });
}
