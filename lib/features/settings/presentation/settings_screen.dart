import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/providers.dart';
import '../../../core/services/notification_service.dart';
import '../../../shared/widgets/stepper_tile.dart';
import '../../focus/presentation/controllers/notification_permission_controller.dart';
import '../domain/pomodoro_settings.dart';
import 'settings_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final ctl = ref.read(settingsProvider.notifier);
    final p = context.phase;

    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          _Section(
            title: 'DURÉES',
            footer: 'Les changements s’appliquent à la prochaine session.',
            children: [
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
            ],
          ),
          _Section(
            title: 'ENCHAÎNEMENT',
            children: [
              _SwitchTile(
                title: 'Démarrer les pauses automatiquement',
                value: s.autoStartBreaks,
                onChanged: (v) =>
                    ctl.update((s) => s.copyWith(autoStartBreaks: v)),
              ),
              _SwitchTile(
                title: 'Démarrer le Pomodoro suivant automatiquement',
                value: s.autoStartFocus,
                onChanged: (v) =>
                    ctl.update((s) => s.copyWith(autoStartFocus: v)),
              ),
            ],
          ),
          _Section(
            title: 'SONS ET VIBRATIONS',
            children: [
              _SwitchTile(
                title: 'Son de fin de session',
                icon: Icons.volume_up_rounded,
                value: s.soundEnabled,
                onChanged: (v) =>
                    ctl.update((s) => s.copyWith(soundEnabled: v)),
              ),
              _SwitchTile(
                title: 'Vibration',
                icon: Icons.vibration_rounded,
                value: s.vibrationEnabled,
                onChanged: (v) =>
                    ctl.update((s) => s.copyWith(vibrationEnabled: v)),
              ),
            ],
          ),
          _Section(
            title: 'APPARENCE',
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<AppThemePreference>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: AppThemePreference.system,
                        label: Text('Système'),
                        icon: Icon(Icons.brightness_auto_rounded),
                      ),
                      ButtonSegment(
                        value: AppThemePreference.light,
                        label: Text('Clair'),
                        icon: Icon(Icons.light_mode_rounded),
                      ),
                      ButtonSegment(
                        value: AppThemePreference.dark,
                        label: Text('Sombre'),
                        icon: Icon(Icons.dark_mode_rounded),
                      ),
                    ],
                    selected: {s.themeMode},
                    onSelectionChanged: (v) =>
                        ctl.update((s) => s.copyWith(themeMode: v.first)),
                  ),
                ),
              ),
            ],
          ),
          _Section(
            title: 'PLEIN ÉCRAN',
            footer:
                'Le décompte s’affiche en grand, téléphone à l’horizontale, '
                'comme une vidéo. L’écran reste allumé ; touchez-le pour '
                'afficher les commandes. « Ne pas déranger » bloque les appels '
                'et les notifications de messages, puis rétablit votre réglage '
                'en quittant le plein écran.',
            children: [
              _SwitchTile(
                title: 'Mode plein écran paysage',
                icon: Icons.fullscreen_rounded,
                value: s.fullscreenEnabled,
                onChanged: (v) =>
                    ctl.update((s) => s.copyWith(fullscreenEnabled: v)),
              ),
              _SwitchTile(
                title: 'Passer en plein écran au démarrage',
                icon: Icons.screen_rotation_rounded,
                value: s.fullscreenEnabled && s.fullscreenAutoOpen,
                onChanged: s.fullscreenEnabled
                    ? (v) =>
                          ctl.update((s) => s.copyWith(fullscreenAutoOpen: v))
                    : null,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ClockStyle>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: ClockStyle.digital,
                        label: Text('Numérique'),
                        icon: Icon(Icons.pin_rounded),
                      ),
                      ButtonSegment(
                        value: ClockStyle.flip,
                        label: Text('À volets'),
                        icon: Icon(Icons.view_day_rounded),
                      ),
                    ],
                    selected: {s.fullscreenClockStyle},
                    onSelectionChanged: s.fullscreenEnabled
                        ? (v) => ctl.update(
                            (s) => s.copyWith(fullscreenClockStyle: v.first),
                          )
                        : null,
                  ),
                ),
              ),
              _SwitchTile(
                title: 'Tic-tac à chaque seconde',
                icon: Icons.av_timer_rounded,
                value: s.fullscreenTickSound,
                onChanged: s.fullscreenEnabled
                    ? (v) =>
                          ctl.update((s) => s.copyWith(fullscreenTickSound: v))
                    : null,
              ),
              _DndTile(
                enabled: s.fullscreenEnabled,
                value: s.fullscreenDnd,
                onChanged: (v) =>
                    ctl.update((s) => s.copyWith(fullscreenDnd: v)),
              ),
            ],
          ),
          const _Section(
            title: 'NOTIFICATIONS',
            children: [_NotificationTile()],
          ),
          const _Section(
            title: 'RACCOURCIS',
            footer:
                'Appui long sur l’icône de Pomodocus : Démarrer un Pomodoro, '
                'Plein écran ou Statistiques.',
            children: [_ShortcutTiles()],
          ),
          _Section(
            title: 'APPLICATION',
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('À propos et mises à jour'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.go('/settings/about'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(notificationPermissionProvider).value;
    final t = Theme.of(context).textTheme;
    final p = context.phase;
    final granted = status == NotificationPermission.granted;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                granted
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_off_rounded,
                color: granted ? p.shortBreak : p.muted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  granted
                      ? 'Notifications autorisées'
                      : 'Notifications non autorisées',
                  style: t.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Pomodocus vous prévient à la fin d’une session, même en arrière-plan. '
            'Selon le téléphone (économie d’énergie, mode Ne pas déranger), la '
            'notification peut arriver avec un léger retard.',
            style: t.bodySmall,
          ),
          if (!granted) ...[
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () async {
                final r = await ref
                    .read(notificationPermissionProvider.notifier)
                    .request();
                if (r != NotificationPermission.granted && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Autorisez les notifications de Pomodocus dans les réglages du téléphone.',
                      ),
                    ),
                  );
                }
              },
              child: const Text('Autoriser les notifications'),
            ),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children, this.footer});
  final String title;
  final String? footer;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(title, style: t.labelSmall),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(children: children),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Text(footer!, style: t.bodySmall),
            ),
        ],
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.title,
    required this.value,
    required this.onChanged,
    this.icon,
  });

  final String title;
  final bool value;
  final IconData? icon;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
    secondary: icon == null ? null : Icon(icon),
    title: Text(title, style: Theme.of(context).textTheme.titleSmall),
    value: value,
    onChanged: onChanged,
  );
}

