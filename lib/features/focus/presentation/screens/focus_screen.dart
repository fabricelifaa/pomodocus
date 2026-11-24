import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/motion.dart';
import '../../../../shared/widgets/pomodocus_logo.dart';
import '../../../settings/presentation/settings_controller.dart';
import '../../domain/entities/active_timer_state.dart';
import '../../domain/entities/session_type.dart';
import '../controllers/notification_permission_controller.dart';
import '../focus_actions.dart';
import '../controllers/timer_controller.dart';
import '../widgets/focus_controls.dart';
import '../widgets/progress_ring.dart';
import '../widgets/quick_durations_sheet.dart';
import 'fullscreen_timer_screen.dart';

class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> {
  int _celebrationKey = 0;
  bool _celebrating = false;

  static const _phrases = {
    SessionType.focus: [
      'Une seule chose à la fois.',
      'Focus on what matters.',
      'Le reste peut attendre 25 minutes.',
      'Petit pas, grand progrès.',
    ],
    SessionType.shortBreak: [
      'Respirez. Levez les yeux de l’écran.',
      'Un verre d’eau ? C’est le moment.',
      'Étirez-vous un peu.',
    ],
    SessionType.longBreak: [
      'Cycle bouclé. Vous l’avez bien mérité.',
      'Marchez un peu, aérez-vous l’esprit.',
    ],
  };

  bool get _fullscreenOpen =>
      GoRouterState.of(context).uri.path == FullscreenTimerScreen.path;

  void _openFullscreen() => context.push(FullscreenTimerScreen.path);

  Future<void> _onPrimary(ActiveTimerState t) async {
    final wasIdle = t.isIdle;
    await FocusActions.primary(context, ref, t);
    if (!mounted || !wasIdle) return;
    final s = ref.read(settingsProvider);
    if (s.fullscreenEnabled && s.fullscreenAutoOpen && !_fullscreenOpen) {
      _openFullscreen();
    }
  }

  Future<void> _onReset(ActiveTimerState t) =>
      FocusActions.reset(context, ref, t);

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(timerControllerProvider);
    final settings = ref.watch(settingsProvider);
    final permission = ref.watch(notificationPermissionProvider).value;
    final t = view.timer;
    final p = context.phase;
    final text = Theme.of(context).textTheme;
    final accent = p.forType(t.type);

    ref.listen(timerControllerProvider.select((v) => v.completionCount), (
      prev,
      next,
    ) {
      if (prev != null && next > prev && !reduceMotion(context)) {
        setState(() {
          _celebrationKey++;
          _celebrating = true;
        });
      }
    });

