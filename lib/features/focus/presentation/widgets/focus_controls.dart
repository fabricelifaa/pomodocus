import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/motion.dart';
import '../../domain/entities/active_timer_state.dart';

/// Primary contextual button (Démarrer / Pause / Reprendre).
class PrimaryTimerButton extends StatelessWidget {
  const PrimaryTimerButton({
    super.key,
    required this.status,
    required this.color,
    required this.onPressed,
    this.compact = false,
  });

  final bool compact;
  final TimerStatus status;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final (label, icon) = switch (status) {
      TimerStatus.idle => ('Démarrer', Icons.play_arrow_rounded),
      TimerStatus.running => ('Pause', Icons.pause_rounded),
      TimerStatus.paused => ('Reprendre', Icons.play_arrow_rounded),
    };
    final d = motionDuration(context, const Duration(milliseconds: 240));
    final filled = status != TimerStatus.running;
    final fg = filled ? Colors.white : color;
    return PressableScale(
      onTap: onPressed,
      semanticLabel: label,
      child: AnimatedContainer(
        duration: d,
        curve: Curves.easeOutCubic,
        height: 64,
        constraints: BoxConstraints(minWidth: compact ? 140 : 184),
        padding: EdgeInsets.symmetric(horizontal: compact ? 18 : 28),
        decoration: BoxDecoration(
          color: filled ? color : color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(32),
          boxShadow: filled
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.28),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ]
              : const [],
        ),
        child: AnimatedSwitcher(
          duration: d,
          switchInCurve: Curves.easeOutBack,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: ScaleTransition(
              scale: Tween(begin: 0.85, end: 1.0).animate(anim),
              child: child,
            ),
          ),
          child: Row(
            key: ValueKey(status),
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: fg, size: 28),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.fade,
                  style: Theme.of(context).textTheme.titleMedium!
                      .copyWith(color: fg, fontSize: 17),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Round secondary action (reset, skip…).
class RoundIconAction extends StatelessWidget {
  const RoundIconAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final p = context.phase;
    final enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: PressableScale(
        onTap: onPressed,
        semanticLabel: tooltip,
        scale: 0.9,
        child: AnimatedOpacity(
          opacity: enabled ? 1 : 0.35,
          duration: motionDuration(context, const Duration(milliseconds: 200)),
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: p.card,
              shape: BoxShape.circle,
              border: Border.all(color: p.track),
            ),
            child: Icon(icon, color: p.muted, size: 24),
          ),
        ),
      ),
    );
  }
}

/// "Pomodoro 2 sur 4" dots.
class CycleIndicator extends StatelessWidget {
  const CycleIndicator({
    super.key,
    required this.current,
    required this.total,
    required this.completedInSet,
    required this.color,
  });

  final int current;
  final int total;
  final int completedInSet;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = context.phase;
    final d = motionDuration(context, const Duration(milliseconds: 350));
    return Semantics(
      label: 'Pomodoro $current sur $total',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= total; i++)
            AnimatedContainer(
              duration: d,
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == current ? 22 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i <= completedInSet
                    ? color
                    : i == current
                    ? color.withValues(alpha: 0.45)
                    : p.track,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    );
  }
}
