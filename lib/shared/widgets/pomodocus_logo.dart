import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// The Pomodocus symbol drawn natively (no SVG dependency): a tomato whose
/// stem continues as the timer hand, pointing at 12 — the start of a session.
class PomodocusSymbol extends StatelessWidget {
  const PomodocusSymbol({
    super.key,
    this.size = 32,
    this.body = BrandColors.coral,
    this.leaf = BrandColors.teal,
    this.hand,
  });

  final double size;
  final Color body;
  final Color leaf;

  /// Colour of the hand; defaults to a transparent cut-out.
  final Color? hand;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _SymbolPainter(body, leaf, hand)),
  );
}

class _SymbolPainter extends CustomPainter {
  _SymbolPainter(this.body, this.leaf, this.hand);
  final Color body, leaf;
  final Color? hand;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 256, size.height / 256);
    final handRect = RRect.fromLTRBR(
      117,
      83,
      139,
      159,
      const Radius.circular(11),
    );
    final fruit = Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(Rect.fromCircle(center: const Offset(128, 146), radius: 90))
      ..addRRect(handRect);
    canvas.drawPath(fruit, Paint()..color = body);
    if (hand != null) canvas.drawRRect(handRect, Paint()..color = hand!);

    final lp = Paint()..color = leaf;
    canvas.drawRRect(
      RRect.fromLTRBR(118, 22, 138, 68, const Radius.circular(10)),
      lp,
    );
    final leafPath = Path()
      ..moveTo(134, 54)
      ..quadraticBezierTo(148, 16, 200, 28)
      ..quadraticBezierTo(184, 68, 134, 54)
      ..close();
    canvas.drawPath(leafPath, lp);
  }

  @override
  bool shouldRepaint(_SymbolPainter old) =>
      old.body != body || old.leaf != leaf || old.hand != hand;
}

/// Symbol + "pomodocus" wordmark.
class PomodocusLogo extends StatelessWidget {
  const PomodocusLogo({super.key, this.height = 28});
  final double height;

  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).colorScheme.onSurface;
    return Semantics(
      label: 'Pomodocus',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PomodocusSymbol(size: height),
          SizedBox(width: height * 0.28),
          Text(
            'pomodocus',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontWeight: FontWeight.w800,
              fontSize: height * 0.74,
              letterSpacing: -0.6,
              height: 1,
              color: ink,
            ),
          ),
        ],
      ),
    );
  }
}
