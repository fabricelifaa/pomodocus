import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers.dart';
import '../../../../core/services/notification_service.dart';

final notificationPermissionProvider =
    AsyncNotifierProvider<
      NotificationPermissionController,
      NotificationPermission
    >(NotificationPermissionController.new);

class NotificationPermissionController
    extends AsyncNotifier<NotificationPermission> {
  @override
  Future<NotificationPermission> build() =>
      ref.read(notificationServiceProvider).permissionStatus();

  Future<NotificationPermission> request() async {
    final result = await ref
        .read(notificationServiceProvider)
        .requestPermission();
    // Re-read the real status (the request result can be null on some OS).
    final status = await ref
        .read(notificationServiceProvider)
        .permissionStatus();
    final value = status == NotificationPermission.unknown ? result : status;
    state = AsyncData(value);
    return value;
  }

  Future<void> refresh() async {
    state = AsyncData(
      await ref.read(notificationServiceProvider).permissionStatus(),
    );
  }

  /// Shows a short, contextual explanation the first time the user starts a
  /// session, then asks the OS. Never blocks starting the timer.
  Future<void> maybeAskInContext(BuildContext context) async {
    final settingsRepo = ref.read(settingsRepositoryProvider);
    if (settingsRepo.notificationPromptShown) return;
    final current = await ref
        .read(notificationServiceProvider)
        .permissionStatus();
    await settingsRepo.markNotificationPromptShown();
    if (current == NotificationPermission.granted) return;
    if (!context.mounted) return;
    final accept = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.notifications_active_rounded, size: 32),
        title: const Text('Être prévenu à la fin ?'),
        content: const Text(
          'Pomodocus peut vous envoyer une notification quand une session '
          'se termine, même si l’application est en arrière-plan ou que '
          'l’écran est verrouillé. Rien d’autre.',
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
    if (accept == true) await request();
  }
}
