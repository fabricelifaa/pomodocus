import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// How the phone is physically held, whatever the UI orientation lock.
enum PhysicalOrientation { portrait, landscape }

/// Reports the physical orientation of the device. The UI stays locked to
/// portrait in standard mode, so the rotation is read from the accelerometer.
/// Abstract so that widgets stay testable.
abstract interface class DeviceOrientationService {
  /// Debounced, distinct changes. A phone lying flat or tilted ambiguously
  /// emits nothing, so putting it down on a desk never toggles anything.
  Stream<PhysicalOrientation> watch();
}

class SensorDeviceOrientationService implements DeviceOrientationService {
  SensorDeviceOrientationService({
    this.settle = const Duration(milliseconds: 450),
  });

  /// The new orientation must hold this long before it is reported.
  final Duration settle;

  /// Gravity is ~9.8 m/s². A dominant axis above this value means the phone
  /// is clearly held upright or sideways (not flat, not mid-rotation).
  static const _threshold = 6.5;

  @visibleForTesting
  static PhysicalOrientation? classify(double x, double y, double z) {
    final ax = x.abs(), ay = y.abs(), az = z.abs();
    if (az > ax && az > ay) return null; // Flat on a table.
    if (ax > _threshold && ax > ay * 1.6) return PhysicalOrientation.landscape;
    // Upright only (y > 0): upside-down is not a supported UI orientation.
    if (y > _threshold && ay > ax * 1.6) return PhysicalOrientation.portrait;
    return null;
  }

  @override
  Stream<PhysicalOrientation> watch() {
    late StreamController<PhysicalOrientation> out;
    StreamSubscription<AccelerometerEvent>? sub;
    Timer? pending;
    PhysicalOrientation? candidate;
    PhysicalOrientation? last;

    void onEvent(AccelerometerEvent e) {
      final o = classify(e.x, e.y, e.z);
      if (o == null || o == candidate) return;
      candidate = o;
      pending?.cancel();
      pending = Timer(settle, () {
        if (o != last) {
          last = o;
          out.add(o);
        }
      });
    }

    out = StreamController<PhysicalOrientation>(
      onListen: () {
        try {
          sub =
              accelerometerEventStream(
                samplingPeriod: SensorInterval.normalInterval,
              ).listen(
                onEvent,
                onError: (Object e) {
                  debugPrint('accelerometer unavailable: $e');
                },
                cancelOnError: true,
              );
        } catch (e) {
          debugPrint('accelerometer unavailable: $e');
        }
      },
      onPause: () => sub?.pause(),
      onResume: () => sub?.resume(),
      onCancel: () async {
        pending?.cancel();
        await sub?.cancel();
      },
    );
    return out.stream;
  }
}

/// Tests: set the orientation by hand. Like the sensor, a new listener first
/// receives the current orientation.
class FakeDeviceOrientationService implements DeviceOrientationService {
  final _changes = StreamController<PhysicalOrientation>.broadcast();
  PhysicalOrientation? current;

  void set(PhysicalOrientation o) {
    current = o;
    _changes.add(o);
  }

  @override
  Stream<PhysicalOrientation> watch() async* {
    final now = current;
    if (now != null) yield now;
    yield* _changes.stream;
  }
}
