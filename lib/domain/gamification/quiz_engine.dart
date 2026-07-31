enum QuizStatus { available, completed, expired }

class QuizQuestion {
  final String id;
  final String text;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  const QuizQuestion({
    required this.id,
    required this.text,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      id: json['id'] as String? ?? '',
      text: json['text'] as String? ?? '',
      options: List<String>.from(json['options'] as List? ?? []),
      correctIndex: json['correctIndex'] as int? ?? 0,
      explanation: json['explanation'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'options': options,
      'correctIndex': correctIndex,
      'explanation': explanation,
    };
  }
}

class Quiz {
  final String id;
  final String title;
  final String topic;
  final List<QuizQuestion> questions;
  final DateTime startTime;
  final DateTime endTime;

  const Quiz({
    required this.id,
    required this.title,
    required this.topic,
    required this.questions,
    required this.startTime,
    required this.endTime,
  });

  factory Quiz.fromJson(Map<String, dynamic> json) {
    return Quiz(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Bi-Weekly Eco Quiz',
      topic: json['topic'] as String? ?? 'General Sustainability',
      questions: (json['questions'] as List? ?? [])
          .map((q) => QuizQuestion.fromJson(q as Map<String, dynamic>))
          .toList(),
      startTime:
          DateTime.tryParse(json['start_time'] as String? ?? '') ??
          DateTime.now().subtract(const Duration(hours: 1)),
      endTime:
          DateTime.tryParse(json['end_time'] as String? ?? '') ??
          DateTime.now().add(const Duration(hours: 47)),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'topic': topic,
      'questions': questions.map((q) => q.toJson()).toList(),
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
    };
  }
}

class QuizAttemptResult {
  final String quizId;
  final String userId;
  final int score;
  final int totalQuestions;
  final int xpEarned;
  final bool isPerfect;
  final List<int> answers;
  final DateTime completedAt;

  const QuizAttemptResult({
    required this.quizId,
    required this.userId,
    required this.score,
    required this.totalQuestions,
    required this.xpEarned,
    required this.isPerfect,
    required this.answers,
    required this.completedAt,
  });

  factory QuizAttemptResult.fromJson(Map<String, dynamic> json) {
    return QuizAttemptResult(
      quizId: json['quiz_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      score: json['score'] as int? ?? 0,
      totalQuestions: json['total_questions'] as int? ?? 0,
      xpEarned: json['xp_earned'] as int? ?? 0,
      isPerfect: json['is_perfect'] as bool? ?? false,
      answers: List<int>.from(json['answers'] as List? ?? []),
      completedAt:
          DateTime.tryParse(json['completed_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'quiz_id': quizId,
      'user_id': userId,
      'score': score,
      'total_questions': totalQuestions,
      'xp_earned': xpEarned,
      'is_perfect': isPerfect,
      'answers': answers,
      'completed_at': completedAt.toIso8601String(),
    };
  }
}

class QuizEngine {
  /// Calculate XP earned for a quiz attempt:
  /// - Base attempt XP: 30 XP
  /// - Per correct answer: +5 XP per question
  /// - Perfect score bonus (all correct): +50 XP
  ///
  /// Example for 10 questions: 30 + 50 + 50 = 130 XP
  /// Example for 5 questions: 30 + 25 + 50 = 105 XP
  static Map<String, dynamic> calculateQuizXp({
    required int score,
    required int totalQuestions,
  }) {
    const baseAttemptXp = 30;
    final perQuestionBonus = score * 5;
    final isPerfect = score > 0 && score == totalQuestions;
    final perfectBonus = isPerfect ? 50 : 0;

    final totalXp = baseAttemptXp + perQuestionBonus + perfectBonus;

    return {
      'baseAttemptXp': baseAttemptXp,
      'perQuestionBonus': perQuestionBonus,
      'perfectBonus': perfectBonus,
      'totalXp': totalXp,
      'isPerfect': isPerfect,
    };
  }

  /// Determine quiz status based on quiz timing and user's completion record
  static QuizStatus getQuizStatus({
    required Quiz quiz,
    required DateTime? completedAt,
    required DateTime now,
  }) {
    if (completedAt != null) {
      return QuizStatus.completed;
    }
    if (now.isBefore(quiz.startTime) || now.isAfter(quiz.endTime)) {
      return QuizStatus.expired;
    }
    return QuizStatus.available;
  }

  /// Remaining duration in the 48-hour availability window
  static Duration getRemainingWindowDuration({
    required Quiz quiz,
    required DateTime now,
  }) {
    if (now.isAfter(quiz.endTime)) {
      return Duration.zero;
    }
    return quiz.endTime.difference(now);
  }

  /// Generate sample fallback quiz questions for offline or test environments
  static Quiz getSampleQuiz({DateTime? startTime}) {
    final start = startTime ?? _getLatestQuizStartTime(DateTime.now());
    final end = start.add(const Duration(hours: 48));

    return Quiz(
      id: 'sample_eco_quiz_${start.millisecondsSinceEpoch}',
      title: 'Bi-Weekly Eco Quiz',
      topic: 'Sustainability & Carbon Footprint',
      questions: const [
        QuizQuestion(
          id: 'q1',
          text: 'Which vehicle type produces the least CO₂ per km?',
          options: [
            'Petrol car',
            'Diesel car',
            'Electric vehicle',
            'Motorcycle',
          ],
          correctIndex: 2,
          explanation:
              'EVs emit 0 direct tailpipe emissions and significantly lower lifecycle CO₂.',
        ),
        QuizQuestion(
          id: 'q2',
          text: 'Which food has the highest carbon footprint per 100g?',
          options: ['Lentils', 'Chicken', 'Beef', 'Tofu'],
          correctIndex: 2,
          explanation:
              'Beef generates over 20-30x more greenhouse gases per 100g than plant proteins.',
        ),
        QuizQuestion(
          id: 'q3',
          text: 'What does "phantom load" mean in household energy?',
          options: [
            'Energy lost in transmission',
            'Electricity consumed by devices on standby',
            'Peak usage during hot days',
            'Solar inverter loss',
          ],
          correctIndex: 1,
          explanation:
              'Standby power draw from plugged-in appliances accounts for up to 10% of home energy.',
        ),
        QuizQuestion(
          id: 'q4',
          text:
              'What is the primary greenhouse gas emitted by human activities?',
          options: ['Oxygen', 'Methane', 'Carbon Dioxide (CO₂)', 'Nitrogen'],
          correctIndex: 2,
          explanation:
              'CO₂ makes up over 75% of global human-caused greenhouse gas emissions.',
        ),
        QuizQuestion(
          id: 'q5',
          text:
              'Lowering your thermostat by 1°C can reduce heating bills by approx:',
          options: ['0.5%', '10%', '30%', '50%'],
          correctIndex: 1,
          explanation:
              'Each 1°C reduction saves approximately 10% on annual space heating emissions and costs.',
        ),
      ],
      startTime: start,
      endTime: end,
    );
  }

  /// Helper to derive the latest Tuesday or Friday 9:00 AM start time
  static DateTime _getLatestQuizStartTime(DateTime now) {
    var candidate = DateTime(now.year, now.month, now.day, 9, 0);
    while (candidate.isAfter(now)) {
      candidate = candidate.subtract(const Duration(days: 1));
    }
    while (candidate.weekday != DateTime.tuesday &&
        candidate.weekday != DateTime.friday) {
      candidate = candidate.subtract(const Duration(days: 1));
    }
    return candidate;
  }
}
