import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../shared/widgets/motion.dart';

/// Circular countdown: the coloured arc is the remaining time, starting at
/// 12 o'clock like the hand of the Pomodocus logo.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.remainingFraction,
    required this.color,
    required this.trackColor,
    required this.running,
    required this.child,
    this.size = 300,
    this.strokeWidth = 14,
  });

  final double remainingFraction;
  final Color color;
  final Color trackColor;
  final bool running;
  final Widget child;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    // While running we interpolate linearly between the one-second updates,
    // giving a continuous motion; other changes ease.
    final duration = motionDuration(
      context,
      running
          ? const Duration(milliseconds: 1000)
          : const Duration(milliseconds: 650),
    );
    return SizedBox.square(
      dimension: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: remainingFraction.clamp(0.0, 1.0)),
        duration: duration,
        curve: running ? Curves.linear : Curves.easeOutCubic,
        builder: (context, value, child) => CustomPaint(
          painter: _RingPainter(
            fraction: value,
            color: color,
            track: trackColor,
            stroke: strokeWidth,
          ),
          child: child,
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.fraction,
    required this.color,
    required this.track,
    required this.stroke,
  });

  final double fraction;
  final Color color;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - stroke) / 2 - 6;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );

    // Minute ticks, very discreet.
    final tickPaint = Paint()
      ..color = track
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final inner = radius - stroke / 2 - 14;
    for (var i = 0; i < 60; i += 5) {
      final a = -math.pi / 2 + i / 60 * 2 * math.pi;
      final len = i % 15 == 0 ? 8.0 : 4.0;
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(
        center + d * inner,
        center + d * (inner - len),
        tickPaint,
      );
    }

    if (fraction <= 0) return;
    final sweep = 2 * math.pi * fraction;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color,
    );

    // Knob at the moving end of the arc.
    final a = -math.pi / 2 + sweep;
    final knob = center + Offset(math.cos(a), math.sin(a)) * radius;
    canvas.drawCircle(knob, stroke * 0.85, Paint()..color = color);
    canvas.drawCircle(
      knob,
      stroke * 0.36,
      Paint()..color = Colors.white.withValues(alpha: 0.95),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction ||
      old.color != color ||
      old.track != track ||
      old.stroke != stroke;
}
