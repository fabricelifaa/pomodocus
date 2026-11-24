import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodocus/features/focus/presentation/screens/fullscreen_timer_screen.dart';
import 'package:pomodocus/features/settings/data/settings_repository.dart';
import 'package:pomodocus/features/settings/domain/pomodoro_settings.dart';

import 'app_test.dart' show pumpApp, settle;

void main() {
  test('fullscreen settings persist through JSON', () {
    final s = PomodoroSettings.defaults.copyWith(
      fullscreenEnabled: false,
      fullscreenAutoOpen: true,
    );
    expect(PomodoroSettings.fromJson(s.toJson()), s);
    expect(PomodoroSettings.defaults.fullscreenEnabled, isTrue);
    expect(PomodoroSettings.defaults.fullscreenAutoOpen, isFalse);
  });

  testWidgets('opens landscape full screen and comes back', (tester) async {
    final deps = await pumpApp(tester);
    await tester.tap(find.byTooltip('Plein écran'));
    await settle(tester, const Duration(milliseconds: 600));
    expect(find.byType(FullscreenTimerScreen), findsOneWidget);
    expect(deps.display.fullscreen, isTrue);
    expect(find.text('25:00'), findsOneWidget);
    expect(find.text('CONCENTRATION'), findsOneWidget);
    // No bottom navigation in full screen.
    expect(find.byType(NavigationBar), findsNothing);

    await tester.tap(find.text('Démarrer'));
    await settle(tester, const Duration(milliseconds: 400));
    deps.clock.advance(const Duration(minutes: 2));
    await settle(tester, const Duration(milliseconds: 600));
    expect(find.text('23:00'), findsOneWidget);

    // Controls auto-hide while running, a tap brings them back.
    await settle(tester, const Duration(seconds: 5));
    await tester.tapAt(const Offset(200, 300));
    await settle(tester, const Duration(milliseconds: 400));
    await tester.tap(find.byTooltip('Quitter le plein écran'));
    await settle(tester, const Duration(milliseconds: 600));
    expect(find.byType(FullscreenTimerScreen), findsNothing);
    expect(deps.display.fullscreen, isFalse);
    // The session kept running.
    expect(find.text('Pause'), findsOneWidget);
  });

  testWidgets('auto-opens on start when enabled', (tester) async {
    final deps = await pumpApp(
      tester,
      prefs: {
        SettingsRepository.key: '{"fullscreenAutoOpen":true}',
        SettingsRepository.notificationPromptKey: true,
      },
    );
    await tester.tap(find.text('Démarrer'));
    await settle(tester, const Duration(milliseconds: 800));
    expect(find.byType(FullscreenTimerScreen), findsOneWidget);
    expect(deps.display.fullscreen, isTrue);
  });

  testWidgets('button hidden when the setting is off', (tester) async {
    await pumpApp(
      tester,
      prefs: {SettingsRepository.key: '{"fullscreenEnabled":false}'},
    );
    expect(find.byTooltip('Plein écran'), findsNothing);
  });

  testWidgets('landscape layout does not overflow', (tester) async {
    await pumpApp(tester, size: const Size(740, 360));
    await tester.tap(find.byTooltip('Plein écran'));
    await settle(tester, const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
    expect(find.byType(FullscreenTimerScreen), findsOneWidget);
  });
}
