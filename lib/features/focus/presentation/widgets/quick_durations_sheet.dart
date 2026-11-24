import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/stepper_tile.dart';
import '../../../settings/domain/pomodoro_settings.dart';
import '../../../settings/presentation/settings_controller.dart';

Future<void> showQuickDurationsSheet(
  BuildContext context, {
  required bool sessionInProgress,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _QuickDurationsSheet(sessionInProgress: sessionInProgress),
);

class _QuickDurationsSheet extends ConsumerWidget {
  const _QuickDurationsSheet({required this.sessionInProgress});
  final bool sessionInProgress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final ctl = ref.read(settingsProvider.notifier);
    final p = context.phase;
    final t = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('Durées', style: t.headlineSmall),
            ),
            StepperTile(
              label: 'Concentration',
              icon: Icons.center_focus_strong_rounded,
              color: p.focus,
              value: s.focusDurationMinutes,
              min: SettingsBounds.focusMin,
              max: SettingsBounds.focusMax,
              onChanged: (v) =>
                  ctl.update((s) => s.copyWith(focusDurationMinutes: v)),
            ),
            StepperTile(
              label: 'Petite pause',
              icon: Icons.local_cafe_rounded,
              color: p.shortBreak,
              value: s.shortBreakMinutes,
              min: SettingsBounds.shortMin,
              max: SettingsBounds.shortMax,
              onChanged: (v) =>
                  ctl.update((s) => s.copyWith(shortBreakMinutes: v)),
            ),
            StepperTile(
              label: 'Longue pause',
              icon: Icons.self_improvement_rounded,
              color: p.longBreak,
              value: s.longBreakMinutes,
              min: SettingsBounds.longMin,
              max: SettingsBounds.longMax,
              onChanged: (v) =>
                  ctl.update((s) => s.copyWith(longBreakMinutes: v)),
            ),
            StepperTile(
              label: 'Cycles avant longue pause',
              icon: Icons.repeat_rounded,
              color: p.muted,
              unit: '',
              value: s.longBreakInterval,
              min: SettingsBounds.intervalMin,
              max: SettingsBounds.intervalMax,
              onChanged: (v) =>
                  ctl.update((s) => s.copyWith(longBreakInterval: v)),
            ),
            if (sessionInProgress)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 18, color: p.muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'La session en cours garde sa durée. Les changements '
                        's’appliquent à la prochaine session.',
                        style: t.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
