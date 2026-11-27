import 'package:flutter_test/flutter_test.dart';
import 'package:pomodocus/core/services/device_orientation_service.dart';
import 'package:pomodocus/features/focus/presentation/screens/fullscreen_timer_screen.dart';
import 'package:pomodocus/features/settings/data/settings_repository.dart';
import 'package:pomodocus/features/settings/domain/pomodoro_settings.dart';

import '../helpers.dart';
import 'app_test.dart' show pumpApp, settle;

void main() {
  const landscape = PhysicalOrientation.landscape;
  const portrait = PhysicalOrientation.portrait;

  Future<void> turn(
    WidgetTester tester,
    TestDeps deps,
    PhysicalOrientation o,
  ) async {
    deps.orientation.set(o);
    await settle(tester, const Duration(milliseconds: 600));
  }

  test('accelerometer readings map to orientations', () {
    const c = SensorDeviceOrientationService.classify;
    expect(c(0.3, 9.7, 0.5), portrait);
    expect(c(9.6, 0.4, 1.0), landscape);
    expect(c(-9.6, 0.4, 1.0), landscape);
    expect(c(0.2, 0.3, 9.8), isNull, reason: 'flat on a table');
    expect(c(6.8, 6.9, 0.5), isNull, reason: 'mid-rotation');
    expect(c(0.3, -9.7, 0.5), isNull, reason: 'upside down');
  });

  test('rotation setting defaults to on and persists', () {
    expect(PomodoroSettings.defaults.fullscreenOnRotate, isTrue);
    final s = PomodoroSettings.defaults.copyWith(fullscreenOnRotate: false);
    expect(PomodoroSettings.fromJson(s.toJson()).fullscreenOnRotate, isFalse);
  });

  testWidgets('turning the phone opens full screen, upright closes it', (
    tester,
  ) async {
    final deps = await pumpApp(tester);
    await turn(tester, deps, landscape);
    expect(find.byType(FullscreenTimerScreen), findsOneWidget);
    expect(deps.display.fullscreen, isTrue);

    await turn(tester, deps, portrait);
    expect(find.byType(FullscreenTimerScreen), findsNothing);
    expect(deps.display.fullscreen, isFalse);

    // And again.
    await turn(tester, deps, landscape);
    expect(find.byType(FullscreenTimerScreen), findsOneWidget);
  });

  testWidgets('leaving with the button while sideways does not reopen', (
    tester,
  ) async {
    final deps = await pumpApp(tester);
    await turn(tester, deps, landscape);
    await tester.tap(find.byTooltip('Quitter le plein écran'));
    await settle(tester, const Duration(milliseconds: 600));
    expect(find.byType(FullscreenTimerScreen), findsNothing);
    // Still sideways: nothing new from the sensor, the screen stays closed.
    await settle(tester, const Duration(seconds: 1));
    expect(find.byType(FullscreenTimerScreen), findsNothing);
  });

  testWidgets('opened with the button while upright, stays open', (
    tester,
  ) async {
    final deps = await pumpApp(tester);
    await tester.tap(find.byTooltip('Plein écran'));
    await settle(tester, const Duration(milliseconds: 600));
    await turn(tester, deps, portrait);
    expect(find.byType(FullscreenTimerScreen), findsOneWidget);
  });

  testWidgets('no rotation full screen on other tabs', (tester) async {
    final deps = await pumpApp(tester);
    await tester.tap(find.text('Statistiques'));
    await settle(tester, const Duration(milliseconds: 400));
    await turn(tester, deps, landscape);
    expect(find.byType(FullscreenTimerScreen), findsNothing);
  });

  testWidgets('setting off: rotation is ignored', (tester) async {
    final deps = await pumpApp(
      tester,
      prefs: {SettingsRepository.key: '{"fullscreenOnRotate":false}'},
    );
    await turn(tester, deps, landscape);
    expect(find.byType(FullscreenTimerScreen), findsNothing);
  });
}
