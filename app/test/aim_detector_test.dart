import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:swip/core/sensors/aim_detector.dart';

/// `F-134` — the camera only detects while the phone is aimed at something.
///
/// The important tests here are not the happy path. They are the two ways this
/// feature could make the app *worse* than having no feature at all:
///
///  * a device with no accelerometer must behave exactly as before;
///  * the state must not flicker at the angle people actually hold a phone.
void main() {
  AccelerometerEvent at(double z) =>
      AccelerometerEvent(0, 0, z, DateTime.now());

  test('starts aimed, so a slow sensor never looks like a broken camera', () {
    final c = StreamController<AccelerometerEvent>();
    final d = AimDetector(stream: c.stream)..start();
    addTearDown(d.dispose);

    // No reading has arrived yet.
    expect(d.hasReading, isFalse);
    expect(d.isAimed, isTrue);
  });

  test('flat on a table is not aimed', () async {
    final c = StreamController<AccelerometerEvent>();
    final d = AimDetector(stream: c.stream)..start();
    addTearDown(d.dispose);

    c.add(at(9.8));
    await Future<void>.delayed(Duration.zero);

    expect(d.hasReading, isTrue);
    expect(d.isAimed, isFalse);
  });

  test('face down is not aimed either — the sign must not matter', () async {
    final c = StreamController<AccelerometerEvent>();
    final d = AimDetector(stream: c.stream)..start();
    addTearDown(d.dispose);

    c.add(at(-9.8));
    await Future<void>.delayed(Duration.zero);
    expect(d.isAimed, isFalse);
  });

  test('raising it engages, but only after it settles', () async {
    final c = StreamController<AccelerometerEvent>();
    final d = AimDetector(stream: c.stream)..start();
    addTearDown(d.dispose);

    c.add(at(9.8));
    await Future<void>.delayed(Duration.zero);
    expect(d.isAimed, isFalse);

    // Raised, but only for an instant — this is the phone swinging up so you
    // can read the ledger, not an aim.
    c.add(at(0.5));
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(d.isAimed, isFalse, reason: 'must not fire on the way past');

    c.add(at(0.5));
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(d.isAimed, isTrue);
  });

  test('hysteresis: a tiring arm does not switch the camera off', () async {
    final c = StreamController<AccelerometerEvent>();
    final d = AimDetector(stream: c.stream)..start();
    addTearDown(d.dispose);

    c.add(at(0.5));
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(d.isAimed, isTrue);

    // Drifted past the engage threshold, but not past release. With one
    // cutoff instead of two, this is where the overlay would strobe.
    c.add(at(5.0));
    await Future<void>.delayed(Duration.zero);
    expect(d.isAimed, isTrue);

    c.add(at(7.5));
    await Future<void>.delayed(Duration.zero);
    expect(d.isAimed, isFalse);
  });

  test('a knock is ignored rather than read as an aim', () async {
    final c = StreamController<AccelerometerEvent>();
    final d = AimDetector(stream: c.stream)..start();
    addTearDown(d.dispose);

    c.add(at(9.8));
    await Future<void>.delayed(Duration.zero);
    expect(d.isAimed, isFalse);

    // 40 m/s² is four gravities — the phone was dropped or banged down, not
    // pointed at a shop counter.
    c.add(AccelerometerEvent(30, 20, 0.2, DateTime.now()));
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(d.isAimed, isFalse);
  });

  test('a sensor error fails open, so a device without one is unaffected',
      () async {
    final c = StreamController<AccelerometerEvent>();
    final d = AimDetector(stream: c.stream)..start();
    addTearDown(d.dispose);

    c.add(at(9.8));
    await Future<void>.delayed(Duration.zero);
    expect(d.isAimed, isFalse);

    c.addError(StateError('no accelerometer on this device'));
    await Future<void>.delayed(Duration.zero);

    expect(d.isAimed, isTrue, reason: 'never leave the camera dark');
    expect(d.hasReading, isFalse);
  });

  test('tapping to scan anyway overrides the sensor', () async {
    final c = StreamController<AccelerometerEvent>();
    var changes = 0;
    final d = AimDetector(stream: c.stream, onChanged: (_) => changes++)
      ..start();
    addTearDown(d.dispose);

    c.add(at(9.8));
    await Future<void>.delayed(Duration.zero);
    expect(d.isAimed, isFalse);

    d.forceAimed();
    expect(d.isAimed, isTrue);
    expect(changes, 2, reason: 'one off, one on — never a repeat');
  });
}