    final completedInSet = t.type == SessionType.focus
        ? t.cycleNumber - 1
        : t.cycleNumber;
    final total = math.max(settings.longBreakInterval, t.cycleNumber);
    final phrases = _phrases[t.type]!;
    final phrase = phrases[(t.cycleNumber - 1) % phrases.length];
    final d = motionDuration(context, const Duration(milliseconds: 600));

    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: accent),
      duration: d,
      curve: Curves.easeInOut,
      builder: (context, color, _) {
        final c = color ?? accent;
        return Scaffold(
          body: SafeArea(
            child: Stack(
              children: [
                LayoutBuilder(
                  builder: (context, box) {
                    final compact = box.maxWidth < 360;
                    final gap = compact ? 12.0 : 20.0;
                    final ringSize = math.min(
                      math.min(box.maxWidth * 0.8, 340.0),
                      box.maxHeight * 0.48,
                    );
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: box.maxHeight),
                        child: IntrinsicHeight(
                          child: Column(
                            children: [
                              _Header(
                                onFullscreen: settings.fullscreenEnabled
                                    ? _openFullscreen
                                    : null,
                                onTune: () => showQuickDurationsSheet(
                                  context,
                                  sessionInProgress: !t.isIdle,
                                ),
                              ),
                              if (permission == NotificationPermission.denied)
                                _PermissionBanner(
                                  onTap: () => context.go('/settings'),
                                ),
                              const Spacer(),
                              _PhaseChip(type: t.type, color: c),
                              SizedBox(height: ringSize * 0.08),
                              AnimatedScale(
                                scale: t.isRunning ? 1 : 0.97,
                                duration: motionDuration(
                                  context,
                                  const Duration(milliseconds: 450),
                                ),
                                curve: Curves.easeOutBack,
                                child: ProgressRing(
                                  size: ringSize,
                                  strokeWidth: ringSize * 0.045,
                                  remainingFraction: 1 - view.progress,
                                  running: t.isRunning,
                                  color: c,
                                  trackColor: p.track,
                                  child: _TimeReadout(
                                    seconds: view.remainingSeconds,
                                    status: t.status,
                                    fontSize: ringSize * 0.22,
                                    onTap: t.isIdle
                                        ? () => showQuickDurationsSheet(
                                            context,
                                            sessionInProgress: false,
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                              SizedBox(height: ringSize * 0.08),
                              CycleIndicator(
                                current: t.cycleNumber,
                                total: total,
                                completedInSet: completedInSet,
                                color: c,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Pomodoro ${t.cycleNumber} sur ${settings.longBreakInterval}',
                                style: text.labelMedium!.copyWith(
                                  color: p.muted,
                                ),
                              ),
                              const SizedBox(height: 28),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  RoundIconAction(
                                    icon: t.isIdle
                                        ? Icons.restart_alt_rounded
                                        : Icons.stop_rounded,
                                    tooltip: t.isIdle
                                        ? 'Réinitialiser le cycle'
                                        : 'Arrêter la session',
                                    onPressed:
                                        t.isIdle &&
                                            t.cycleNumber == 1 &&
                                            t.type == SessionType.focus
                                        ? null
                                        : () => _onReset(t),
                                  ),
                                  SizedBox(width: gap),
                                  Flexible(
                                    child: PrimaryTimerButton(
                                      status: t.status,
                                      color: c,
                                      compact: compact,
                                      onPressed: () => _onPrimary(t),
                                    ),
                                  ),
                                  SizedBox(width: gap),
                                  RoundIconAction(
                                    icon: Icons.skip_next_rounded,
                                    tooltip: 'Passer la pause',
                                    onPressed: t.type.isBreak
                                        ? ref
                                              .read(
                                                timerControllerProvider
                                                    .notifier,
                                              )
                                              .skipBreak
                                        : null,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 28),
                              AnimatedSwitcher(
                                duration: d,
                                child: Padding(
                                  key: ValueKey(phrase),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                  ),
                                  child: Text(
                                    phrase,
                                    textAlign: TextAlign.center,
                                    style: text.bodyMedium!.copyWith(
                                      color: p.muted,
                                    ),
                                  ),
                                ),
                              ),
                              const Spacer(flex: 2),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                if (_celebrating)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: Lottie.asset(
                          'assets/lottie/celebrate.json',
                          key: ValueKey(_celebrationKey),
                          repeat: false,
                          width: 360,
                          onLoaded: (comp) => Future.delayed(comp.duration, () {
                            if (mounted) setState(() => _celebrating = false);
                          }),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onTune, this.onFullscreen});
  final VoidCallback onTune;
  final VoidCallback? onFullscreen;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 12, 12, 0),
    child: Row(
      children: [
        const Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: PomodocusLogo(height: 28),
          ),
        ),
        const Spacer(),
        if (onFullscreen != null)
          IconButton(
            tooltip: 'Plein écran',
            onPressed: onFullscreen,
            icon: const Icon(Icons.fullscreen_rounded),
          ),
        IconButton(
          tooltip: 'Régler les durées',
          onPressed: onTune,
          icon: const Icon(Icons.tune_rounded),
        ),
      ],
    ),
  );
}

class _PhaseChip extends StatelessWidget {
  const _PhaseChip({required this.type, required this.color});
  final SessionType type;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final icon = switch (type) {
      SessionType.focus => Icons.center_focus_strong_rounded,
      SessionType.shortBreak => Icons.local_cafe_rounded,
      SessionType.longBreak => Icons.self_improvement_rounded,
    };
    final d = motionDuration(context, const Duration(milliseconds: 380));
    return AnimatedContainer(
      duration: d,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(40),
      ),
      child: AnimatedSwitcher(
        duration: d,
        transitionBuilder: (child, a) => FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, 0.4),
              end: Offset.zero,
            ).animate(a),
            child: child,
          ),
        ),
        child: Row(
          key: ValueKey(type),
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              sessionLabel(type),
              style: Theme.of(context).textTheme.labelLarge!
                  .copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeReadout extends StatelessWidget {
  const _TimeReadout({
    required this.seconds,
    required this.status,
    required this.fontSize,
    this.onTap,
  });

  final int seconds;
  final TimerStatus status;
  final double fontSize;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.phase;
    final text = Theme.of(context).textTheme;
    final caption = switch (status) {
      TimerStatus.idle => 'Prêt',
      TimerStatus.running => 'En cours',
      TimerStatus.paused => 'En pause',
    };
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The digits themselves never animate (no per-second distraction);
          // only their opacity changes when paused.
          AnimatedOpacity(
            opacity: status == TimerStatus.paused ? 0.45 : 1,
            duration: motionDuration(
              context,
              const Duration(milliseconds: 300),
            ),
            child: Text(
              formatClock(seconds),
              semanticsLabel:
                  '${seconds ~/ 60} minutes ${seconds % 60} secondes restantes',
              style: text.displayLarge!.copyWith(
                fontSize: fontSize,
                fontFeatures: AppTypography.tabular,
              ),
            ),
          ),
          const SizedBox(height: 4),
          AnimatedSwitcher(
            duration: motionDuration(
              context,
              const Duration(milliseconds: 250),
            ),
            child: Text(
              caption.toUpperCase(),
              key: ValueKey(caption),
              style: text.labelSmall!.copyWith(color: p.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionBanner extends StatelessWidget {
  const _PermissionBanner({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.phase;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Material(
        color: p.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.notifications_off_rounded, color: p.muted, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Notifications désactivées : vous ne serez pas prévenu en arrière-plan.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: p.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
