import 'package:flutter/foundation.dart';

/// Sentry settings, injected at build time from the `.env` file:
///
///   flutter run --dart-define-from-file=.env
///
/// See `.env.example`. Without a DSN, Sentry is not started at all (local
/// development, tests), so the app behaves exactly as before.
abstract final class SentryConfig {
  static const dsn = String.fromEnvironment('SENTRY_DSN');

  static const environment = String.fromEnvironment(
    'SENTRY_ENVIRONMENT',
    defaultValue: kReleaseMode ? 'production' : 'development',
  );

  /// Optional: overrides the default release name (`bundleId@version+build`).
  static const release = String.fromEnvironment('SENTRY_RELEASE');

  /// Share of transactions sent for performance monitoring, 0 to 1.
  static final double tracesSampleRate =
      (double.tryParse(
                const String.fromEnvironment(
                  'SENTRY_TRACES_SAMPLE_RATE',
                  defaultValue: '0',
                ),
              ) ??
              0)
          .clamp(0.0, 1.0);

  static bool get enabled => dsn.isNotEmpty;
}
