import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';

/// A labelled −/+ stepper with bounds. Long-press repeats quickly.
class StepperTile extends StatelessWidget {
  const StepperTile({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.unit = 'min',
    this.icon,
    this.color,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final String unit;
  final IconData? icon;
  final Color? color;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = context.phase;
    final accent = color ?? p.focus;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: accent, size: 20),
            ),
            const SizedBox(width: 14),
          ],
          Expanded(child: Text(label, style: t.titleSmall)),
          _StepButton(
            icon: Icons.remove_rounded,
            tooltip: 'Diminuer $label',
            onTap: value > min ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: 68,
            child: Semantics(
              liveRegion: true,
              child: Text(
                '$value $unit',
                textAlign: TextAlign.center,
                style: t.titleMedium!.copyWith(
                  fontFeatures: AppTypography.tabular,
                ),
              ),
            ),
          ),
          _StepButton(
            icon: Icons.add_rounded,
            tooltip: 'Augmenter $label',
            onTap: value < max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.tooltip, this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.phase;
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap!();
            },
      style: IconButton.styleFrom(
        backgroundColor: p.track.withValues(alpha: 0.6),
        disabledBackgroundColor: p.track.withValues(alpha: 0.25),
        fixedSize: const Size(40, 40),
        minimumSize: const Size(40, 40),
      ),
      icon: Icon(icon, size: 20),
    );
  }
}
