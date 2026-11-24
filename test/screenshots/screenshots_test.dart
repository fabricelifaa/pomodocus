// Renders real-font screenshots of the main screens for visual review.
// Run: flutter test test/screenshots --update-goldens --tags screenshots
@Tags(['screenshots'])
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodocus/app/app.dart';
import 'package:pomodocus/features/focus/domain/entities/focus_session.dart';
import 'package:pomodocus/features/focus/domain/entities/session_type.dart';
import 'package:pomodocus/features/settings/data/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';
import '../widget/app_test.dart' show settle;

Future<void> _loadFonts() async {
  final manrope = FontLoader('Manrope');
  for (final w in [400, 500, 600, 700, 800]) {
    manrope.addFont(rootBundle.load('assets/fonts/Manrope-$w.ttf'));
  }
  await manrope.load();
  final sdk = Platform.environment['FLUTTER_ROOT'] ?? 'D:/apps/flutter';
  final icons = File(
    '$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (icons.existsSync()) {
    final loader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
    await loader.load();
  }
}

void main() {
  setUpAll(_loadFonts);

  Future<TestDeps> shoot(
    WidgetTester tester,
    String name, {
    String theme = 'light',
    Future<void> Function(TestDeps)? act,
    bool seed = false,
    Size size = const Size(1179, 2556),
    String settings = '',
    bool splash = false,
    Duration finalSettle = const Duration(milliseconds: 1500),
  }) async {
    SharedPreferences.setMockInitialValues({
      SettingsRepository.key: '{"themeMode":"$theme"$settings}',
      SettingsRepository.notificationPromptKey: true,
    });
    final deps = TestDeps(
      await SharedPreferences.getInstance(),
      now: DateTime(2026, 11, 24, 16, 20),
    )..splash = splash;
    if (seed) {
      var i = 0;
      for (final (d, n) in [
        (6, 3),
        (5, 5),
        (4, 2),
        (3, 6),
        (2, 4),
        (1, 7),
        (0, 3),
      ]) {
        for (var k = 0; k < n; k++) {
          final start = DateTime(2026, 11, 24 - d, 9 + k);
          await deps.sessions.record(
            FocusSession(
              id: 's${i++}',
              type: SessionType.focus,
              startedAt: start,
              plannedDurationSeconds: 1500,
              endedAt: start.add(const Duration(minutes: 25)),
              actualDurationSeconds: k == 1 && d == 0 ? 640 : 1500,
              status: k == 1 && d == 0
                  ? SessionStatus.interrupted
                  : SessionStatus.completed,
              cycleNumber: k % 4 + 1,
            ),
          );
        }
      }
      await deps.sessions.record(
        FocusSession(
          id: 'brk',
          type: SessionType.shortBreak,
          startedAt: DateTime(2026, 11, 24, 12, 30),
          plannedDurationSeconds: 300,
          endedAt: DateTime(2026, 11, 24, 12, 35),
          actualDurationSeconds: 300,
          status: SessionStatus.completed,
          cycleNumber: 2,
        ),
      );
    }
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: deps.overrides.cast(),
        child: const PomodocusApp(),
      ),
    );
    await settle(tester, const Duration(seconds: 1));
    if (act != null) await act(deps);
    await settle(tester, finalSettle);
    await expectLater(
      find.byType(PomodocusApp),
      matchesGoldenFile('goldens/$name.png'),
    );
    return deps;
  }

  testWidgets('focus idle light', (t) => shoot(t, 'focus_idle_light'));
  testWidgets(
    'splash light',
    (t) => shoot(t, 'splash_light', splash: true),
  );
  testWidgets(
    'splash dark',
    (t) => shoot(t, 'splash_dark', theme: 'dark', splash: true),
  );
  testWidgets('fullscreen flip clock', (t) async {
    await shoot(
      t,
      'fullscreen_flip',
      size: const Size(2556, 1179),
      settings: ',"fullscreenClockStyle":"flip"',
      act: (d) async {
        await t.tap(find.byTooltip('Plein écran'));
        await settle(t, const Duration(milliseconds: 600));
        await t.tap(find.text('Démarrer'));
        await settle(t, const Duration(milliseconds: 400));
        d.clock.advance(const Duration(minutes: 7, seconds: 41));
        await settle(t, const Duration(milliseconds: 1200));
      },
    );
  });
  testWidgets('fullscreen flip clock mid-flip', (t) async {
    await shoot(
      t,
      'fullscreen_flip_mid',
      size: const Size(2556, 1179),
      settings: ',"fullscreenClockStyle":"flip"',
      finalSettle: Duration.zero,
      act: (d) async {
        await t.tap(find.byTooltip('Plein écran'));
        await settle(t, const Duration(milliseconds: 600));
        await t.tap(find.text('Démarrer'));
        await settle(t, const Duration(seconds: 5));
        d.clock.advance(const Duration(minutes: 7, seconds: 40));
        await settle(t, const Duration(milliseconds: 1200));
        d.clock.advance(const Duration(seconds: 1));
        await t.pump(const Duration(milliseconds: 250));
        await t.pump(const Duration(milliseconds: 90));
      },
    );
  });
  testWidgets(
    'focus idle dark',
    (t) => shoot(t, 'focus_idle_dark', theme: 'dark'),
  );
  testWidgets('focus running', (t) async {
    await shoot(
      t,
      'focus_running_light',
      act: (d) async {
        await t.tap(find.text('Démarrer'));
        await settle(t, const Duration(milliseconds: 400));
        d.clock.advance(const Duration(minutes: 9, seconds: 12));
        await settle(t, const Duration(milliseconds: 1500));
      },
    );
  });
  testWidgets('break dark', (t) async {
    await shoot(
      t,
      'break_dark',
      theme: 'dark',
      act: (d) async {
        await t.tap(find.text('Démarrer'));
        await settle(t, const Duration(milliseconds: 400));
        d.clock.advance(const Duration(minutes: 25));
        await settle(t, const Duration(seconds: 3));
      },
    );
  });
  testWidgets('stats light', (t) async {
    await shoot(
      t,
      'stats_light',
      seed: true,
      act: (d) async {
        await t.tap(find.text('Statistiques'));
        await settle(t, const Duration(seconds: 1));
      },
    );
  });
  testWidgets('stats empty dark', (t) async {
    await shoot(
      t,
      'stats_empty_dark',
      theme: 'dark',
      act: (d) async {
        await t.tap(find.text('Statistiques'));
        await settle(t, const Duration(seconds: 1));
      },
    );
  });
  testWidgets('settings light', (t) async {
    await shoot(
      t,
      'settings_light',
      act: (d) async {
        await t.tap(find.text('Paramètres'));
        await settle(t, const Duration(seconds: 1));
      },
    );
  });
  testWidgets('fullscreen landscape running', (t) async {
    await shoot(
      t,
      'fullscreen_running',
      size: const Size(2556, 1179),
      act: (d) async {
        await t.tap(find.byTooltip('Plein écran'));
        await settle(t, const Duration(milliseconds: 600));
        await t.tap(find.text('Démarrer'));
        await settle(t, const Duration(milliseconds: 400));
        d.clock.advance(const Duration(minutes: 7, seconds: 41));
        await settle(t, const Duration(milliseconds: 1200));
      },
    );
  });
  testWidgets('fullscreen landscape controls hidden', (t) async {
    await shoot(
      t,
      'fullscreen_clean',
      size: const Size(2556, 1179),
      act: (d) async {
        await t.tap(find.byTooltip('Plein écran'));
        await settle(t, const Duration(milliseconds: 600));
        await t.tap(find.text('Démarrer'));
        d.clock.advance(const Duration(minutes: 12, seconds: 3));
        await settle(t, const Duration(seconds: 5));
      },
    );
  });
}
