import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodocus/app/app.dart';
import 'package:pomodocus/app/theme/app_colors.dart';
import 'package:pomodocus/core/services/notification_service.dart';
import 'package:pomodocus/features/settings/data/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';

Future<TestDeps> pumpApp(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
  Size size = const Size(400, 860),
  void Function(TestDeps deps)? configure,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final deps = TestDeps(await SharedPreferences.getInstance());
  configure?.call(deps);
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: deps.overrides.cast(),
      child: const PomodocusApp(),
    ),
  );
  await settle(tester, const Duration(milliseconds: 800));
  return deps;
}

/// Pumps several frames: Riverpod delivers async updates on a later frame.
Future<void> settle(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 100);
  var elapsed = Duration.zero;
  while (elapsed < total) {
    await tester.pump(step);
    elapsed += step;
  }
  await tester.pump();
}

void main() {
  testWidgets('first launch shows a ready 25:00 focus session', (tester) async {
    await pumpApp(tester);
    expect(find.text('25:00'), findsOneWidget);
    expect(find.text('Concentration'), findsOneWidget);
    expect(find.text('Démarrer'), findsOneWidget);
    expect(find.text('Pomodoro 1 sur 4'), findsOneWidget);
  });

  testWidgets('start, pause and resume', (tester) async {
    final deps = await pumpApp(tester);
    await tester.tap(find.text('Démarrer'));
    await settle(tester, const Duration(milliseconds: 500));
    expect(find.text('Pause'), findsOneWidget);
    deps.clock.advance(const Duration(seconds: 61));
    await settle(tester, const Duration(milliseconds: 600));
    expect(find.text('23:59'), findsOneWidget);
    await tester.tap(find.text('Pause'));
    await settle(tester, const Duration(milliseconds: 500));
    expect(find.text('Reprendre'), findsOneWidget);
    expect(find.text('EN PAUSE'), findsOneWidget);
    await tester.tap(find.text('Reprendre'));
    await settle(tester, const Duration(milliseconds: 500));
    expect(find.text('Pause'), findsOneWidget);
  });

  testWidgets('end of a pomodoro moves to a short break', (tester) async {
    final deps = await pumpApp(tester);
    await tester.tap(find.text('Démarrer'));
    await settle(tester, const Duration(milliseconds: 300));
    deps.clock.advance(const Duration(minutes: 25));
    await settle(tester, const Duration(milliseconds: 600));
    await settle(tester, const Duration(seconds: 2));
    expect(find.text('Petite pause'), findsOneWidget);
    expect(find.text('05:00'), findsOneWidget);
    expect(deps.sessions.rows, hasLength(1));
    expect(deps.sound.plays, 1);
  });

  testWidgets('denied notifications show a banner and the contextual prompt', (
    tester,
  ) async {
    final deps = await pumpApp(
      tester,
      configure: (d) => d.notifications.status = NotificationPermission.denied,
    );
    expect(find.textContaining('Notifications désactivées'), findsOneWidget);
    await tester.tap(find.text('Démarrer'));
    await settle(tester, const Duration(milliseconds: 500));
    expect(find.text('Être prévenu à la fin ?'), findsOneWidget);
    await tester.tap(find.text('Plus tard'));
    await settle(tester, const Duration(milliseconds: 500));
    // The timer kept running regardless of the refusal.
    expect(find.text('Pause'), findsOneWidget);
    expect(
      deps.prefs.getBool(SettingsRepository.notificationPromptKey),
      isTrue,
    );
  });

  testWidgets('navigation between the three screens', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Statistiques'));
    await settle(tester, const Duration(milliseconds: 800));
    expect(find.text('Pas encore de session'), findsOneWidget);
    await tester.tap(find.text('Paramètres'));
    await settle(tester, const Duration(milliseconds: 800));
    expect(find.text('DURÉES'), findsOneWidget);
    await tester.tap(find.text('Focus'));
    await settle(tester, const Duration(milliseconds: 800));
    expect(find.text('Démarrer'), findsOneWidget);
  });

  testWidgets('dark theme from settings', (tester) async {
    await pumpApp(
      tester,
      prefs: {SettingsRepository.key: '{"themeMode":"dark"}'},
    );
    final ctx = tester.element(find.text('Démarrer'));
    expect(Theme.of(ctx).brightness, Brightness.dark);
    expect(Theme.of(ctx).scaffoldBackgroundColor, BrandColors.night);
  });

  testWidgets('small screen layout does not overflow', (tester) async {
    await pumpApp(tester, size: const Size(320, 568));
    expect(tester.takeException(), isNull);
    expect(find.text('Démarrer'), findsOneWidget);
  });

  testWidgets('back from background recomputes from the clock', (tester) async {
    final deps = await pumpApp(tester);
    await tester.tap(find.text('Démarrer'));
    await settle(tester, const Duration(milliseconds: 300));
    void go(AppLifecycleState s) =>
        tester.binding.handleAppLifecycleStateChanged(s);
    go(AppLifecycleState.inactive);
    go(AppLifecycleState.hidden);
    go(AppLifecycleState.paused);
    deps.clock.advance(const Duration(minutes: 30));
    go(AppLifecycleState.hidden);
    go(AppLifecycleState.inactive);
    go(AppLifecycleState.resumed);
    await settle(tester, const Duration(milliseconds: 300));
    await settle(tester, const Duration(seconds: 2));
    expect(find.text('Petite pause'), findsOneWidget);
    expect(deps.sessions.rows, hasLength(1));
  });
}
