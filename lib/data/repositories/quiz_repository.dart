import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:neutrawise/domain/gamification/quiz_engine.dart';
import 'package:neutrawise/domain/gamification/gamification_engine.dart';
import 'package:neutrawise/data/repositories/user_repository.dart';

final quizRepositoryProvider = Provider<QuizRepository>((ref) {
  return QuizRepository(Supabase.instance.client);
});

final activeQuizProvider = FutureProvider.family<Map<String, dynamic>, String>((
  ref,
  userId,
) async {
  final repo = ref.watch(quizRepositoryProvider);
  return repo.getActiveQuizData(userId);
});

class QuizRepository {
  final SupabaseClient _supabase;

  QuizRepository(this._supabase);

  /// Fetch active quiz and user attempt data
  Future<Map<String, dynamic>> getActiveQuizData(String userId) async {
    final now = DateTime.now();

    Quiz? quiz;
    QuizAttemptResult? attempt;

    try {
      // 1. Query Supabase for active quiz within 48h window
      final response = await _supabase
          .from('quizzes')
          .select()
          .lte('start_time', now.toIso8601String())
          .gte('end_time', now.toIso8601String())
          .order('start_time', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        quiz = Quiz.fromJson(response);
      }
    } catch (_) {
      // Offline or schema fallback
    }

    // 2. Dynamic Fallback: if no active quiz in quizzes table, try fetching 5 random questions from question_bank
    if (quiz == null) {
      try {
        final bankResponse = await _supabase
            .from('question_bank')
            .select()
            .limit(5);

        if (bankResponse.isNotEmpty && bankResponse.length >= 3) {
          final questions = bankResponse.map((item) {
            final m = Map<String, dynamic>.from(item as Map);
            final rawOptions = m['options'];
            List<String> options = [];
            if (rawOptions is List) {
              options = List<String>.from(rawOptions);
            }
            return QuizQuestion(
              id: m['id'] as String? ?? 'q',
              text: m['text'] as String? ?? '',
              options: options,
              correctIndex: m['correct_index'] as int? ?? 0,
              explanation: m['explanation'] as String? ?? '',
            );
          }).toList();

          final start = now.subtract(const Duration(hours: 2));
          final end = start.add(const Duration(hours: 48));

          quiz = Quiz(
            id: 'dynamic_bank_quiz_${start.millisecondsSinceEpoch}',
            title: 'Bi-Weekly Eco Quiz',
            topic: 'Sustainability Knowledge',
            questions: questions,
            startTime: start,
            endTime: end,
          );
        }
      } catch (_) {}
    }

    // 3. Fallback to client-side sample quiz if no DB record or question bank found
    quiz ??= QuizEngine.getSampleQuiz(
      startTime: now.subtract(const Duration(hours: 4)),
    );

    try {
      // 4. Fetch user's completion attempt for this quiz if available
      final attemptResponse = await _supabase
          .from('user_quizzes')
          .select()
          .eq('user_id', userId)
          .eq('quiz_id', quiz.id)
          .maybeSingle();

      if (attemptResponse != null) {
        attempt = QuizAttemptResult.fromJson(attemptResponse);
      }
    } catch (_) {
      // Offline fallback
    }

    final status = QuizEngine.getQuizStatus(
      quiz: quiz,
      completedAt: attempt?.completedAt,
      now: now,
    );

    return {'quiz': quiz, 'attempt': attempt, 'status': status};
  }

  /// Submit quiz attempt and award XP to user profile
  Future<void> submitQuizAttempt(
    String userId,
    QuizAttemptResult attempt,
    WidgetRef ref,
  ) async {
    try {
      // 1. Upsert attempt into user_quizzes table
      await _supabase.from('user_quizzes').upsert({
        'user_id': userId,
        'quiz_id': attempt.quizId,
        'score': attempt.score,
        'total_questions': attempt.totalQuestions,
        'xp_earned': attempt.xpEarned,
        'is_perfect': attempt.isPerfect,
        'answers': attempt.answers,
        'completed_at': attempt.completedAt.toIso8601String(),
      });

      // 2. Update user profile XP and Level
      final userProfile = await _supabase
          .from('users')
          .select('xp, level')
          .eq('id', userId)
          .single();

      final currentXp = (userProfile['xp'] as int?) ?? 0;
      final newXp = currentXp + attempt.xpEarned;
      final newLevel = GamificationEngine.getLevelFromXp(newXp);

      await _supabase
          .from('users')
          .update({'xp': newXp, 'level': newLevel})
          .eq('id', userId);

      // Check if perfect quiz badge is earned (e.g. Quiz Whiz)
      if (attempt.isPerfect) {
        await _supabase.from('badges').upsert({
          'user_id': userId,
          'badge_name': 'Quiz Whiz 🧠',
          'category': 'Special',
          'earned_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (_) {
      // Handle local state or silent fallback
    }

    // Invalidate state to trigger UI updates
    ref.invalidate(activeQuizProvider(userId));
    ref.invalidate(userProfileProvider(userId));
  }
}
