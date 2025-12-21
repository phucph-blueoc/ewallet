import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Tech-inspired animated background with circuit patterns
class TechBackground extends StatefulWidget {
  final Widget child;
  final bool showPattern;

  const TechBackground({
    super.key,
    required this.child,
    this.showPattern = true,
  });

  @override
  State<TechBackground> createState() => _TechBackgroundState();
}

class _TechBackgroundState extends State<TechBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Animated gradient background
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF050810),
                    const Color(0xFF0A0E27),
                    const Color(0xFF050810),
                  ],
                  stops: [
                    0.0,
                    0.5 + 0.3 * math.sin(_controller.value * 2 * math.pi),
                    1.0,
                  ],
                ),
              ),
            );
          },
        ),
        // Circuit pattern overlay
        if (widget.showPattern)
          CustomPaint(
            painter: CircuitPatternPainter(_controller.value),
            child: Container(),
          ),
        // Content
        widget.child,
      ],
    );
  }
}

class CircuitPatternPainter extends CustomPainter {
  final double animationValue;

  CircuitPatternPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00D4FF).withOpacity(0.1)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Draw circuit-like lines
    final path = Path();
    
    // Horizontal lines
    for (int i = 0; i < 5; i++) {
      final y = size.height * (i + 1) / 6;
      path.moveTo(0, y);
      path.lineTo(size.width, y);
    }

    // Vertical lines
    for (int i = 0; i < 5; i++) {
      final x = size.width * (i + 1) / 6;
      path.moveTo(x, 0);
      path.lineTo(x, size.height);
    }

    // Animated glow effect
    final glowPaint = Paint()
      ..color = const Color(0xFF00D4FF).withOpacity(0.05 * (1 + math.sin(animationValue * 2 * math.pi)))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);

    canvas.drawPath(path, paint);
    canvas.drawPath(path, glowPaint);
  }

  @override
  bool shouldRepaint(CircuitPatternPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

