import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neutrawise/widgets/theme/app_colors.dart';
import 'package:neutrawise/domain/gamification/quiz_engine.dart';
import 'package:neutrawise/data/repositories/quiz_repository.dart';

class QuizModal extends ConsumerStatefulWidget {
  final String userId;
  final Quiz quiz;

  const QuizModal({super.key, required this.userId, required this.quiz});

  static Future<void> show(BuildContext context, String userId, Quiz quiz) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => QuizModal(userId: userId, quiz: quiz),
    );
  }

  @override
  ConsumerState<QuizModal> createState() => _QuizModalState();
}

class _QuizModalState extends ConsumerState<QuizModal> {
  int _currentIndex = 0;
  final List<int> _userAnswers = [];
  int? _selectedOptionIndex;
  bool _isAnswerSubmitted = false;
  bool _isFinished = false;

  void _onOptionSelected(int index) {
    if (_isAnswerSubmitted) return;
    setState(() {
      _selectedOptionIndex = index;
    });
  }

  void _submitCurrentAnswer() {
    if (_selectedOptionIndex == null) return;
    setState(() {
      _isAnswerSubmitted = true;
      _userAnswers.add(_selectedOptionIndex!);
    });
  }

  void _nextQuestion() {
    if (_currentIndex < widget.quiz.questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedOptionIndex = null;
        _isAnswerSubmitted = false;
      });
    } else {
      setState(() {
        _isFinished = true;
      });
    }
  }

  int _calculateScore() {
    int score = 0;
    for (int i = 0; i < widget.quiz.questions.length; i++) {
      if (i < _userAnswers.length &&
          _userAnswers[i] == widget.quiz.questions[i].correctIndex) {
        score++;
      }
    }
    return score;
  }

  Future<void> _completeQuiz(
    int score,
    Map<String, dynamic> xpBreakdown,
  ) async {
    final attempt = QuizAttemptResult(
      quizId: widget.quiz.id,
      userId: widget.userId,
      score: score,
      totalQuestions: widget.quiz.questions.length,
      xpEarned: xpBreakdown['totalXp'] as int,
      isPerfect: xpBreakdown['isPerfect'] as bool,
      answers: _userAnswers,
      completedAt: DateTime.now(),
    );

    await ref
        .read(quizRepositoryProvider)
        .submitQuizAttempt(widget.userId, attempt, ref);

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return Container(
      height: mediaQuery.size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.backgroundDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: mediaQuery.viewInsets.bottom + 20,
      ),
      child: _isFinished ? _buildResultsView() : _buildQuestionView(),
    );
  }

  Widget _buildQuestionView() {
    final question = widget.quiz.questions[_currentIndex];
    final totalQuestions = widget.quiz.questions.length;
    final progress = (_currentIndex + 1) / totalQuestions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Drag Handle & Title
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[700],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.quiz.title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.grey),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),

        // Progress Bar & Step Indicator
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppColors.surfaceDark,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.primaryGreen,
                  ),
                  minHeight: 8,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${_currentIndex + 1}/$totalQuestions',
              style: const TextStyle(
                color: AppColors.textSecondaryDark,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Question Card
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primaryGreen.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    question.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Options List
                ...List.generate(question.options.length, (index) {
                  final optionText = question.options[index];
                  final isSelected = _selectedOptionIndex == index;
                  final isCorrect = index == question.correctIndex;

                  Color optionColor = AppColors.surfaceDark;
                  Color borderColor = Colors.transparent;
                  IconData? iconData;

                  if (_isAnswerSubmitted) {
                    if (isCorrect) {
                      optionColor = AppColors.primaryGreen.withValues(
                        alpha: 0.2,
                      );
                      borderColor = AppColors.primaryGreen;
                      iconData = Icons.check_circle;
                    } else if (isSelected && !isCorrect) {
                      optionColor = Colors.redAccent.withValues(alpha: 0.2);
                      borderColor = Colors.redAccent;
                      iconData = Icons.cancel;
                    }
                  } else if (isSelected) {
                    optionColor = AppColors.primaryGreen.withValues(
                      alpha: 0.15,
                    );
                    borderColor = AppColors.primaryGreen;
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () => _onOptionSelected(index),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: optionColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: borderColor != Colors.transparent
                                ? borderColor
                                : Colors.grey.withValues(alpha: 0.2),
                            width: borderColor != Colors.transparent ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              '${String.fromCharCode(65 + index)}.',
                              style: TextStyle(
                                color: isSelected
                                    ? AppColors.primaryGreen
                                    : AppColors.textSecondaryDark,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                optionText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            if (iconData != null)
                              Icon(
                                iconData,
                                color: isCorrect
                                    ? AppColors.primaryGreen
                                    : Colors.redAccent,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

                // Explanation Card (Post-answer submission)
                if (_isAnswerSubmitted) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primaryGreen.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.lightbulb,
                          color: AppColors.primaryGreen,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            question.explanation,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Action Button
        const SizedBox(height: 12),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryGreen,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _selectedOptionIndex == null
              ? null
              : (_isAnswerSubmitted ? _nextQuestion : _submitCurrentAnswer),
          child: Text(
            !_isAnswerSubmitted
                ? 'Check Answer'
                : (_currentIndex < totalQuestions - 1
                      ? 'Next Question'
                      : 'See Results'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildResultsView() {
    final score = _calculateScore();
    final totalQuestions = widget.quiz.questions.length;
    final xpBreakdown = QuizEngine.calculateQuizXp(
      score: score,
      totalQuestions: totalQuestions,
    );
    final totalXp = xpBreakdown['totalXp'] as int;
    final isPerfect = xpBreakdown['isPerfect'] as bool;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          isPerfect ? Icons.workspace_premium : Icons.stars,
          size: 72,
          color: isPerfect ? Colors.amber : AppColors.primaryGreen,
        ),
        const SizedBox(height: 16),
        Text(
          isPerfect ? 'Perfect Quiz Score! 🌟' : 'Quiz Completed! 🧠',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'You scored $score out of $totalQuestions correct',
          style: const TextStyle(
            color: AppColors.textSecondaryDark,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 24),

        // XP Breakdown Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primaryGreen.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              _buildXpRow(
                'Quiz Attempt',
                '+${xpBreakdown['baseAttemptXp']} XP',
              ),
              const SizedBox(height: 10),
              _buildXpRow(
                'Correct Answers ($score)',
                '+${xpBreakdown['perQuestionBonus']} XP',
              ),
              if (isPerfect) ...[
                const SizedBox(height: 10),
                _buildXpRow(
                  'Perfect Score Bonus 🌟',
                  '+${xpBreakdown['perfectBonus']} XP',
                  isBonus: true,
                ),
              ],
              const Divider(color: Colors.grey, height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total XP Earned',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '+$totalXp XP',
                    style: const TextStyle(
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => _completeQuiz(score, xpBreakdown),
            child: const Text(
              'Claim XP & Close',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildXpRow(String label, String xpText, {bool isBonus = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isBonus ? Colors.amber : Colors.grey[300],
            fontSize: 14,
            fontWeight: isBonus ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          xpText,
          style: TextStyle(
            color: isBonus ? Colors.amber : AppColors.primaryGreen,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
