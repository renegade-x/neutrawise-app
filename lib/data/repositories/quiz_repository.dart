import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  final Map<String, QuizAttemptResult> _memoryQuizAttempts = {};

  QuizRepository(this._supabase);

  String _toUuid(String input) {
    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    if (uuidRegex.hasMatch(input)) return input;

    int hash1 = 0x8a9b0c1d;
    int hash2 = 0xe7f5a1b2;
    for (int i = 0; i < input.length; i++) {
      final code = input.codeUnitAt(i);
      hash1 = ((hash1 << 5) - hash1 + code) & 0xFFFFFFFF;
      hash2 = ((hash2 << 7) - hash2 + code) & 0xFFFFFFFF;
    }

    final sb = StringBuffer();
    for (int i = 0; i < input.length; i++) {
      sb.write(input.codeUnitAt(i).toRadixString(16).padLeft(2, '0'));
    }
    sb.write(hash1.toRadixString(16).padLeft(8, '0'));
    sb.write(hash2.toRadixString(16).padLeft(8, '0'));
    sb.write('00000000000000000000000000000000');

    final raw = sb.toString().substring(0, 32);
    return '${raw.substring(0, 8)}-${raw.substring(8, 12)}-4${raw.substring(13, 16)}-a${raw.substring(17, 20)}-${raw.substring(20, 32)}';
  }

  /// Fetch active quiz and user attempt data
  Future<Map<String, dynamic>> getActiveQuizData(String userId) async {
    final now = DateTime.now();
    final windowInfo = QuizEngine.getQuizWindowInfo(now);

    // If outside active 48h windows (Tue 9 AM - Thu 9 AM or Fri 9 AM - Sun 9 AM)
    if (!windowInfo.isAvailable) {
      final placeholderQuiz = Quiz(
        id: windowInfo.windowId,
        title: 'Bi-Weekly Eco Quiz',
        topic: 'Sustainability & Carbon Science',
        questions: [],
        startTime: windowInfo.windowStart,
        endTime: windowInfo.windowEnd,
      );
      return {
        'quiz': placeholderQuiz,
        'attempt': null,
        'status': QuizStatus.expired,
        'windowInfo': windowInfo,
      };
    }

    QuizAttemptResult? attempt;
    final memoryKey = '$userId:${windowInfo.windowId}';

    // 1. Check in-memory local completed attempts first
    if (_memoryQuizAttempts.containsKey(memoryKey)) {
      attempt = _memoryQuizAttempts[memoryKey];
    }

    // 2. Check local SharedPreferences storage (persists across app restarts)
    if (attempt == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final localData = prefs.getString(
          'quiz_attempt_${userId}_${windowInfo.windowId}',
        );
        if (localData != null) {
          attempt = QuizAttemptResult.fromJson(jsonDecode(localData));
          _memoryQuizAttempts[memoryKey] = attempt;
        }
      } catch (_) {}
    }

    // 3. Check user completion attempt for this specific window from Supabase
    if (attempt == null) {
      try {
        var attemptResponse = await _supabase
            .from('user_quizzes')
            .select()
            .eq('user_id', userId)
            .eq('quiz_id', _toUuid(windowInfo.windowId))
            .maybeSingle();

        if (attemptResponse == null) {
          try {
            attemptResponse = await _supabase
                .from('user_quizzes')
                .select()
                .eq('user_id', userId)
                .eq('quiz_id', windowInfo.windowId)
                .maybeSingle();
          } catch (_) {}
        }

        if (attemptResponse != null) {
          attempt = QuizAttemptResult.fromJson(attemptResponse);
          _memoryQuizAttempts[memoryKey] = attempt;
        }
      } catch (_) {}
    }

    if (attempt != null) {
      final quiz = QuizEngine.getSampleQuiz(windowInfo: windowInfo);
      return {
        'quiz': quiz,
        'attempt': attempt,
        'status': QuizStatus.completed,
        'windowInfo': windowInfo,
      };
    }

    // Attempt fetching 10 random questions from Supabase quiz_questions or question_bank
    Quiz? quiz;
    try {
      List<dynamic> response = [];
      try {
        response = await _supabase.from('quiz_questions').select();
      } catch (_) {}

      if (response.isEmpty) {
        try {
          response = await _supabase.from('question_bank').select();
        } catch (_) {}
      }

      if (response.isNotEmpty && response.length >= 10) {
        final allDbQuestions = response.map((item) {
          final m = Map<String, dynamic>.from(item as Map);
          List<String> options = [];
          final rawOpt = m['options'];
          if (rawOpt is List) {
            options = List<String>.from(rawOpt);
          }
          return QuizQuestion(
            id: m['id'] as String? ?? 'q',
            category: m['category'] as String? ?? 'General',
            text: (m['question'] as String?) ?? (m['text'] as String?) ?? '',
            options: options,
            correctIndex:
                (m['correct_index'] as int?) ??
                (m['correctIndex'] as int?) ??
                0,
            explanation: (m['explanation'] as String?) ?? '',
          );
        }).toList();

        // Select 10 questions deterministically for this window session
        final rand = Random(windowInfo.windowId.hashCode);
        allDbQuestions.shuffle(rand);
        final selectedQuestions = allDbQuestions.take(10).toList();

        quiz = Quiz(
          id: windowInfo.windowId,
          title: 'Bi-Weekly Eco Quiz',
          topic: 'Sustainability & Carbon Science',
          questions: selectedQuestions,
          startTime: windowInfo.windowStart,
          endTime: windowInfo.windowEnd,
        );
      }
    } catch (_) {}

    // Fallback to client-side 50-question bank
    quiz ??= QuizEngine.getSampleQuiz(windowInfo: windowInfo);

    return {
      'quiz': quiz,
      'attempt': null,
      'status': QuizStatus.available,
      'windowInfo': windowInfo,
    };
  }

  /// Submit quiz attempt and award XP to user profile
  Future<void> submitQuizAttempt(
    String userId,
    QuizAttemptResult attempt,
    WidgetRef ref,
  ) async {
    // 0. Instantly record in local memory cache & persistent SharedPreferences
    final memoryKey = '$userId:${attempt.quizId}';
    _memoryQuizAttempts[memoryKey] = attempt;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'quiz_attempt_${userId}_${attempt.quizId}',
        jsonEncode(attempt.toJson()),
      );
    } catch (e) {
      debugPrint('Error saving quiz attempt to SharedPreferences: $e');
    }

    // 1. Try upserting attempt into user_quizzes table (silently catch errors if table missing)
    try {
      // Ensure parent quiz record exists to satisfy foreign key constraint user_quizzes_quiz_id_fkey
      try {
        await _supabase.from('quizzes').upsert({
          'id': _toUuid(attempt.quizId),
          'title': 'Bi-Weekly Eco Quiz',
        });
      } catch (_) {}

      await _supabase.from('user_quizzes').upsert({
        'user_id': userId,
        'quiz_id': _toUuid(attempt.quizId),
        'score': attempt.score,
        'total_questions': attempt.totalQuestions,
        'xp_earned': attempt.xpEarned,
        'is_perfect': attempt.isPerfect,
        'answers': attempt.answers,
        'completed_at': attempt.completedAt.toIso8601String(),
      });
    } catch (e) {
      debugPrint('Note: user_quizzes upsert skipped/failed: $e');
    }

    // 2. Award XP to User Profile (Always execute, even if user_quizzes table missing)
    try {
      final userRepo = ref.read(userRepositoryProvider);
      final profile = await userRepo.getUserProfile(userId);

      if (profile != null) {
        final currentLifetimeXp = profile.effectiveXp;
        final currentMonthlyXp = profile.monthlyXp;

        final newLifetimeXp = currentLifetimeXp + attempt.xpEarned;
        final newMonthlyXp = currentMonthlyXp + attempt.xpEarned;
        final newLevel = GamificationEngine.getLevelFromXp(newLifetimeXp);

        final updatedProfile = profile.copyWith(
          lifetimeXp: newLifetimeXp,
          monthlyXp: newMonthlyXp,
          xp: newLifetimeXp,
          level: newLevel,
        );

        await userRepo.saveUserProfile(updatedProfile);
      }
    } catch (e) {
      debugPrint('Error updating user profile XP for quiz: $e');
    }

    // 3. Check if Quiz Whiz badge is earned (5 perfect quiz scores as per Spec Section 7.2)
    if (attempt.isPerfect) {
      int perfectCount = 1;
      try {
        final countRes = await _supabase
            .from('user_quizzes')
            .select('id')
            .eq('user_id', userId)
            .eq('is_perfect', true);
        perfectCount = (countRes as List).length;
      } catch (_) {}

      if (perfectCount >= 5) {
        try {
          await _supabase.from('badges').upsert({
            'user_id': userId,
            'badge_name': 'Quiz Whiz 🧠',
            'category': 'Special',
            'earned_at': DateTime.now().toIso8601String(),
          }, onConflict: 'user_id, badge_name');
        } catch (_) {}
      }
    }

    // 4. Invalidate state to trigger UI updates for both Quiz status and User Profile XP
    ref.invalidate(activeQuizProvider(userId));
    ref.invalidate(userProfileProvider(userId));
  }
}
