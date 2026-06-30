import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neutrawise/providers/auth_provider.dart';
import 'package:neutrawise/data/repositories/user_repository.dart';
import 'package:neutrawise/domain/models/daily_log.dart';
import 'package:neutrawise/widgets/theme/app_colors.dart';
import 'package:neutrawise/features/dashboard/screens/dashboard_screen.dart';

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  String _timeRange = 'Week'; // 'Week' or 'Month'

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final profileAsync = ref.watch(userProfileProvider(user.id));
    final logsAsync = ref.watch(recentLogsProvider(user.id));

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(color: AppColors.backgroundDark),
        child: SafeArea(
          child: profileAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Error: $e')),
            data: (profile) {
              if (profile == null) {
                return const Center(child: Text('Profile not found'));
              }

              return logsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(child: Text('Error: $e')),
                data: (logs) {
                  // Calculate insights based on range
                  final double baseline = profile.totalDailyBaselineCo2 ?? 15.0;
                  final recentLogs = logs
                      .take(_timeRange == 'Week' ? 7 : 30)
                      .toList();

                  double totalSaved = 0.0;
                  double totalEmitted = 0.0;
                  double totalTransport = 0.0;
                  double totalFood = 0.0;
                  double totalEnergy = 0.0;

                  for (var log in recentLogs) {
                    totalSaved += log.co2SavedVsBaseline;
                    totalEmitted += log.totalDailyCo2;
                    totalTransport += log.transportCo2;
                    totalFood += log.foodCo2;
                    totalEnergy += log.energyCo2;
                  }

                  final double avgSaved = recentLogs.isNotEmpty
                      ? totalSaved / recentLogs.length
                      : 0.0;
                  final double avgEmitted = recentLogs.isNotEmpty
                      ? totalEmitted / recentLogs.length
                      : 0.0;
                  final double improvementPercent = baseline > 0
                      ? (avgSaved / baseline) * 100
                      : 0.0;

                  // CO2 Equivalences (only shown if positive saved)
                  final double treesAbsorbed = totalSaved > 0
                      ? totalSaved / 0.0603
                      : 0.0;
                  final double carKm = totalSaved > 0 ? totalSaved / 0.18 : 0.0;
                  final double phoneCharges = totalSaved > 0
                      ? totalSaved / 0.008
                      : 0.0;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Insights',
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                            ),
                            // Toggle
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceDark,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: ['Week', 'Month'].map((range) {
                                  final isSelected = _timeRange == range;
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _timeRange = range;
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppColors.primaryGreen
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        range,
                                        style: TextStyle(
                                          color: isSelected
                                              ? Colors.white
                                              : AppColors.textSecondaryDark,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Performance Callout Card
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: improvementPercent >= 0
                                  ? [
                                      AppColors.primaryGreen.withValues(
                                        alpha: 0.15,
                                      ),
                                      AppColors.primaryGreen.withValues(
                                        alpha: 0.05,
                                      ),
                                    ]
                                  : [
                                      AppColors.warning.withValues(alpha: 0.15),
                                      AppColors.warning.withValues(alpha: 0.05),
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: improvementPercent >= 0
                                  ? AppColors.primaryGreen.withValues(
                                      alpha: 0.3,
                                    )
                                  : AppColors.warning.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                improvementPercent >= 0
                                    ? Icons.trending_up
                                    : Icons.trending_down,
                                color: improvementPercent >= 0
                                    ? AppColors.primaryGreen
                                    : AppColors.warning,
                                size: 36,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      improvementPercent >= 0
                                          ? 'You improved by ${improvementPercent.toStringAsFixed(1)}%'
                                          : 'Emissions higher by ${improvementPercent.abs().toStringAsFixed(1)}%',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Average daily emissions are ${avgEmitted.toStringAsFixed(1)} kg CO₂e compared to baseline ${baseline.toStringAsFixed(1)} kg.',
                                      style: const TextStyle(
                                        color: AppColors.textSecondaryDark,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Stacked Trend Chart
                        const Text(
                          'Emissions Breakdown',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          height: 220,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceDark,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.05),
                            ),
                          ),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final double totalChartWidth = max(
                                constraints.maxWidth,
                                recentLogs.length * 60.0,
                              );
                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: SizedBox(
                                    width:
                                        totalChartWidth -
                                        32, // account for padding
                                    child: CustomPaint(
                                      size: Size.infinite,
                                      painter: StackedBarChartPainter(
                                        logs: recentLogs,
                                        baseline: baseline,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Monthly Target progress
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceDark,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.05),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Monthly Target',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Target: 20% reduction',
                                      style: TextStyle(
                                        color: AppColors.textSecondaryDark,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Achieved: ${max(0.0, improvementPercent).toStringAsFixed(1)}%',
                                      style: const TextStyle(
                                        color: AppColors.primaryGreen,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: 70,
                                height: 70,
                                child: CustomPaint(
                                  painter: TargetProgressPainter(
                                    progress: (improvementPercent / 20.0).clamp(
                                      0.0,
                                      1.0,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${min(100, (improvementPercent * 5).round()).clamp(0, 100)}%',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // CO2 Equivalences
                        if (totalSaved > 0) ...[
                          const Text(
                            'Your Positive Impact',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildEquivalenceCard(
                                  Icons.eco,
                                  'Tree Days',
                                  treesAbsorbed.toStringAsFixed(1),
                                  'Absorbed',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildEquivalenceCard(
                                  Icons.directions_car,
                                  'Car km',
                                  carKm.toStringAsFixed(1),
                                  'Avoided',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildEquivalenceCard(
                                  Icons.bolt,
                                  'Phone Charges',
                                  phoneCharges.toStringAsFixed(0),
                                  'Saved',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Emissions table by Category
                        const Text(
                          'Category Summary',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.surfaceDark,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Table(
                            columnWidths: const {
                              0: FlexColumnWidth(2),
                              1: FlexColumnWidth(1),
                              2: FlexColumnWidth(1),
                            },
                            children: [
                              _buildTableHeader(),
                              _buildTableRow(
                                'Transport',
                                totalTransport,
                                AppColors.primaryBlue,
                              ),
                              _buildTableRow(
                                'Food',
                                totalFood,
                                AppColors.primaryGreen,
                              ),
                              _buildTableRow(
                                'Energy',
                                totalEnergy,
                                AppColors.warning,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEquivalenceCard(
    IconData icon,
    String title,
    String value,
    String unit,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primaryGreen, size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondaryDark,
            ),
          ),
          Text(
            unit,
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textSecondaryDark.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  TableRow _buildTableHeader() {
    return const TableRow(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      children: [
        Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Category',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'CO₂e (kg)',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            textAlign: TextAlign.right,
          ),
        ),
        Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            '% Share',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  TableRow _buildTableRow(String category, double co2, Color color) {
    return TableRow(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(category, style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            co2.toStringAsFixed(1),
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.right,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            co2 > 0 ? '${(co2 / (co2 + 1) * 100).toStringAsFixed(0)}%' : '0%',
            style: const TextStyle(color: AppColors.textSecondaryDark),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class StackedBarChartPainter extends CustomPainter {
  final List<DailyLog> logs;
  final double baseline;

  StackedBarChartPainter({required this.logs, required this.baseline});

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;
    final double chartHeight = height - 20;

    // Draw baseline
    final baselinePaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Find the maximum total emission value in logs to scale dynamically
    double maxLogVal = 0.0;
    for (var log in logs) {
      final totalCo2 = log.transportCo2 + log.foodCo2 + log.energyCo2;
      if (totalCo2 > maxLogVal) {
        maxLogVal = totalCo2;
      }
    }
    final double maxVal = max(max(baseline * 1.5, maxLogVal * 1.1), 30.0);
    final double baselineY = chartHeight - (baseline / maxVal) * chartHeight;

    // Draw horizontal guidelines
    canvas.drawLine(
      Offset(0, baselineY),
      Offset(width, baselineY),
      baselinePaint,
    );

    // Text for baseline
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'Baseline (${baseline.toStringAsFixed(1)})',
        style: const TextStyle(color: Colors.white30, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(8, baselineY - 14));

    if (logs.isEmpty) return;

    final double barSpacing = width / (logs.length * 2);
    final double barWidth = width / (logs.length * 1.8);

    for (int i = 0; i < logs.length; i++) {
      final log = logs[logs.length - 1 - i];
      final double x = barSpacing + i * (barWidth + barSpacing);

      // Stack: Transport (bottom), Food (middle), Energy (top)
      final double transportH = (log.transportCo2 / maxVal) * chartHeight;
      final double foodH = (log.foodCo2 / maxVal) * chartHeight;
      final double energyH = (log.energyCo2 / maxVal) * chartHeight;

      double currentY = chartHeight;

      // Draw Transport segment
      if (transportH > 0) {
        final rect = Rect.fromLTWH(
          x,
          currentY - transportH,
          barWidth,
          transportH,
        );
        canvas.drawRect(rect, Paint()..color = AppColors.primaryBlue);
        currentY -= transportH;
      }

      // Draw Food segment
      if (foodH > 0) {
        final rect = Rect.fromLTWH(x, currentY - foodH, barWidth, foodH);
        canvas.drawRect(rect, Paint()..color = AppColors.primaryGreen);
        currentY -= foodH;
      }

      // Draw Energy segment
      if (energyH > 0) {
        final rect = Rect.fromLTWH(x, currentY - energyH, barWidth, energyH);
        canvas.drawRect(rect, Paint()..color = AppColors.warning);
      }

      // Labels below the bars
      final dateStr = log.date.substring(5); // e.g. 05-24
      final datePainter = TextPainter(
        text: TextSpan(
          text: dateStr,
          style: const TextStyle(
            color: AppColors.textSecondaryDark,
            fontSize: 8,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      datePainter.paint(
        canvas,
        Offset(x + (barWidth - datePainter.width) / 2, height - 12),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class TargetProgressPainter extends CustomPainter {
  final double progress;

  TargetProgressPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paintBg = Paint()
      ..color = Colors.white10
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke;

    final paintProgress = Paint()
      ..color = AppColors.primaryGreen
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, radius, paintBg);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      paintProgress,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
