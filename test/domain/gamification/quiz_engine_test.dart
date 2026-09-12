import 'package:flutter_test/flutter_test.dart';
import 'package:neutrawise/domain/gamification/quiz_engine.dart';

void main() {
  group('QuizEngine Unit Tests (v3.0)', () {
    // Tuesday 12:00 PM (Active Tuesday 48h window: Tue 9 AM -> Thu 9 AM)
    final now = DateTime(2026, 8, 25, 12, 0);

    test(
      'XP Calculation: Level 1-4 gets no perfect bonus (max 80 XP), Level 5+ gets +50 XP perfect bonus (max 130 XP)',
      () {
        // Level 1: 10/10 Correct -> Base 30 + 50 = 80 XP (Perfect bonus locked)
        final lvl1Result = QuizEngine.calculateQuizXp(
          score: 10,
          totalQuestions: 10,
          level: 1,
        );
        expect(lvl1Result['baseAttemptXp'], 30);
        expect(lvl1Result['perQuestionBonus'], 50);
        expect(lvl1Result['perfectBonus'], 0);
        expect(lvl1Result['totalXp'], 80);
        expect(lvl1Result['isPerfect'], true);

        // Level 5: 10/10 Correct -> Base 30 + 50 + 50 = 130 XP (Perfect bonus unlocked!)
        final lvl5Result = QuizEngine.calculateQuizXp(
          score: 10,
          totalQuestions: 10,
          level: 5,
        );
        expect(lvl5Result['baseAttemptXp'], 30);
        expect(lvl5Result['perQuestionBonus'], 50);
        expect(lvl5Result['perfectBonus'], 50);
        expect(lvl5Result['totalXp'], 130);
        expect(lvl5Result['isPerfect'], true);

        // Level 5: 7/10 Correct -> Base 30 + 35 = 65 XP
        final partialResult = QuizEngine.calculateQuizXp(
          score: 7,
          totalQuestions: 10,
          level: 5,
        );
        expect(partialResult['baseAttemptXp'], 30);
        expect(partialResult['perQuestionBonus'], 35);
        expect(partialResult['perfectBonus'], 0);
        expect(partialResult['totalXp'], 65);
        expect(partialResult['isPerfect'], false);
      },
    );

    test(
      'Quiz Status: Available, Completed, and Expired within 48h window',
      () {
        final windowInfo = QuizEngine.getQuizWindowInfo(now);
        final sampleQuiz = QuizEngine.getSampleQuiz(windowInfo: windowInfo);

        // 1. Available when within 48h window and completedAt is null
        final availableStatus = QuizEngine.getQuizStatus(
          quiz: sampleQuiz,
          completedAt: null,
          now: now,
        );
        expect(availableStatus, QuizStatus.available);

        // 2. Completed when completedAt is non-null
        final completedStatus = QuizEngine.getQuizStatus(
          quiz: sampleQuiz,
          completedAt: now.subtract(const Duration(hours: 2)),
          now: now,
        );
        expect(completedStatus, QuizStatus.completed);

        // 3. Expired when now is after endTime
        final expiredStatus = QuizEngine.getQuizStatus(
          quiz: sampleQuiz,
          completedAt: null,
          now: sampleQuiz.endTime.add(const Duration(hours: 1)),
        );
        expect(expiredStatus, QuizStatus.expired);
      },
    );

    test('Remaining window duration calculation', () {
      final windowInfo = QuizEngine.getQuizWindowInfo(now);
      final sampleQuiz = QuizEngine.getSampleQuiz(windowInfo: windowInfo);

      final remaining = QuizEngine.getRemainingWindowDuration(
        quiz: sampleQuiz,
        now: now,
      );

      expect(remaining.inHours, 45); // 48h - 3h elapsed = 45h
    });

    test(
      'Full 50 Question Bank contains valid questions in all 5 categories',
      () {
        expect(QuizEngine.fullQuestionBank.length, 50);

        final categories = QuizEngine.fullQuestionBank
            .map((q) => q.category)
            .toSet();
        expect(categories.contains('Transport'), true);
        expect(categories.contains('Food'), true);
        expect(categories.contains('Energy'), true);
        expect(categories.contains('Climate Science'), true);
        expect(categories.contains('Nature'), true);

        for (final q in QuizEngine.fullQuestionBank) {
          expect(q.text.isNotEmpty, true);
          expect(q.options.length, 4);
          expect(q.correctIndex >= 0 && q.correctIndex < 4, true);
          expect(q.explanation.isNotEmpty, true);
        }
      },
    );
  });
}
