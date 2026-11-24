import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/motion.dart';

/// MM:SS made of split-flap cards. Each digit flips on its own when it
/// changes: the old top half folds down, then the new bottom half lands.
class FlipClock extends StatelessWidget {
  const FlipClock({
    super.key,
    required this.seconds,
    required this.maxWidth,
    required this.maxHeight,
    this.cardColor = const Color(0xFF1C1E25),
    this.digitColor = const Color(0xFFF3F1EE),
    this.dimmed = false,
  });

  final int seconds;
  final double maxWidth;
  final double maxHeight;
  final Color cardColor;
  final Color digitColor;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final s = seconds < 0 ? 0 : seconds;
    final minutes = (s ~/ 60).toString().padLeft(2, '0');
    final secs = (s % 60).toString().padLeft(2, '0');
    final count = minutes.length + secs.length;
    // Width units: digits + small gaps inside a pair + the colon.
    final units = count + (count - 2) * 0.08 + 0.62;
    final w = math.max(
      12.0,
      math.min(maxWidth * 0.9 / units, maxHeight / FlipDigit.aspect),
    );
    final gap = w * 0.08;

    Widget group(String digits, String key) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < digits.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          FlipDigit(
            // Keyed by position from the right so 9:59 → 10:00 flips the
            // right cards instead of rebuilding them all.
            key: ValueKey('$key${digits.length - i}'),
            digit: digits[i],
            width: w,
            cardColor: cardColor,
            digitColor: digitColor,
          ),
        ],
      ],
    );

    final dot = Container(
      width: w * 0.13,
      height: w * 0.13,
      decoration: BoxDecoration(
        color: digitColor.withValues(alpha: 0.55),
        shape: BoxShape.circle,
      ),
    );

    return Semantics(
      label: '${s ~/ 60} minutes ${s % 60} secondes restantes',
      excludeSemantics: true,
      child: AnimatedOpacity(
        opacity: dimmed ? 0.4 : 1,
        duration: motionDuration(context, const Duration(milliseconds: 300)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            group(minutes, 'm'),
            SizedBox(
              width: w * 0.62,
              height: w * FlipDigit.aspect,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  dot,
                  SizedBox(height: w * 0.3),
                  dot,
                ],
              ),
            ),
            group(secs, 's'),
          ],
        ),
      ),
    );
  }
}

class FlipDigit extends StatefulWidget {
  const FlipDigit({
    super.key,
    required this.digit,
    required this.width,
    required this.cardColor,
    required this.digitColor,
  });

  /// Card height / width.
  static const aspect = 1.42;

  final String digit;
  final double width;
  final Color cardColor;
  final Color digitColor;

  @override
  State<FlipDigit> createState() => _FlipDigitState();
}

class _FlipDigitState extends State<FlipDigit>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
    value: 1,
  );
  late String _current = widget.digit;
  late String _previous = widget.digit;

  @override
  void didUpdateWidget(covariant FlipDigit old) {
    super.didUpdateWidget(old);
    if (widget.digit != _current) {
      _previous = _current;
      _current = widget.digit;
      if (reduceMotion(context)) {
        _c.value = 1;
      } else {
        _c.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.width;
    final h = w * FlipDigit.aspect;
    final split = math.max(1.0, w * 0.018);
    final radius = Radius.circular(w * 0.12);

    Widget card(String d) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: widget.cardColor,
        borderRadius: BorderRadius.all(radius),
      ),
      alignment: Alignment.center,
      child: Text(
        d,
        textHeightBehavior: const TextHeightBehavior(
          applyHeightToFirstAscent: false,
          applyHeightToLastDescent: false,
        ),
        style: TextStyle(
          fontFamily: AppTypography.family,
          fontWeight: FontWeight.w700,
          fontSize: h * 0.78,
          height: 1,
          color: widget.digitColor,
          fontFeatures: AppTypography.tabular,
        ),
      ),
    );

    Widget half(String d, {required bool top, double shade = 0}) => SizedBox(
      width: w,
      height: (h - split) / 2,
      child: ClipRect(
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: top ? 0 : -(h + split) / 2,
              child: card(d),
            ),
            if (shade > 0)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: shade.clamp(0, 0.6)),
                ),
              ),
          ],
        ),
      ),
    );

    return SizedBox(
      width: w,
      height: h,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          final animating = t < 1;
          final bottomStatic = animating ? _previous : _current;
          const persp = 0.0022;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(top: 0, left: 0, child: half(_current, top: true)),
              Positioned(
                bottom: 0,
                left: 0,
                child: half(
                  bottomStatic,
                  top: false,
                  // The landing flap casts a shadow on the old half.
                  shade: animating && t > 0.5 ? (1 - t) * 0.5 : 0,
                ),
              ),
              if (animating && t < 0.5)
                Positioned(
                  top: 0,
                  left: 0,
                  child: Transform(
                    alignment: Alignment.bottomCenter,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, persp / (w / 100))
                      ..rotateX(-math.pi * Curves.easeIn.transform(t * 2) / 2),
                    child: half(_previous, top: true, shade: t * 0.7),
                  ),
                ),
              if (animating && t >= 0.5)
                Positioned(
                  bottom: 0,
                  left: 0,
                  child: Transform(
                    alignment: Alignment.topCenter,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, persp / (w / 100))
                      ..rotateX(
                        math.pi /
                            2 *
                            (1 - Curves.easeOutBack.transform((t - 0.5) * 2)),
                      ),
                    child: half(_current, top: false, shade: (1 - t) * 0.6),
                  ),
                ),
              // Hinge line.
              Positioned(
                left: 0,
                right: 0,
                top: (h - split) / 2,
                child: Container(height: split, color: Colors.black26),
              ),
            ],
          );
        },
      ),
    );
  }
}
