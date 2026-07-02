import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:confetti/confetti.dart';
import 'package:neutrawise/widgets/theme/app_colors.dart';

class CelebrationModal extends StatefulWidget {
  final String title;
  final String description;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final int? xpReward;
  final bool fullScreenConfetti;

  const CelebrationModal({
    super.key,
    required this.title,
    required this.description,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    this.xpReward,
    this.fullScreenConfetti = false,
  });

  static void showLevelUp(BuildContext context, int level, String levelTitle) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CelebrationModal(
        title: "LEVEL UP!",
        subtitle: "Level $level",
        description: "You've unlocked the title \"$levelTitle\"!",
        icon: Icons.upgrade,
        iconColor: AppColors.primaryGreen,
        fullScreenConfetti: true,
      ),
    );
  }

  static void showBadgeEarned(BuildContext context, String badgeName, String badgeDesc) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CelebrationModal(
        title: "NEW BADGE EARNED!",
        subtitle: badgeName,
        description: badgeDesc,
        icon: Icons.military_tech,
        iconColor: AppColors.warning,
        fullScreenConfetti: false,
      ),
    );
  }

  static void showChallengeComplete(BuildContext context, String challengeName, int xpReward) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CelebrationModal(
        title: "CHALLENGE COMPLETE!",
        subtitle: challengeName,
        description: "Excellent effort! You have successfully completed this eco challenge.",
        icon: Icons.emoji_events,
        iconColor: AppColors.primaryBlue,
        xpReward: xpReward,
        fullScreenConfetti: false,
      ),
    );
  }

  @override
  State<CelebrationModal> createState() => _CelebrationModalState();
}

class _CelebrationModalState extends State<CelebrationModal> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _confettiController.play();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background Card with Glassmorphism and glow
          Container(
            padding: const EdgeInsets.all(28.0),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: widget.iconColor.withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.iconColor.withValues(alpha: 0.15),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                // Glowing Icon with animation
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: widget.iconColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.iconColor.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    widget.icon,
                    size: 64,
                    color: widget.iconColor,
                  ),
                )
                    .animate(onPlay: (controller) => controller.repeat())
                    .shimmer(delay: 500.ms, duration: 1800.ms)
                    .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1), duration: 1000.ms, curve: Curves.easeInOutSine)
                    .then()
                    .scale(begin: const Offset(1.1, 1.1), end: const Offset(0.9, 0.9), duration: 1000.ms, curve: Curves.easeInOutSine),
                const SizedBox(height: 24),
                // Title
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: widget.iconColor,
                  ),
                ).animate().fade(duration: 400.ms).scale(delay: 100.ms),
                const SizedBox(height: 8),
                // Subtitle
                Text(
                  widget.subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ).animate().fade(delay: 200.ms, duration: 400.ms).slideY(begin: 0.2, end: 0.0),
                const SizedBox(height: 16),
                // Description
                Text(
                  widget.description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondaryDark,
                    height: 1.4,
                  ),
                ).animate().fade(delay: 300.ms, duration: 400.ms),
                const SizedBox(height: 24),
                // XP Reward counter / visual pop
                if (widget.xpReward != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      "+${widget.xpReward} XP",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  )
                      .animate()
                      .scale(delay: 500.ms, duration: 400.ms, curve: Curves.elasticOut)
                      .shake(delay: 900.ms, hz: 4),
                const SizedBox(height: 24),
                // Close button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.iconColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text(
                      "Awesome!",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ).animate().fade(delay: 400.ms).slideY(begin: 0.2, end: 0.0),
              ],
            ),
          ),
          // Confetti overlay
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                Colors.green,
                Colors.blue,
                Colors.orange,
                Colors.yellow,
                Colors.pink,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