/// "Ne pas déranger" switch, with the system access it needs.
class _DndTile extends ConsumerStatefulWidget {
  const _DndTile({
    required this.enabled,
    required this.value,
    required this.onChanged,
  });

  final bool enabled;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  ConsumerState<_DndTile> createState() => _DndTileState();
}

class _DndTileState extends ConsumerState<_DndTile> {
  bool? _access;
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onResume: _check,
  );

  @override
  void initState() {
    super.initState();
    _lifecycle;
    _check();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final a = await ref.read(dndServiceProvider).hasAccess();
    if (mounted) setState(() => _access = a);
  }

  @override
  Widget build(BuildContext context) {
    final missing = widget.value && _access == false;
    return Column(
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.do_not_disturb_on_rounded),
          title: Text(
            'Ne pas déranger en plein écran',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          subtitle: missing
              ? const Text('Autorisation requise')
              : const Text('Pas d’appel ni de notification de message'),
          value: widget.value,
          onChanged: widget.enabled ? widget.onChanged : null,
        ),
        if (missing && widget.enabled)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: () => ref.read(dndServiceProvider).requestAccess(),
                child: const Text('Autoriser l’accès « Ne pas déranger »'),
              ),
            ),
          ),
      ],
    );
  }
}

class _ShortcutTiles extends ConsumerWidget {
  const _ShortcutTiles();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.read(homeIntegrationProvider);
    void hint(String text) =>
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(text)));
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.widgets_rounded),
          title: const Text('Ajouter le widget à l’écran d’accueil'),
          subtitle: const Text('Lance le minuteur en un geste'),
          onTap: () async {
            if (!await home.requestPinWidget()) {
              hint('Appui long sur l’écran d’accueil → Widgets → Pomodocus.');
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.dashboard_customize_rounded),
          title: const Text('Ajouter la tuile Réglages rapides'),
          subtitle: const Text('Démarrez depuis le volet de notifications'),
          onTap: () async {
            if (!await home.requestAddTile()) {
              hint(
                'Ouvrez les Réglages rapides, touchez ✎ Modifier et faites '
                'glisser la tuile Pomodocus.',
              );
            }
          },
        ),
      ],
    );
  }
}
