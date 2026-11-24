import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/active_timer_state.dart';
import '../domain/entities/session_type.dart';
import 'controllers/notification_permission_controller.dart';
import 'controllers/timer_controller.dart';

/// User actions shared by the Focus screen and the full-screen countdown.
abstract final class FocusActions {
  /// Start (with the contextual notification prompt), pause or resume.
  static Future<void> primary(
    BuildContext context,
    WidgetRef ref,
    ActiveTimerState t,
  ) async {
    final ctl = ref.read(timerControllerProvider.notifier);
    if (!t.isIdle) return ctl.toggle();
    await ctl.start();
    if (context.mounted) {
      await ref
          .read(notificationPermissionProvider.notifier)
          .maybeAskInContext(context);
    }
  }

  /// Stops a started session after confirmation, or resets the set when idle.
  static Future<void> reset(
    BuildContext context,
    WidgetRef ref,
    ActiveTimerState t,
  ) async {
    final ctl = ref.read(timerControllerProvider.notifier);
    if (t.isIdle) return ctl.reset();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Arrêter la session ?'),
        content: Text(
          t.type == SessionType.focus
              ? 'Ce Pomodoro sera enregistré comme interrompu et ne comptera '
                    'pas comme une session terminée.'
              : 'La pause sera interrompue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continuer'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Arrêter'),
          ),
        ],
      ),
    );
    if (ok == true) await ctl.reset();
  }
}
