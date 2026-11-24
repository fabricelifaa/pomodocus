import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodocus/core/services/home_integration_service.dart';
import 'package:pomodocus/features/focus/domain/entities/active_timer_state.dart';
import 'package:pomodocus/features/focus/presentation/screens/fullscreen_timer_screen.dart';
import 'package:pomodocus/features/focus/presentation/widgets/flip_clock.dart';
import 'package:pomodocus/features/settings/data/settings_repository.dart';
import 'package:pomodocus/features/settings/domain/pomodoro_settings.dart';
import 'package:pomodocus/features/splash/splash_screen.dart';
import 'package:pomodocus/features/statistics/presentation/statistics_screen.dart';

import 'app_test.dart' show pumpApp, settle;

Future<void> openFullscreen(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Plein écran'));
  await settle(tester, const Duration(milliseconds: 600));
}

void main() {
  test('new full-screen settings persist through JSON', () {
    final s = PomodoroSettings.defaults.copyWith(
      fullscreenClockStyle: ClockStyle.flip,
      fullscreenTickSound: false,
      fullscreenDnd: false,
    );
    expect(PomodoroSettings.fromJson(s.toJson()), s);
    const d = PomodoroSettings.defaults;
    expect(d.fullscreenClockStyle, ClockStyle.digital);
    expect(d.fullscreenTickSound, isTrue);
    expect(d.fullscreenDnd, isTrue);
    // Unknown value falls back to digital.
    expect(
      PomodoroSettings.fromJson({'fullscreenClockStyle': 'nixie'})
          .fullscreenClockStyle,
      ClockStyle.digital,
    );
  });

  group('splash', () {
    testWidgets('shows the logo and slogan for 3 s, then Focus', (
      tester,
    ) async {
      await pumpApp(tester, configure: (d) => d.splash = true);
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.text('pomodocus'), findsOneWidget);
      expect(find.text('Focus on what matters.'), findsOneWidget);
      expect(find.text('FOCUS. WORK. REPEAT.'), findsOneWidget);
      await settle(tester, const Duration(milliseconds: 2600));
      expect(find.byType(SplashScreen), findsNothing);
      expect(find.text('25:00'), findsOneWidget);
    });

    testWidgets('a tap skips it', (tester) async {
      await pumpApp(tester, configure: (d) => d.splash = true);
      await tester.tap(find.byType(SplashScreen));
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.byType(SplashScreen), findsNothing);
      expect(find.text('Démarrer'), findsOneWidget);
    });
  });

  group('full-screen clock', () {
    testWidgets('switches between digital and flip clock', (tester) async {
      final deps = await pumpApp(tester);
      await openFullscreen(tester);
      expect(find.text('25:00'), findsOneWidget);
      expect(find.byType(FlipClock), findsNothing);

      await tester.tap(find.byTooltip('Horloge à volets'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.byType(FlipClock), findsOneWidget);
      expect(find.byType(FlipDigit), findsNWidgets(4));
      expect(find.text('25:00'), findsNothing);
      expect(deps.prefs.getString(SettingsRepository.key), contains('flip'));

      // Runs and flips without layout errors.
      await tester.tap(find.text('Démarrer'));
      await settle(tester, const Duration(milliseconds: 300));
      for (var i = 0; i < 3; i++) {
        deps.clock.advance(const Duration(seconds: 1));
        await settle(tester, const Duration(milliseconds: 500));
      }
      expect(tester.takeException(), isNull);

      // Controls are still visible (they hide 4 s after the start).
      await tester.tap(find.byTooltip('Horloge numérique'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.byType(FlipClock), findsNothing);
    });

    testWidgets('flip clock fits a small landscape screen', (tester) async {
      await pumpApp(
        tester,
        size: const Size(740, 360),
        prefs: {SettingsRepository.key: '{"fullscreenClockStyle":"flip"}'},
      );
      await openFullscreen(tester);
      expect(find.byType(FlipClock), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ticks each second with the style sound, mutable', (
      tester,
    ) async {
      final deps = await pumpApp(tester);
      await openFullscreen(tester);
      await tester.tap(find.text('Démarrer'));
      await settle(tester, const Duration(milliseconds: 300));
      for (var i = 0; i < 3; i++) {
        deps.clock.advance(const Duration(seconds: 1));
        await settle(tester, const Duration(milliseconds: 300));
      }
      expect(deps.ticks.ticks, hasLength(3));
      expect(deps.ticks.ticks.toSet(), {ClockStyle.digital});

      // Controls are still visible (they hide 4 s after the start).
      await tester.tap(find.byTooltip('Couper le tic-tac'));
      await settle(tester, const Duration(milliseconds: 300));
      deps.clock.advance(const Duration(seconds: 2));
      await settle(tester, const Duration(milliseconds: 600));
      expect(deps.ticks.ticks, hasLength(3));
      expect(find.byTooltip('Activer le tic-tac'), findsOneWidget);
    });

    testWidgets('no tick while idle or paused', (tester) async {
      final deps = await pumpApp(tester);
      await openFullscreen(tester);
      deps.clock.advance(const Duration(seconds: 5));
      await settle(tester, const Duration(milliseconds: 600));
      expect(deps.ticks.ticks, isEmpty);
    });
  });

  group('do not disturb', () {
    testWidgets('on while in full screen, restored on exit', (tester) async {
      final deps = await pumpApp(tester);
      await openFullscreen(tester);
      expect(deps.dnd.active, isTrue);
      expect(find.byTooltip('Désactiver « Ne pas déranger »'), findsOneWidget);
      await tester.tap(find.byTooltip('Quitter le plein écran'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(deps.dnd.active, isFalse);
    });

    testWidgets('the button turns it off and remembers', (tester) async {
      final deps = await pumpApp(tester);
      await openFullscreen(tester);
      await tester.tap(find.byTooltip('Désactiver « Ne pas déranger »'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(deps.dnd.active, isFalse);
      expect(find.byTooltip('Activer « Ne pas déranger »'), findsOneWidget);
      expect(
        deps.prefs.getString(SettingsRepository.key),
        contains('"fullscreenDnd":false'),
      );
    });

    testWidgets('setting off: DND untouched', (tester) async {
      final deps = await pumpApp(
        tester,
        prefs: {SettingsRepository.key: '{"fullscreenDnd":false}'},
      );
      await openFullscreen(tester);
      expect(deps.dnd.active, isFalse);
    });

    testWidgets('without access, asks to grant it', (tester) async {
      final deps = await pumpApp(
        tester,
        prefs: {SettingsRepository.key: '{"fullscreenDnd":false}'},
        configure: (d) => d.dnd.access = false,
      );
      await openFullscreen(tester);
      await tester.tap(find.byTooltip('Activer « Ne pas déranger »'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Activer « Ne pas déranger »'), findsOneWidget);
      await tester.tap(find.text('Autoriser'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(deps.dnd.requests, 1);
      expect(deps.dnd.active, isFalse);
    });
  });

  group('widget, tile and shortcuts', () {
    testWidgets('launched with "start": timer running, no splash', (
      tester,
    ) async {
      await pumpApp(
        tester,
        configure: (d) => d.home.initial = LaunchAction.start,
      );
      expect(find.byType(SplashScreen), findsNothing);
      expect(find.text('Pause'), findsOneWidget);
    });

    testWidgets('"fullscreen" action while running opens full screen', (
      tester,
    ) async {
      final deps = await pumpApp(tester);
      deps.home.controller.add(LaunchAction.fullscreen);
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.byType(FullscreenTimerScreen), findsOneWidget);
      // Started, and opened only once.
      expect(find.byType(FullscreenTimerScreen), findsOneWidget);
      expect(deps.home.published.last.$1, TimerStatus.running);
    });

    testWidgets('"stats" action opens the statistics', (tester) async {
      final deps = await pumpApp(tester);
      deps.home.controller.add(LaunchAction.stats);
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byType(StatisticsScreen), findsOneWidget);
    });

    testWidgets('timer state is published on every change', (tester) async {
      final deps = await pumpApp(tester);
      expect(deps.home.published.last, (TimerStatus.idle, 1500));
      await tester.tap(find.text('Démarrer'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(deps.home.published.last.$1, TimerStatus.running);
      await tester.tap(find.text('Pause'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(deps.home.published.last.$1, TimerStatus.paused);
    });

    testWidgets('settings offer the widget and the tile', (tester) async {
      await pumpApp(tester, size: const Size(400, 3000));
      await tester.tap(find.text('Paramètres'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('RACCOURCIS'), findsOneWidget);
      expect(
        find.text('Ajouter le widget à l’écran d’accueil'),
        findsOneWidget,
      );
      expect(find.text('Ajouter la tuile Réglages rapides'), findsOneWidget);
      expect(find.text('Ne pas déranger en plein écran'), findsOneWidget);
      expect(find.text('À volets'), findsOneWidget);
    });
  });
}
