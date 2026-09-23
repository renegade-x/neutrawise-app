import 'package:flutter/material.dart';
import 'package:neutrawise/widgets/theme/app_colors.dart';

class GoogleSignInButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;

  const GoogleSignInButton({
    super.key,
    this.text = 'Continue with Google',
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF3E3E3E) : const Color(0xFFDADCE0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: isLoading ? null : onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: isLoading
                ? const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primaryGreen,
                        ),
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const _GoogleLogo(size: 22),
                      const SizedBox(width: 12),
                      Text(
                        text,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF3C4043),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Precise custom painter for Google 4-color 'G' brand logo
class _GoogleLogo extends StatelessWidget {
  final double size;

  const _GoogleLogo({this.size = 24});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Google Brand Colors
    final red = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.fill;
    final blue = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    final green = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.fill;
    final yellow = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.fill;

    final center = Offset(w * 0.5, h * 0.5);
    final radius = w * 0.48;
    final innerRadius = w * 0.26;

    // Blue section (Right bar and top-right curve)
    final bluePath = Path()
      ..moveTo(center.dx + radius, center.dy)
      ..lineTo(center.dx + radius, center.dy - radius * 0.05)
      ..arcTo(Rect.fromCircle(center: center, radius: radius), 0, -0.85, false)
      ..lineTo(center.dx + innerRadius * 0.7, center.dy - innerRadius * 0.7)
      ..arcTo(
        Rect.fromCircle(center: center, radius: innerRadius),
        -0.85,
        0.85,
        false,
      )
      ..lineTo(center.dx, center.dy - radius * 0.18)
      ..lineTo(center.dx + radius * 0.95, center.dy - radius * 0.18)
      ..lineTo(center.dx + radius * 0.95, center.dy + radius * 0.18)
      ..lineTo(center.dx, center.dy + radius * 0.18)
      ..close();
    canvas.drawPath(bluePath, blue);

    // Red section (Top arc)
    final redPath = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..arcTo(
        Rect.fromCircle(center: center, radius: radius),
        -1.57,
        1.15,
        false,
      )
      ..lineTo(center.dx + innerRadius * 0.75, center.dy - innerRadius * 0.65)
      ..arcTo(
        Rect.fromCircle(center: center, radius: innerRadius),
        -0.42,
        -1.15,
        false,
      )
      ..close();
    canvas.drawPath(redPath, red);

    // Yellow section (Left-top arc)
    final yellowPath = Path()
      ..moveTo(center.dx - radius, center.dy)
      ..arcTo(
        Rect.fromCircle(center: center, radius: radius),
        3.14,
        0.75,
        false,
      )
      ..lineTo(center.dx - innerRadius * 0.7, center.dy - innerRadius * 0.7)
      ..arcTo(
        Rect.fromCircle(center: center, radius: innerRadius),
        3.89,
        -0.75,
        false,
      )
      ..close();
    canvas.drawPath(yellowPath, yellow);

    // Green section (Bottom arc)
    final greenPath = Path()
      ..moveTo(center.dx, center.dy + radius)
      ..arcTo(
        Rect.fromCircle(center: center, radius: radius),
        1.57,
        1.57,
        false,
      )
      ..lineTo(center.dx - innerRadius, center.dy)
      ..arcTo(
        Rect.fromCircle(center: center, radius: innerRadius),
        3.14,
        -1.57,
        false,
      )
      ..arcTo(
        Rect.fromCircle(center: center, radius: innerRadius),
        1.57,
        -0.75,
        false,
      )
      ..lineTo(center.dx + radius * 0.72, center.dy + radius * 0.68)
      ..arcTo(
        Rect.fromCircle(center: center, radius: radius),
        0.82,
        0.75,
        false,
      )
      ..close();
    canvas.drawPath(greenPath, green);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
