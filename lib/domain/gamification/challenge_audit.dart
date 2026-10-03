/// Pure helpers for the daily challenge audit (no I/O, fully unit-testable).
library;

/// Formats a date as `YYYY-MM-DD` (calendar day, no time component).
String formatAuditDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Strips the time from a [DateTime] (local calendar day).
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Result of applying one audited day to a challenge run.
class ChallengeAuditStep {
  final int daysPassed;
  final bool completed;
  final bool failed;

  const ChallengeAuditStep({
    required this.daysPassed,
    required this.completed,
    required this.failed,
  });
}

/// Applies one fully-elapsed calendar day to a challenge.
///
/// - A qualified day adds one to [daysPassed].
/// - An unqualified day resets progress for consecutive / APP_BEHAVIOR
///   challenges and leaves it unchanged for the others.
/// - The challenge completes once [requiredDays] is reached.
/// - If the challenge window ([windowDays] calendar days, counting the start
///   day) has fully elapsed without completing, it has failed.
ChallengeAuditStep applyAuditDay({
  required int daysPassed,
  required bool qualified,
  required bool consecutive,
  required String strategy,
  required int requiredDays,
  required int windowDays,
  required int dayNumber, // 1 = start day, 2 = next day, ...
}) {
  var days = daysPassed;
  if (qualified) {
    days += 1;
  } else if (consecutive || strategy == 'APP_BEHAVIOR') {
    days = 0;
  }

  final completed = days >= requiredDays;
  final failed = !completed && dayNumber >= windowDays;
  return ChallengeAuditStep(
    daysPassed: days,
    completed: completed,
    failed: failed,
  );
}

/// Calendar days that still need auditing for one challenge run: from the
/// later of the start day and the day after [lastAudited], up to and
/// including [lastDayToAudit] (normally yesterday). Capped at [maxDays].
List<DateTime> pendingAuditDays({
  required DateTime startedAt,
  required DateTime? lastAudited,
  required DateTime lastDayToAudit,
  int maxDays = 120,
}) {
  final start = dateOnly(startedAt);
  var first = start;
  if (lastAudited != null) {
    final next = dateOnly(lastAudited).add(const Duration(days: 1));
    if (next.isAfter(first)) first = next;
  }
  final last = dateOnly(lastDayToAudit);
  final days = <DateTime>[];
  var d = first;
  while (!d.isAfter(last) && days.length < maxDays) {
    days.add(d);
    d = DateTime(d.year, d.month, d.day + 1);
  }
  return days;
}
