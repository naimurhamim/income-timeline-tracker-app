import 'dart:math';
import 'package:flutter/material.dart';

class BlobPainter extends CustomPainter {
  final Color color1;
  final Color color2;
  final Color color3;
  final double animationValue;

  BlobPainter({
    required this.color1,
    required this.color2,
    required this.color3,
    this.animationValue = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Large circle (like the reference image)
    final paint1 = Paint()
      ..color = color1.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width * 0.25, size.height * 0.5),
      size.width * 0.35 + sin(animationValue) * 5,
      paint1,
    );

    // Medium circle (lavender-like)
    final paint2 = Paint()
      ..color = color2.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width * 0.45, size.height * 0.35),
      size.width * 0.2 + cos(animationValue) * 3,
      paint2,
    );

    // Small accent circle
    final paint3 = Paint()
      ..color = color3.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width * 0.7, size.height * 0.25),
      size.width * 0.08 + sin(animationValue * 1.5) * 2,
      paint3,
    );

    // Tiny diamond shape
    final paint4 = Paint()
      ..color = color3.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;

    final diamondPath = Path();
    final dx = size.width * 0.8;
    final dy = size.height * 0.15;
    final dSize = 8.0 + cos(animationValue * 2) * 2;
    diamondPath.moveTo(dx, dy - dSize);
    diamondPath.lineTo(dx + dSize, dy);
    diamondPath.lineTo(dx, dy + dSize);
    diamondPath.lineTo(dx - dSize, dy);
    diamondPath.close();
    canvas.drawPath(diamondPath, paint4);

    // Another small circle
    final paint5 = Paint()
      ..color = color1.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.6),
      size.width * 0.12 + sin(animationValue * 0.8) * 4,
      paint5,
    );
  }

  @override
  bool shouldRepaint(covariant BlobPainter oldDelegate) {
    return animationValue != oldDelegate.animationValue;
  }
}

class AnimatedBlobBackground extends StatefulWidget {
  final Widget child;
  final Color color1;
  final Color color2;
  final Color color3;
  final double height;

  const AnimatedBlobBackground({
    super.key,
    required this.child,
    required this.color1,
    required this.color2,
    required this.color3,
    this.height = 280,
  });

  @override
  State<AnimatedBlobBackground> createState() =>
      _AnimatedBlobBackgroundState();
}

class _AnimatedBlobBackgroundState extends State<AnimatedBlobBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: BlobPainter(
            color1: widget.color1,
            color2: widget.color2,
            color3: widget.color3,
            animationValue: _controller.value * 2 * pi,
          ),
          child: widget.child,
        );
      },
    );
  }
}
