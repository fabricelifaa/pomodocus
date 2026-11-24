import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../app/theme/app_colors.dart';
import '../../shared/widgets/motion.dart';
import '../../shared/widgets/pomodocus_logo.dart';

/// 3-second animated splash: the Lottie logo reveal, then the wordmark and
/// the slogan. Shown after the native splash (same background colour, so the
/// hand-off is seamless). A tap skips it.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.next = '/focus'});

  static const path = '/splash';
  static const duration = Duration(milliseconds: 3000);

  final String next;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: SplashScreen.duration)
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed) _leave();
        });
  bool _left = false;

  @override
  void initState() {
    super.initState();
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _leave() {
    if (_left || !mounted) return;
    _left = true;
    context.go(widget.next);
  }

  /// Progress of an element that animates between [from] and [to] ms.
  double _seg(int from, int to, [Curve curve = Curves.easeOutCubic]) {
    final ms = _c.value * SplashScreen.duration.inMilliseconds;
    return curve.transform(((ms - from) / (to - from)).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? BrandColors.paper : BrandColors.ink;
    final muted = context.phase.muted;
    final still = reduceMotion(context);

    Widget reveal(Widget child, int from, {double dy = 14}) {
      final v = still ? 1.0 : _seg(from, from + 520);
      return Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, (1 - v) * dy),
          child: child,
        ),
      );
    }

    return Scaffold(
      backgroundColor: dark ? BrandColors.night : BrandColors.paper,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _leave,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final out = still ? 0.0 : _seg(2650, 3000, Curves.easeInCubic);
            return Opacity(
              opacity: 1 - out,
              child: Transform.scale(
                scale: 1 + out * 0.04,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox.square(
                        dimension: 190,
                        child: still
                            ? const Padding(
                                padding: EdgeInsets.all(40),
                                child: PomodocusSymbol(size: 110),
                              )
                            : Lottie.asset(
                                'assets/lottie/logo_reveal.json',
                                repeat: false,
                                frameRate: FrameRate.max,
                              ),
                      ),
                      reveal(
                        Text(
                          'pomodocus',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontWeight: FontWeight.w800,
                            fontSize: 40,
                            letterSpacing: -1.2,
                            height: 1,
                            color: ink,
                          ),
                        ),
                        900,
                      ),
                      const SizedBox(height: 12),
                      reveal(
                        Text(
                          'Focus on what matters.',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontWeight: FontWeight.w500,
                            fontSize: 17,
                            color: muted,
                          ),
                        ),
                        1200,
                      ),
                      const SizedBox(height: 28),
                      reveal(
                        Text(
                          'FOCUS. WORK. REPEAT.',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            letterSpacing: 3.2,
                            color: context.phase.focus,
                          ),
                        ),
                        1500,
                        dy: 8,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
