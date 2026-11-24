import 'package:package_info_plus/package_info_plus.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

enum UpdateState {
  /// OTA updates are not available (debug build, or not built with
  /// `shorebird release`).
  unavailable,
  upToDate,
  available,
  downloading,

  /// A patch was downloaded and will be applied at next launch.
  restartRequired,
  failed,
}

class AppVersionInfo {
  const AppVersionInfo({
    required this.version,
    required this.buildNumber,
    this.patchNumber,
  });

  final String version;
  final String buildNumber;
  final int? patchNumber;

  String get label =>
      'v$version ($buildNumber)${patchNumber != null ? ' · patch $patchNumber' : ''}';
}

/// Abstract so that the UI does not depend on Shorebird directly.
abstract interface class UpdateService {
  Future<AppVersionInfo> versionInfo();

  Future<UpdateState> check();

  /// Downloads an available patch. Never blocks the app.
  Future<UpdateState> download();
}

class ShorebirdUpdateService implements UpdateService {
  ShorebirdUpdateService([ShorebirdUpdater? updater])
    : _updater = updater ?? ShorebirdUpdater();

  final ShorebirdUpdater _updater;

  @override
  Future<AppVersionInfo> versionInfo() async {
    final info = await PackageInfo.fromPlatform();
    int? patch;
    if (_updater.isAvailable) {
      try {
        patch = (await _updater.readCurrentPatch())?.number;
      } catch (_) {}
    }
    return AppVersionInfo(
      version: info.version,
      buildNumber: info.buildNumber,
      patchNumber: patch,
    );
  }

  @override
  Future<UpdateState> check() async {
    if (!_updater.isAvailable) return UpdateState.unavailable;
    try {
      final status = await _updater.checkForUpdate().timeout(
        const Duration(seconds: 10),
      );
      return switch (status) {
        UpdateStatus.upToDate => UpdateState.upToDate,
        UpdateStatus.outdated => UpdateState.available,
        UpdateStatus.restartRequired => UpdateState.restartRequired,
        UpdateStatus.unavailable => UpdateState.unavailable,
      };
    } catch (_) {
      return UpdateState.failed;
    }
  }

  @override
  Future<UpdateState> download() async {
    if (!_updater.isAvailable) return UpdateState.unavailable;
    try {
      await _updater.update();
      return UpdateState.restartRequired;
    } catch (_) {
      return UpdateState.failed;
    }
  }
}
