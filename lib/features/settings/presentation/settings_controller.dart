import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../domain/pomodoro_settings.dart';

final settingsProvider = NotifierProvider<SettingsController, PomodoroSettings>(
  SettingsController.new,
);

class SettingsController extends Notifier<PomodoroSettings> {
  @override
  PomodoroSettings build() => ref.watch(settingsRepositoryProvider).load();

  Future<void> update(
    PomodoroSettings Function(PomodoroSettings) change,
  ) async {
    final next = change(state).validated();
    if (next == state) return;
    state = next;
    await ref.read(settingsRepositoryProvider).save(next);
  }
}
