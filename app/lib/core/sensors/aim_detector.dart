import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// `F-134` — **only scan when the phone is actually being aimed at something.**
///
/// ## The complaint
///
/// > *"it becomes a nuisance that if held in front of a QR for a while it keeps
/// > on scanning and giving pop ups"*
///
/// Two separate causes, and the de-duplication fixed only one of them. That
/// stopped the *same* code re-firing while held in view. It does nothing about
/// the case where the dashboard is simply open — in a pocket, on a table, in a
/// hand while you read the ledger — and the camera is grinding away at whatever
/// happens to be in front of it, waiting to ambush you with a sheet.
///
/// The camera should be looking when **you** are looking. Not otherwise.
///
/// ## Reading intent from one number
///
/// The accelerometer gives gravity's direction in device space. `z` is the axis
/// out of the screen, so with the phone:
///
/// | Position | `z` ≈ | Aimed at a code? |
/// |---|---|---|
/// | Flat on a table, screen up | `+9.8` | No |
/// | Face down / in a pocket | `−9.8` | No |
/// | **Held upright, camera at a counter** | **`0`** | **Yes** |
/// | Tilted ~30° from vertical | `±4.9` | Yes, comfortably |
///
/// So the whole test is `|z| < threshold`. No gyroscope integration, no drift,
/// no calibration, and nothing that needs to know which way north is. One axis,
/// one comparison, ~5 Hz.
///
/// ## Why the thresholds are two numbers and not one
///
/// A single cutoff makes the state flicker at exactly the angle people hold a
/// phone at. [_engageAt] is stricter than [_releaseAt] — it takes a more
/// deliberate aim to wake the camera than to keep it awake. That is standard
/// hysteresis, and without it this feature would be worse than no feature.
///
/// [_settle] then requires the phone to *stay* aimed for a moment before the
/// camera starts, so swinging the phone up to look at the ledger does not fire
/// the scanner on the way past.
///
/// ## What this is not
///
/// It is not a security control and not a privacy claim. The camera permission
/// is still granted, and a person who wants to scan can always tap. It exists
/// to stop the app being **rude**, which is a real bug even though nothing
/// crashes.
class AimDetector {
  AimDetector({
    this.onChanged,
    @visibleForTesting this.stream,
  });

  /// Called whenever [isAimed] flips. Never called for the same value twice.
  final void Function(bool aimed)? onChanged;

  /// Injectable for tests, which must not need a real accelerometer.
  @visibleForTesting
  final Stream<AccelerometerEvent>? stream;

  /// Below this the phone counts as raised. 4.0 m/s² is about **66° from
  /// horizontal** — a clear, deliberate aim.
  static const _engageAt = 4.0;

  /// It stays engaged until it passes this. About 52°, so a tiring arm does
  /// not switch the camera off mid-scan.
  static const _releaseAt = 6.4;

  /// How long it must hold before the camera starts. Long enough that lifting
  /// the phone to read something does not trip it; short enough that a
  /// deliberate raise feels instant.
  static const _settle = Duration(milliseconds: 350);

  StreamSubscription<AccelerometerEvent>? _sub;
  Timer? _settleTimer;

  bool _aimed = false;
  bool get isAimed => _aimed;

  /// True once a reading has arrived. Until then the camera runs — **a sensor
  /// that has not reported yet must never be read as "not aimed"**, or the app
  /// looks broken for the first second on every device that reports slowly, and
  /// completely broken on any device with no accelerometer at all.
  bool _hasReading = false;
  bool get hasReading => _hasReading;

  void start() {
    if (_sub != null) return;
    _aimed = true; // fail open until proven otherwise
    final source = stream ??
        accelerometerEventStream(
            samplingPeriod: const Duration(milliseconds: 200));
    _sub = source.listen(_onSample, onError: (_) {
      // No accelerometer, or the platform refused. Fail open and stay open:
      // a device without the sensor must behave exactly as it did before this
      // feature existed.
      _hasReading = false;
      _set(true);
    });
  }

  void _onSample(AccelerometerEvent e) {
    _hasReading = true;
    final z = e.z.abs();
    // Guard against a wild reading — a knock or a dropped phone can produce a
    // sample far beyond gravity, and treating that as "aimed" is noise.
    final magnitude = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
    if (magnitude > 25) return;

    if (_aimed) {
      if (z > _releaseAt) {
        _settleTimer?.cancel();
        _settleTimer = null;
        _set(false);
      }
      return;
    }

    if (z < _engageAt) {
      _settleTimer ??= Timer(_settle, () {
        _settleTimer = null;
        _set(true);
      });
    } else {
      _settleTimer?.cancel();
      _settleTimer = null;
    }
  }

  void _set(bool v) {
    if (_aimed == v) return;
    _aimed = v;
    onChanged?.call(v);
  }

  /// Used by the "tap to scan anyway" affordance: the person has overridden
  /// the sensor, and an override must win until they lower the phone.
  void forceAimed() {
    _settleTimer?.cancel();
    _settleTimer = null;
    _set(true);
  }

  void dispose() {
    _settleTimer?.cancel();
    _sub?.cancel();
    _sub = null;
  }
}
