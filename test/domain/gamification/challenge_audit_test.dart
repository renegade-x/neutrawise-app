import 'package:flutter_test/flutter_test.dart';
import 'package:neutrawise/domain/gamification/challenge_audit.dart';

void main() {
  group('applyAuditDay', () {
    test('qualified day advances progress', () {
      final step = applyAuditDay(
        daysPassed: 2,
        qualified: true,
        consecutive: true,
        strategy: 'LOG_FIELD_ZERO',
        requiredDays: 7,
        windowDays: 7,
        dayNumber: 3,
      );
      expect(step.daysPassed, 3);
      expect(step.completed, isFalse);
      expect(step.failed, isFalse);
    });

    test('missed day resets consecutive challenges', () {
      final step = applyAuditDay(
        daysPassed: 4,
        qualified: false,
        consecutive: true,
        strategy: 'LOG_FIELD_ZERO',
        requiredDays: 7,
        windowDays: 14,
        dayNumber: 5,
      );
      expect(step.daysPassed, 0);
    });

    test('missed day keeps progress on non-consecutive challenges', () {
      final step = applyAuditDay(
        daysPassed: 4,
        qualified: false,
        consecutive: false,
        strategy: 'LOG_FIELD_ZERO',
        requiredDays: 5,
        windowDays: 10,
        dayNumber: 6,
      );
      expect(step.daysPassed, 4);
    });

    test('APP_BEHAVIOR resets even when not consecutive', () {
      final step = applyAuditDay(
        daysPassed: 3,
        qualified: false,
        consecutive: false,
        strategy: 'APP_BEHAVIOR',
        requiredDays: 7,
        windowDays: 14,
        dayNumber: 4,
      );
      expect(step.daysPassed, 0);
    });

    test(
      'reaching required days completes (and does not fail on last day)',
      () {
        final step = applyAuditDay(
          daysPassed: 6,
          qualified: true,
          consecutive: true,
          strategy: 'LOG_FIELD_ZERO',
          requiredDays: 7,
          windowDays: 7,
          dayNumber: 7,
        );
        expect(step.completed, isTrue);
        expect(step.failed, isFalse);
      },
    );

    test('one-day challenge qualified on its only day completes', () {
      final step = applyAuditDay(
        daysPassed: 0,
        qualified: true,
        consecutive: false,
        strategy: 'LOG_FIELD_ZERO',
        requiredDays: 1,
        windowDays: 1,
        dayNumber: 1,
      );
      expect(step.completed, isTrue);
    });

    test('window elapsing without completion fails the run', () {
      final step = applyAuditDay(
        daysPassed: 1,
        qualified: false,
        consecutive: false,
        strategy: 'LOG_FIELD_ZERO',
        requiredDays: 5,
        windowDays: 7,
        dayNumber: 7,
      );
      expect(step.completed, isFalse);
      expect(step.failed, isTrue);
    });
  });

  group('pendingAuditDays', () {
    test('starts at the start day when never audited', () {
      final days = pendingAuditDays(
        startedAt: DateTime(2026, 10, 1, 15, 30),
        lastAudited: null,
        lastDayToAudit: DateTime(2026, 10, 3),
      );
      expect(days.map(formatAuditDate), [
        '2026-10-01',
        '2026-10-02',
        '2026-10-03',
      ]);
    });

    test('resumes the day after the last audited day', () {
      final days = pendingAuditDays(
        startedAt: DateTime(2026, 10, 1),
        lastAudited: DateTime(2026, 10, 2),
        lastDayToAudit: DateTime(2026, 10, 4),
      );
      expect(days.map(formatAuditDate), ['2026-10-03', '2026-10-04']);
    });

    test('nothing pending when already audited through yesterday', () {
      final days = pendingAuditDays(
        startedAt: DateTime(2026, 10, 1),
        lastAudited: DateTime(2026, 10, 3),
        lastDayToAudit: DateTime(2026, 10, 3),
      );
      expect(days, isEmpty);
    });

    test('same-day enrollment has nothing to audit yet', () {
      final days = pendingAuditDays(
        startedAt: DateTime(2026, 10, 4, 9),
        lastAudited: null,
        lastDayToAudit: DateTime(2026, 10, 3),
      );
      expect(days, isEmpty);
    });

    test('ignores last-audited dates before the start day', () {
      final days = pendingAuditDays(
        startedAt: DateTime(2026, 10, 3),
        lastAudited: DateTime(2026, 9, 1),
        lastDayToAudit: DateTime(2026, 10, 3),
      );
      expect(days.map(formatAuditDate), ['2026-10-03']);
    });

    test('is capped to avoid unbounded loops', () {
      final days = pendingAuditDays(
        startedAt: DateTime(2020, 1, 1),
        lastAudited: null,
        lastDayToAudit: DateTime(2026, 10, 3),
        maxDays: 120,
      );
      expect(days.length, 120);
    });

    test('crosses month boundaries correctly', () {
      final days = pendingAuditDays(
        startedAt: DateTime(2026, 9, 29),
        lastAudited: null,
        lastDayToAudit: DateTime(2026, 10, 2),
      );
      expect(days.map(formatAuditDate), [
        '2026-09-29',
        '2026-09-30',
        '2026-10-01',
        '2026-10-02',
      ]);
    });
  });
}
