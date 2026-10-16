import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:neutrawise/domain/gamification/quiz_engine.dart';

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

  Future<Map<String, dynamic>> getActiveQuizData(String userId) async {
    final now = DateTime.now().toUtc();
    final windowInfo = QuizEngine.getQuizWindowInfo(now);
    final response = Map<String, dynamic>.from(
      await _supabase.rpc('get_my_quiz_session') as Map,
    );

    if (response['available'] != true) {
      final placeholder = Quiz(
        id: windowInfo.windowId,
        title: 'Bi-Weekly Eco Quiz',
        topic: 'Sustainability & Carbon Science',
        questions: const [],
        startTime: windowInfo.windowStart,
        endTime: windowInfo.windowEnd,
      );
      return {
        'quiz': placeholder,
        'attempt': null,
        'status': QuizStatus.expired,
        'windowInfo': windowInfo,
      };
    }

    final localQuestions = {
      for (final question in QuizEngine.fullQuestionBank) question.id: question,
    };
    final questions = (response['questions'] as List<dynamic>? ?? const [])
        .map((raw) {
          final row = Map<String, dynamic>.from(raw as Map);
          final local = localQuestions[row['id'] as String];
          return QuizQuestion(
            id: row['id'] as String,
            category: row['category'] as String? ?? 'General',
            text: row['text'] as String? ?? '',
            options: List<String>.from(row['options'] as List? ?? const []),
            // The API omits answer keys. The app's existing question bank is
            // used only for immediate UI feedback; the server grades the
            // submitted answers against its private key.
            correctIndex: local?.correctIndex ?? -1,
            explanation: row['explanation'] as String? ?? '',
          );
        })
        .toList(growable: false);

    final quiz = Quiz(
      id: response['quiz_id'] as String,
      title: response['title'] as String? ?? 'Bi-Weekly Eco Quiz',
      topic: response['topic'] as String? ?? 'Sustainability & Carbon Science',
      questions: questions,
      startTime: DateTime.parse(response['start_time'] as String).toLocal(),
      endTime: DateTime.parse(response['end_time'] as String).toLocal(),
    );
    final attemptData = response['attempt'];
    final attempt = attemptData is Map
        ? QuizAttemptResult.fromJson(Map<String, dynamic>.from(attemptData))
        : null;

    return {
      'quiz': quiz,
      'attempt': attempt,
      'status': attempt == null ? QuizStatus.available : QuizStatus.completed,
      'windowInfo': windowInfo,
    };
  }

  /// Sends answers only. Score, perfect status, and XP are computed by the
  /// database from the user's server-issued question set.
  Future<QuizAttemptResult> submitQuizAttempt(
    String userId,
    String quizId,
    List<int> answers,
    WidgetRef ref,
  ) async {
    final response = Map<String, dynamic>.from(
      await _supabase.rpc(
            'submit_my_quiz_attempt',
            params: {'p_quiz_id': quizId, 'p_answers': answers},
          )
          as Map,
    );
    final attempt = QuizAttemptResult.fromJson(response);
    ref.invalidate(activeQuizProvider(userId));
    return attempt;
  }
}
