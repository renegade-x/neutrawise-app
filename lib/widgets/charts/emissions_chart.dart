import 'dart:math';
import 'package:flutter/material.dart';
import 'package:neutrawise/domain/models/daily_log.dart';
import 'package:neutrawise/widgets/theme/app_colors.dart';

class EmissionsBreakdownChart extends StatelessWidget {
  final List<DailyLog> logs;
  final double baseline;
  final String title;

  const EmissionsBreakdownChart({
    super.key,
    required this.logs,
    required this.baseline,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildLegendItem('Transport', AppColors.primaryBlue),
              const SizedBox(width: 14),
              _buildLegendItem('Food', AppColors.primaryGreen),
              const SizedBox(width: 14),
              _buildLegendItem('Energy', AppColors.warning),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double calculatedWidth = logs.length <= 7
                    ? constraints.maxWidth
                    : max(constraints.maxWidth, logs.length * 42.0);

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: logs.length <= 7
                      ? const NeverScrollableScrollPhysics()
                      : const BouncingScrollPhysics(),
                  child: SizedBox(
                    width: calculatedWidth,
                    height: 180,
                    child: CustomPaint(
                      size: Size(calculatedWidth, 180),
                      painter: StackedBarChartPainter(
                        logs: logs,
                        baseline: baseline,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondaryDark,
            fontSize: 10,
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

    const double topMargin = 24.0;
    const double bottomMargin = 24.0;
    final double chartHeight = height - topMargin - bottomMargin;
    final double chartBottomY = height - bottomMargin;

    double maxLogVal = 0.0;
    for (var log in logs) {
      final totalCo2 = log.transportCo2 + log.foodCo2 + log.energyCo2;
      if (totalCo2 > maxLogVal) {
        maxLogVal = totalCo2;
      }
    }

    final double maxVal = max(max(baseline * 1.2, maxLogVal * 1.1), 10.0);

    final double baselineY =
        chartBottomY -
        ((baseline / maxVal) * chartHeight).clamp(0.0, chartHeight);
    final baselinePaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(0, baselineY),
      Offset(width, baselineY),
      baselinePaint,
    );

    final baselineText = TextPainter(
      text: TextSpan(
        text: 'Baseline (${baseline.toStringAsFixed(1)})',
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 9,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final double textY = (baselineY - 12).clamp(2.0, height - 36.0);
    baselineText.paint(canvas, Offset(6, textY));

    if (logs.isEmpty) return;

    final int count = logs.length;
    final double step = width / count;
    final double barWidth = (step * 0.55).clamp(10.0, 36.0);

    for (int i = 0; i < count; i++) {
      final log = logs[count - 1 - i];
      final double centerX = (i + 0.5) * step;
      final double leftX = centerX - barWidth / 2;

      final double transportH = ((log.transportCo2 / maxVal) * chartHeight)
          .clamp(0.0, chartHeight);
      final double foodH = ((log.foodCo2 / maxVal) * chartHeight).clamp(
        0.0,
        chartHeight,
      );
      final double energyH = ((log.energyCo2 / maxVal) * chartHeight).clamp(
        0.0,
        chartHeight,
      );

      double currentY = chartBottomY;

      // Transport
      if (transportH > 0) {
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(leftX, currentY - transportH, barWidth, transportH),
          const Radius.circular(2),
        );
        canvas.drawRRect(rect, Paint()..color = AppColors.primaryBlue);
        currentY -= transportH;
      }

      // Food
      if (foodH > 0) {
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(leftX, currentY - foodH, barWidth, foodH),
          const Radius.circular(2),
        );
        canvas.drawRRect(rect, Paint()..color = AppColors.primaryGreen);
        currentY -= foodH;
      }

      // Energy
      if (energyH > 0) {
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(leftX, currentY - energyH, barWidth, energyH),
          const Radius.circular(2),
        );
        canvas.drawRRect(rect, Paint()..color = AppColors.warning);
      }

      // Date label underneath bar
      final dateStr = log.date.length >= 10 ? log.date.substring(5) : log.date;
      final datePainter = TextPainter(
        text: TextSpan(
          text: dateStr,
          style: const TextStyle(
            color: AppColors.textSecondaryDark,
            fontSize: 9,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      datePainter.paint(
        canvas,
        Offset(centerX - datePainter.width / 2, height - 18),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
