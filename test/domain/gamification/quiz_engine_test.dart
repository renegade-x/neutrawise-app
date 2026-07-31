import 'package:flutter_test/flutter_test.dart';
import 'package:neutrawise/domain/gamification/quiz_engine.dart';

void main() {
  group('QuizEngine Unit Tests', () {
    final now = DateTime(2026, 7, 31, 12, 0);

    test(
      'XP Calculation: Base attempt (30 XP), correct answers (+5/ea), perfect bonus (+50 XP)',
      () {
        // 5/5 Correct
        final perfectResult = QuizEngine.calculateQuizXp(
          score: 5,
          totalQuestions: 5,
        );
        expect(perfectResult['baseAttemptXp'], 30);
        expect(perfectResult['perQuestionBonus'], 25);
        expect(perfectResult['perfectBonus'], 50);
        expect(perfectResult['totalXp'], 105);
        expect(perfectResult['isPerfect'], true);

        // 3/5 Correct
        final partialResult = QuizEngine.calculateQuizXp(
          score: 3,
          totalQuestions: 5,
        );
        expect(partialResult['baseAttemptXp'], 30);
        expect(partialResult['perQuestionBonus'], 15);
        expect(partialResult['perfectBonus'], 0);
        expect(partialResult['totalXp'], 45);
        expect(partialResult['isPerfect'], false);

        // 10/10 Correct
        final tenResult = QuizEngine.calculateQuizXp(
          score: 10,
          totalQuestions: 10,
        );
        expect(tenResult['totalXp'], 130); // 30 + 50 + 50 = 130
        expect(tenResult['isPerfect'], true);
      },
    );

    test(
      'Quiz Status: Available, Completed, and Expired within 48h window',
      () {
        final sampleQuiz = QuizEngine.getSampleQuiz(
          startTime: now.subtract(const Duration(hours: 10)),
        );

        // 1. Available when within 48h and completedAt is null
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
      final sampleQuiz = QuizEngine.getSampleQuiz(
        startTime: now.subtract(const Duration(hours: 20)),
      );

      final remaining = QuizEngine.getRemainingWindowDuration(
        quiz: sampleQuiz,
        now: now,
      );

      expect(remaining.inHours, 28); // 48 - 20 = 28 hours remaining
    });

    test('Sample Quiz structure contains valid questions and options', () {
      final quiz = QuizEngine.getSampleQuiz();
      expect(quiz.questions.isNotEmpty, true);
      expect(quiz.questions.length, 5);

      for (final q in quiz.questions) {
        expect(q.text.isNotEmpty, true);
        expect(q.options.length, 4);
        expect(q.correctIndex >= 0 && q.correctIndex < 4, true);
        expect(q.explanation.isNotEmpty, true);
      }
    });
  });
}
