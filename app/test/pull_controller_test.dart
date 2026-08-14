import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swip/widgets/pull_to_reveal.dart';

/// `F-118` — the test that would have caught a gesture that did nothing.
///
/// The first pull-to-reveal shipped, looked right in a screenshot, and could
/// never fire: its `NotificationListener` sat *inside* the `CustomScrollView`,
/// and notifications travel up from descendants, not down from ancestors. No
/// analyzer sees that, and no layout test sees it either — the widget lays out
/// perfectly, it simply never hears anything.
///
/// So the decision logic is pulled out into [PullController] and tested against
/// synthetic notifications, which is both cheaper and stricter than dragging a
/// widget: it can assert the **bouncing** case, where the list springs back
/// before the gesture ends and the naive implementation opens nothing.
void main() {
  // The controller fires a haptic when it opens, which is a platform-channel
  // call. Without the binding these are unit tests that throw on the one line
  // that matters.
  TestWidgetsFlutterBinding.ensureInitialized();

  ScrollMetrics at(double pixels, {double max = 400}) => FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: max,
        pixels: pixels,
        viewportDimension: 600,
        axisDirection: AxisDirection.down,
        devicePixelRatio: 3,
      );

  ScrollStartNotification start(ScrollMetrics m) =>
      ScrollStartNotification(metrics: m, context: null);
  ScrollEndNotification end(ScrollMetrics m) =>
      ScrollEndNotification(metrics: m, context: null);

  test('a short pull does not open it, and settles back to closed', () {
    var opened = false;
    final c = PullController(() => opened = true);
    addTearDown(c.dispose);

    c.onNotification(start(at(400)));
    c.onNotification(OverscrollNotification(
        metrics: at(400), context: null, overscroll: 40));

    expect(c.pull.value, greaterThan(0));
    expect(c.pull.value, lessThan(1));

    c.onNotification(end(at(400)));

    expect(opened, isFalse);
    expect(c.revealed, isFalse);
    expect(c.pull.value, 0);
  });

  test('clamping physics: a full pull reported as overscroll opens it', () {
    var opened = 0;
    final c = PullController(() => opened++);
    addTearDown(c.dispose);

    c.onNotification(start(at(400)));
    // Android's default physics refuses the movement and reports the refused
    // distance in pieces, as the finger travels.
    for (var i = 0; i < 4; i++) {
      c.onNotification(OverscrollNotification(
          metrics: at(400), context: null, overscroll: 30));
    }
    c.onNotification(end(at(400)));

    expect(opened, 1);
    expect(c.revealed, isTrue);
    expect(c.pull.value, 1);
  });

  test('bouncing physics: the spring-back before the drag ends does not '
      'cancel the reveal', () {
    var opened = false;
    final c = PullController(() => opened = true);
    addTearDown(c.dispose);

    c.onNotification(start(at(400)));
    // No overscroll notification at all under bouncing physics — the position
    // simply goes out of range.
    c.onNotification(
        ScrollUpdateNotification(metrics: at(520), context: null));
    // …and is most of the way back before the gesture is over. Deciding on the
    // live value here would open nothing, ever.
    c.onNotification(
        ScrollUpdateNotification(metrics: at(404), context: null));
    c.onNotification(end(at(400)));

    expect(opened, isTrue);
    expect(c.pull.value, 1);
  });

  test('it opens once, and stays open', () {
    var opened = 0;
    final c = PullController(() => opened++);
    addTearDown(c.dispose);

    for (var pull = 0; pull < 3; pull++) {
      c.onNotification(start(at(400)));
      c.onNotification(
          ScrollUpdateNotification(metrics: at(600), context: null));
      c.onNotification(end(at(400)));
    }

    expect(opened, 1);
    expect(c.revealed, isTrue);
    expect(c.pull.value, 1);
  });

  test('scrolling normally, without reaching the end, never opens it', () {
    var opened = false;
    final c = PullController(() => opened = true);
    addTearDown(c.dispose);

    c.onNotification(start(at(0)));
    for (final p in [50.0, 120.0, 260.0, 399.0]) {
      c.onNotification(ScrollUpdateNotification(metrics: at(p), context: null));
    }
    c.onNotification(end(at(399)));

    expect(opened, isFalse);
    expect(c.pull.value, 0);
  });
}
