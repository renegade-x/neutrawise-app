import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neutrawise/providers/auth_provider.dart';
import 'package:neutrawise/data/repositories/user_repository.dart';
import 'package:neutrawise/data/repositories/activity_repository.dart';
import 'package:neutrawise/domain/models/daily_log.dart';
import 'package:neutrawise/widgets/theme/app_colors.dart';
import 'package:neutrawise/features/activity/screens/activity_log_sheet.dart';

final recentLogsProvider = StreamProvider.family<List<DailyLog>, String>((
  ref,
  userId,
) {
  return ref.watch(activityRepositoryProvider).watchRecentLogs(userId);
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final profileAsync = ref.watch(userProfileProvider(user.id));
    final logsAsync = ref.watch(recentLogsProvider(user.id));

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(authProvider.notifier).signOut();
            },
          ),
          IconButton(icon: const Icon(Icons.settings), onPressed: () {}),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Profile not found'));
          }

          return logsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Error loading logs: $e')),
            data: (logs) {
              final todayLog = logs
                  .where(
                    (l) =>
                        l.date ==
                        DateTime.now().toIso8601String().substring(0, 10),
                  )
                  .firstOrNull;

              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hello, ${profile.name}',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Let's make an impact today.",
                                style: TextStyle(
                                  color: AppColors.textSecondaryDark,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceDark,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.warning.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.local_fire_department,
                                  color: AppColors.warning,
                                  size: 20,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${profile.currentStreak}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.warning,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Ring Chart
                      Center(
                        child: CustomPaint(
                          size: const Size(220, 220),
                          painter: RingChartPainter(
                            transportCo2: todayLog?.transportCo2 ?? 0,
                            foodCo2: todayLog?.foodCo2 ?? 0,
                            energyCo2: todayLog?.energyCo2 ?? 0,
                            baseline: profile.totalDailyBaselineCo2 ?? 1.0,
                          ),
                          child: SizedBox(
                            width: 220,
                            height: 220,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  (todayLog?.totalDailyCo2 ?? 0)
                                      .toStringAsFixed(1),
                                  style: Theme.of(context)
                                      .textTheme
                                      .displayMedium
                                      ?.copyWith(fontSize: 48),
                                ),
                                const Text(
                                  'kg CO₂e',
                                  style: TextStyle(fontSize: 14),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'vs ${(profile.totalDailyBaselineCo2 ?? 0).toStringAsFixed(1)} avg',
                                  style: TextStyle(
                                    color: AppColors.textSecondaryDark,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Category Cards
                      Row(
                        children: [
                          Expanded(
                            child: _CategoryCard(
                              title: 'Transport',
                              co2: todayLog?.transportCo2 ?? 0,
                              icon: Icons.directions_car,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _CategoryCard(
                              title: 'Food',
                              co2: todayLog?.foodCo2 ?? 0,
                              icon: Icons.restaurant,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _CategoryCard(
                              title: 'Energy',
                              co2: todayLog?.energyCo2 ?? 0,
                              icon: Icons.bolt,
                              color: AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: logsAsync.maybeWhen(
        data: (logs) {
          final todayLog = logs
              .where(
                (l) =>
                    l.date == DateTime.now().toIso8601String().substring(0, 10),
              )
              .firstOrNull;
          return FloatingActionButton(
            backgroundColor: AppColors.primaryGreen,
            child: const Icon(Icons.add, color: Colors.white),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: AppColors.backgroundDark,
                builder: (context) => ActivityLogSheet(existingLog: todayLog),
              );
            },
          );
        },
        orElse: () => FloatingActionButton(
          backgroundColor: AppColors.primaryGreen,
          child: const Icon(Icons.add, color: Colors.white),
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: AppColors.backgroundDark,
              builder: (context) => const ActivityLogSheet(),
            );
          },
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String title;
  final double co2;
  final IconData icon;
  final Color color;

  const _CategoryCard({
    required this.title,
    required this.co2,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            '${co2.toStringAsFixed(1)} kg',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class RingChartPainter extends CustomPainter {
  final double transportCo2;
  final double foodCo2;
  final double energyCo2;
  final double baseline;

  RingChartPainter({
    required this.transportCo2,
    required this.foodCo2,
    required this.energyCo2,
    required this.baseline,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 20.0;

    final paintBg = Paint()
      ..color = AppColors.surfaceDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, paintBg);

    final total = transportCo2 + foodCo2 + energyCo2;
    if (total == 0) return;

    // We scale the ring such that 1 full circle = baseline.
    // If total > baseline, we cap at 1 full circle for visual simplicity (or overflow).
    // Actually, let's just make the segments proportional to the total if over baseline,
    // and if under baseline, the unfilled part is baseline - total.

    double startAngle = -pi / 2;
    final sweepTotal = (total / baseline).clamp(0.0, 1.0) * 2 * pi;

    void drawSegment(double co2, Color color) {
      if (co2 == 0) return;
      final sweepAngle = (co2 / total) * sweepTotal;
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
      startAngle += sweepAngle;
    }

    drawSegment(transportCo2, AppColors.primaryBlue);
    drawSegment(foodCo2, AppColors.primaryGreen);
    drawSegment(energyCo2, AppColors.warning);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
