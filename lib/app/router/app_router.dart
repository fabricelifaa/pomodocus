import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../core/providers.dart';
import '../../shared/widgets/motion.dart';
import '../../features/focus/presentation/screens/fullscreen_timer_screen.dart';
import '../../features/splash/splash_screen.dart';
import 'app_modules.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Read once: changing the navigation requires a restart, which keeps the
  // active timer screen stable while the app is in use.
  final modules = enabledModules(ref.read(remoteConfigProvider));
  final router = GoRouter(
    // Navigation breadcrumbs in Sentry reports (no-op when Sentry is off).
    observers: [SentryNavigatorObserver()],
    initialLocation: ref.read(showSplashProvider)
        ? SplashScreen.path
        : '/focus',
    routes: [
      GoRoute(
        path: SplashScreen.path,
        pageBuilder: (context, state) => CustomTransitionPage(
          name: state.uri.path,
          child: const SplashScreen(),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          transitionsBuilder: (_, _, _, child) => child,
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) =>
            AppShell(shell: shell, modules: modules),
        branches: [
          for (final m in modules)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: m.path,
                  pageBuilder: (context, state) =>
                      NoTransitionPage(name: m.path, child: m.builder(context)),
                  routes: m.routes,
                ),
              ],
            ),
        ],
      ),
      // Outside the shell: no bottom navigation in full-screen mode.
      GoRoute(
        path: FullscreenTimerScreen.path,
        pageBuilder: (context, state) => CustomTransitionPage(
          name: state.uri.path,
          child: const FullscreenTimerScreen(),
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 250),
          transitionsBuilder: (context, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell, required this.modules});

  final StatefulNavigationShell shell;
  final List<AppModule> modules;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _FadeIndexedSwitch(index: shell.currentIndex, child: shell),
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: [
          for (final m in modules)
            NavigationDestination(
              icon: Icon(m.icon),
              selectedIcon: Icon(m.selectedIcon),
              label: m.label,
            ),
        ],
      ),
    );
  }
}

/// Short cross-fade when switching tabs (state of each tab is preserved by
/// the indexed stack).
class _FadeIndexedSwitch extends StatefulWidget {
  const _FadeIndexedSwitch({required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  State<_FadeIndexedSwitch> createState() => _FadeIndexedSwitchState();
}

class _FadeIndexedSwitchState extends State<_FadeIndexedSwitch>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 1,
  );

  @override
  void didUpdateWidget(covariant _FadeIndexedSwitch old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index && !reduceMotion(context)) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: Tween(begin: 0.0, end: 1.0).animate(curve),
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.015),
          end: Offset.zero,
        ).animate(curve),
        child: widget.child,
      ),
    );
  }
}
