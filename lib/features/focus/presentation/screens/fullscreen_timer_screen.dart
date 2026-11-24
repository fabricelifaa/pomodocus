import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/providers.dart';
import '../../../../core/services/display_mode_service.dart';
import '../../../../core/services/dnd_service.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/motion.dart';
import '../../../settings/domain/pomodoro_settings.dart';
import '../../../settings/presentation/settings_controller.dart';
import '../../domain/entities/active_timer_state.dart';
import '../../domain/entities/session_type.dart';
import '../controllers/timer_controller.dart';
import '../focus_actions.dart';
import '../widgets/flip_clock.dart';
import '../widgets/focus_controls.dart';

/// "Mode vidéo": landscape, system bars hidden, screen kept on, giant digits.
/// Tap anywhere to show the controls; they hide again while running.
/// Options: digital or flip clock, a tick each second (mutable) and
/// Do Not Disturb while the screen is shown.
class FullscreenTimerScreen extends ConsumerStatefulWidget {
  const FullscreenTimerScreen({super.key});

  static const path = '/fullscreen';

  @override
  ConsumerState<FullscreenTimerScreen> createState() =>
      _FullscreenTimerScreenState();
}

class _FullscreenTimerScreenState extends ConsumerState<FullscreenTimerScreen>
    with WidgetsBindingObserver {
  static const _hideAfter = Duration(seconds: 4);

  late final DisplayModeService _display = ref.read(displayModeServiceProvider);
  late final DndService _dnd = ref.read(dndServiceProvider);
  bool _controlsVisible = true;
  bool _dndActive = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _display.enterFullscreenLandscape();
    _syncDnd();
    _scheduleHide();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    _display.enterStandard();
    if (_dndActive) _dnd.disable();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the system page where the DND access is granted.
    if (state == AppLifecycleState.resumed) _syncDnd();
  }

  /// Applies the DND setting (no-op without the system access).
  Future<void> _syncDnd() async {
    final want = ref.read(settingsProvider).fullscreenDnd;
    if (want && !_dndActive) {
      final ok = await _dnd.enable();
      if (mounted) setState(() => _dndActive = ok);
    } else if (!want && _dndActive) {
      await _dnd.disable();
      if (mounted) setState(() => _dndActive = false);
    }
  }

  Future<void> _toggleDnd() async {
    _scheduleHide();
    final settings = ref.read(settingsProvider.notifier);
    if (_dndActive) {
      await settings.update((s) => s.copyWith(fullscreenDnd: false));
      return _syncDnd();
    }
    await settings.update((s) => s.copyWith(fullscreenDnd: true));
    if (await _dnd.hasAccess()) return _syncDnd();
    if (!mounted) return;
    final open = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Activer « Ne pas déranger »'),
        content: const Text(
          'Pour bloquer les appels et les notifications de messages en plein '
          'écran, autorisez Pomodocus à gérer le mode « Ne pas déranger ». '
          'Votre réglage habituel est rétabli en quittant le plein écran.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Plus tard'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Autoriser'),
          ),
        ],
      ),
    );
    if (open == true) await _dnd.requestAccess();
  }

  void _toggleClockStyle() {
    _scheduleHide();
    ref
        .read(settingsProvider.notifier)
        .update(
          (s) => s.copyWith(
            fullscreenClockStyle: s.fullscreenClockStyle == ClockStyle.digital
                ? ClockStyle.flip
                : ClockStyle.digital,
          ),
        );
  }

  void _toggleTick() {
    _scheduleHide();
    ref
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(fullscreenTickSound: !s.fullscreenTickSound));
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_hideAfter, () {
      final running = ref.read(timerControllerProvider).timer.isRunning;
      if (mounted && running) setState(() => _controlsVisible = false);
    });
  }

  void _onTapBackground() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _scheduleHide();
  }

  void _exit() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/focus');
    }
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(timerControllerProvider);
    final interval = ref.watch(
      settingsProvider.select((s) => s.longBreakInterval),
    );
    final style = ref.watch(
      settingsProvider.select((s) => s.fullscreenClockStyle),
    );
    final tickOn = ref.watch(
      settingsProvider.select((s) => s.fullscreenTickSound),
    );
    final t = view.timer;

    // One tick per displayed second while counting down.
    ref.listen(timerControllerProvider.select((v) => v.remainingSeconds), (
      prev,
      next,
    ) {
      final s = ref.read(settingsProvider);
      if (prev != null &&
          next != prev &&
          next > 0 &&
          s.fullscreenTickSound &&
          ref.read(timerControllerProvider).timer.isRunning) {
        ref.read(tickSoundServiceProvider).tick(s.fullscreenClockStyle);
      }
    });

    // Controls always visible when nothing is counting down.
    final showControls = _controlsVisible || !t.isRunning;
    ref.listen(timerControllerProvider.select((v) => v.timer.status), (_, s) {
      if (s == TimerStatus.running) _scheduleHide();
    });

    // Always dark, like a video player: easier on the eyes and on OLED.
    return Theme(
      data: AppTheme.dark(),
      child: Builder(
        builder: (context) {
          final p = context.phase;
          final accent = p.forType(t.type);
          final d = motionDuration(context, const Duration(milliseconds: 600));
          return TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: accent),
            duration: d,
            builder: (context, color, _) {
              final c = color ?? accent;
              return Scaffold(
                backgroundColor: const Color(0xFF0E0F13),
                body: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _onTapBackground,
                  child: LayoutBuilder(
                    builder: (context, box) => Stack(
                      children: [
                        AnimatedPositioned(
                          duration: motionDuration(
                            context,
                            const Duration(milliseconds: 320),
                          ),
                          curve: Curves.easeOutCubic,
                          left: 0,
                          right: 0,
                          top: 0,
                          // Make room for the controls when they are shown.
                          bottom: showControls ? 88 : 0,
                          child: _Countdown(
                            seconds: view.remainingSeconds,
                            status: t.status,
                            type: t.type,
                            cycle: t.cycleNumber,
                            interval: interval,
                            color: c,
                            style: style,
                            box: BoxConstraints(
                              maxWidth: box.maxWidth,
                              maxHeight:
                                  box.maxHeight - (showControls ? 88 : 0),
                            ),
                            // The digits shift slightly each minute to
                            // avoid burn-in on OLED screens.
                            drift: view.remainingSeconds ~/ 60,
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: _ProgressLine(
                            remaining: 1 - view.progress,
                            running: t.isRunning,
                            color: c,
                            track: p.track,
                          ),
                        ),
                        _Controls(
                          visible: showControls,
                          timer: t,
                          color: c,
                          compact: box.maxHeight < 340,
                          onExit: _exit,
                          clockStyle: style,
                          tickOn: tickOn,
                          dndOn: _dndActive,
                          onClockStyle: _toggleClockStyle,
                          onTick: _toggleTick,
                          onDnd: _toggleDnd,
                          onPrimary: () async {
                            await FocusActions.primary(context, ref, t);
                            _scheduleHide();
                          },
                          onReset: () => FocusActions.reset(context, ref, t),
                          onSkip: t.type.isBreak
                              ? ref
                                    .read(timerControllerProvider.notifier)
                                    .skipBreak
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _Countdown extends StatelessWidget {
  const _Countdown({
    required this.seconds,
    required this.status,
    required this.type,
    required this.cycle,
    required this.interval,
    required this.color,
    required this.style,
    required this.box,
    required this.drift,
  });

  final ClockStyle style;
  final int seconds;
  final TimerStatus status;
  final SessionType type;
  final int cycle;
  final int interval;
  final Color color;
  final BoxConstraints box;
  final int drift;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = context.phase;
    // Digits as large as the screen allows, leaving room for the labels.
    final digitSize = math.min(box.maxHeight * 0.46, box.maxWidth * 0.2);
    final dx = (drift % 3 - 1) * 6.0;
    final dy = ((drift ~/ 3) % 3 - 1) * 4.0;
    final paused = status == TimerStatus.paused;

    return AnimatedSlide(
      offset: Offset(
        dx / math.max(box.maxWidth, 1),
        dy / math.max(box.maxHeight, 1),
      ),
      duration: motionDuration(context, const Duration(seconds: 2)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            sessionLabel(type).toUpperCase(),
            style: text.labelLarge!.copyWith(
              color: color,
              letterSpacing: 4,
              fontSize: math.max(14, digitSize * 0.11),
            ),
          ),
          SizedBox(height: digitSize * 0.06),
          if (style == ClockStyle.flip)
            FlipClock(
              seconds: seconds,
              maxWidth: box.maxWidth,
              maxHeight: digitSize * 1.12,
              dimmed: paused,
            )
          else
            AnimatedOpacity(
              opacity: paused ? 0.4 : 1,
              duration: motionDuration(
                context,
                const Duration(milliseconds: 300),
              ),
              child: Text(
                formatClock(seconds),
                semanticsLabel:
                    '${seconds ~/ 60} minutes ${seconds % 60} secondes restantes',
                maxLines: 1,
                style: text.displayLarge!.copyWith(
                  fontSize: digitSize,
                  height: 1,
                  letterSpacing: -digitSize * 0.03,
                  fontFeatures: AppTypography.tabular,
                  color: const Color(0xFFF3F1EE),
                ),
              ),
            ),
          SizedBox(height: digitSize * 0.08),
          Text(
            paused
                ? 'EN PAUSE'
                : 'POMODORO ${math.min(cycle, interval)} SUR $interval',
            style: text.labelMedium!.copyWith(color: p.muted, letterSpacing: 2),
          ),
        ],
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({
    required this.remaining,
    required this.running,
    required this.color,
    required this.track,
  });

  final double remaining;
  final bool running;
  final Color color;
  final Color track;

  @override
  Widget build(BuildContext context) {
    final d = motionDuration(
      context,
      Duration(milliseconds: running ? 1000 : 600),
    );
    return TweenAnimationBuilder<double>(
      tween: Tween(end: remaining.clamp(0.0, 1.0)),
      duration: d,
      curve: running ? Curves.linear : Curves.easeOutCubic,
      builder: (context, v, _) => Stack(
        children: [
          Container(height: 4, color: track.withValues(alpha: 0.6)),
          FractionallySizedBox(
            widthFactor: v,
            child: Container(height: 4, color: color),
          ),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.visible,
    required this.timer,
    required this.color,
    required this.compact,
    required this.onExit,
    required this.onPrimary,
    required this.onReset,
    required this.onSkip,
    required this.clockStyle,
    required this.tickOn,
    required this.dndOn,
    required this.onClockStyle,
    required this.onTick,
    required this.onDnd,
  });

  final ClockStyle clockStyle;
  final bool tickOn;
  final bool dndOn;
  final VoidCallback onClockStyle;
  final VoidCallback onTick;
  final VoidCallback onDnd;
  final bool visible;
  final ActiveTimerState timer;
  final Color color;
  final bool compact;
  final VoidCallback onExit;
  final VoidCallback onPrimary;
  final VoidCallback onReset;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final t = timer;
    final canReset =
        !(t.isIdle && t.cycleNumber == 1 && t.type == SessionType.focus);
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: motionDuration(context, const Duration(milliseconds: 280)),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: 8,
                left: 8,
                child: IconButton(
                  tooltip: 'Quitter le plein écran',
                  onPressed: onExit,
                  iconSize: 28,
                  color: const Color(0xFFF3F1EE),
                  icon: const Icon(Icons.fullscreen_exit_rounded),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Row(
                  children: [
                    _TopAction(
                      tooltip: clockStyle == ClockStyle.digital
                          ? 'Horloge à volets'
                          : 'Horloge numérique',
                      icon: clockStyle == ClockStyle.digital
                          ? Icons.view_day_rounded
                          : Icons.pin_rounded,
                      onPressed: onClockStyle,
                    ),
                    _TopAction(
                      tooltip: tickOn
                          ? 'Couper le tic-tac'
                          : 'Activer le tic-tac',
                      icon: tickOn
                          ? Icons.volume_up_rounded
                          : Icons.volume_off_rounded,
                      onPressed: onTick,
                    ),
                    _TopAction(
                      tooltip: dndOn
                          ? 'Désactiver « Ne pas déranger »'
                          : 'Activer « Ne pas déranger »',
                      icon: dndOn
                          ? Icons.do_not_disturb_on_rounded
                          : Icons.do_not_disturb_off_rounded,
                      active: dndOn,
                      activeColor: color,
                      onPressed: onDnd,
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: compact ? 12 : 24,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    RoundIconAction(
                      icon: t.isIdle
                          ? Icons.restart_alt_rounded
                          : Icons.stop_rounded,
                      tooltip: t.isIdle
                          ? 'Réinitialiser le cycle'
                          : 'Arrêter la session',
                      onPressed: canReset ? onReset : null,
                    ),
                    const SizedBox(width: 20),
                    PrimaryTimerButton(
                      status: t.status,
                      color: color,
                      compact: true,
                      onPressed: onPrimary,
                    ),
                    const SizedBox(width: 20),
                    RoundIconAction(
                      icon: Icons.skip_next_rounded,
                      tooltip: 'Passer la pause',
                      onPressed: onSkip,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopAction extends StatelessWidget {
  const _TopAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.active = false,
    this.activeColor,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool active;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      iconSize: 26,
      color: active ? activeColor : const Color(0xFFF3F1EE),
      style: IconButton.styleFrom(
        backgroundColor: active
            ? activeColor?.withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: 0.06),
      ),
      icon: Icon(icon),
    ),
  );
}
