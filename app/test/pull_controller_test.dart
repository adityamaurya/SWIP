import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swip/data/models/capture_event.dart';
import 'package:swip/data/models/mcc.dart';
import 'package:swip/features/dashboard/dashboard_page.dart';
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
///
/// These are `testWidgets` rather than plain `test` for one reason:
/// `ScrollNotification.context` is **non-nullable**, so a notification cannot be
/// built without a real `BuildContext` — there has to be an element tree, even
/// if it is one `SizedBox`.
void main() {
  ScrollMetrics at(double pixels, {double max = 400}) => FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: max,
        pixels: pixels,
        viewportDimension: 600,
        axisDirection: AxisDirection.down,
        devicePixelRatio: 3,
      );

  /// The cheapest possible element tree, for the one thing a notification
  /// cannot be constructed without.
  Future<BuildContext> context(WidgetTester tester) async {
    late BuildContext captured;
    await tester.pumpWidget(Builder(builder: (c) {
      captured = c;
      return const SizedBox();
    }));
    return captured;
  }

  testWidgets('a short pull does not open it, and settles back to closed',
      (tester) async {
    final ctx = await context(tester);
    var opened = false;
    final c = PullController(() => opened = true);
    addTearDown(c.dispose);

    c.onNotification(ScrollStartNotification(metrics: at(400), context: ctx));
    c.onNotification(OverscrollNotification(
        metrics: at(400), context: ctx, overscroll: 40));

    expect(c.pull.value, greaterThan(0));
    expect(c.pull.value, lessThan(1));

    c.onNotification(ScrollEndNotification(metrics: at(400), context: ctx));

    expect(opened, isFalse);
    expect(c.revealed, isFalse);
    expect(c.pull.value, 0);
  });

  testWidgets('clamping physics: a full pull reported as overscroll opens it',
      (tester) async {
    final ctx = await context(tester);
    var opened = 0;
    final c = PullController(() => opened++);
    addTearDown(c.dispose);

    c.onNotification(ScrollStartNotification(metrics: at(400), context: ctx));
    // Android's default physics refuses the movement and reports the refused
    // distance in pieces, as the finger travels.
    for (var i = 0; i < 4; i++) {
      c.onNotification(OverscrollNotification(
          metrics: at(400), context: ctx, overscroll: 30));
    }
    c.onNotification(ScrollEndNotification(metrics: at(400), context: ctx));

    expect(opened, 1);
    expect(c.revealed, isTrue);
    expect(c.pull.value, 1);
  });

  testWidgets(
      'bouncing physics: the spring-back before the drag ends does not '
      'cancel the reveal', (tester) async {
    final ctx = await context(tester);
    var opened = false;
    final c = PullController(() => opened = true);
    addTearDown(c.dispose);

    c.onNotification(ScrollStartNotification(metrics: at(400), context: ctx));
    // No overscroll notification at all under bouncing physics — the position
    // simply goes out of range.
    c.onNotification(
        ScrollUpdateNotification(metrics: at(520), context: ctx));
    // …and is most of the way back before the gesture is over. Deciding on the
    // live value here would open nothing, ever.
    c.onNotification(
        ScrollUpdateNotification(metrics: at(404), context: ctx));
    c.onNotification(ScrollEndNotification(metrics: at(400), context: ctx));

    expect(opened, isTrue);
    expect(c.pull.value, 1);
  });

  testWidgets('it opens once, and stays open', (tester) async {
    final ctx = await context(tester);
    var opened = 0;
    final c = PullController(() => opened++);
    addTearDown(c.dispose);

    for (var pull = 0; pull < 3; pull++) {
      c.onNotification(ScrollStartNotification(metrics: at(400), context: ctx));
      c.onNotification(
          ScrollUpdateNotification(metrics: at(600), context: ctx));
      c.onNotification(ScrollEndNotification(metrics: at(400), context: ctx));
    }

    expect(opened, 1);
    expect(c.revealed, isTrue);
    expect(c.pull.value, 1);
  });

  testWidgets('scrolling normally, without reaching the end, never opens it',
      (tester) async {
    final ctx = await context(tester);
    var opened = false;
    final c = PullController(() => opened = true);
    addTearDown(c.dispose);

    c.onNotification(ScrollStartNotification(metrics: at(0), context: ctx));
    for (final p in [50.0, 120.0, 260.0, 399.0]) {
      c.onNotification(ScrollUpdateNotification(metrics: at(p), context: ctx));
    }
    c.onNotification(ScrollEndNotification(metrics: at(399), context: ctx));

    expect(opened, isFalse);
    expect(c.pull.value, 0);
  });

  // ───────────────────────────────────────────────────────────────────────
  // `F-141` — the regression test for the red panel on the dashboard.
  // ───────────────────────────────────────────────────────────────────────
  //
  // Everything above drives [PullController] with synthetic notifications,
  // which is precise but shares one blind spot: a synthetic notification is
  // dispatched from test code, i.e. between frames, where writing to a
  // `ValueNotifier` is perfectly legal.
  //
  // The bug was only ever reachable from the *real* scroll view, because it
  // needed the notification to arrive **during** a frame — which is what a
  // bouncing physics spring-back does. So this one drags an actual
  // `DashboardPage` past the end of its content and asserts that the frame
  // produced no exception. Nothing less would have caught it: the widget laid
  // out fine, analyze was clean, and all five tests above passed on the broken
  // build.
  //
  // What the user saw was Flutter's `ErrorWidget`: a full-width red panel of
  // small text reading "Build scheduled during frame", rendered at the foot of
  // the dashboard at the exact moment the pull was released.

  group('the real dashboard, dragged past the end', () {
    final event = CaptureEvent(
      id: 'pull-regression-1',
      mcc: '5499',
      vector: CaptureVector.qr,
      confidence: MccConfidence.verified,
      capturedAt: DateTime.utc(2026, 8, 10, 12),
      merchantName: 'CULINARY BRANDS INDIA PRIVATE LIMITED',
      merchantKey: 'upi:paytmqr6dld0y@ptys',
      placeLabel: 'Kasarvadavali, Thane',
    );

    // Two sizes, because the at-rest camera overlay (`F-142`) overflowed on
    // the short one and not the tall one.
    for (final size in const [Size(360, 800), Size(320, 640)]) {
      testWidgets('no exception is thrown at ${size.width}x${size.height}',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(MaterialApp(
          home: DashboardPage(
            recent: [event],
            mccFor: (_) => null,
            tapAvailable: true,
            // Layout only. No platform channel is touched.
            active: false,
          ),
        ));
        await tester.pump(const Duration(milliseconds: 300));

        final view = find.byType(CustomScrollView);
        // All the way to the foot of the page…
        for (var i = 0; i < 12; i++) {
          await tester.drag(view, const Offset(0, -400));
          await tester.pump(const Duration(milliseconds: 60));
        }
        // …and then keep pulling, which is the gesture under test.
        await tester.drag(view, const Offset(0, -260));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 400));

        expect(tester.takeException(), isNull,
            reason: 'the pull must not throw: an assertion here renders as '
                'the red ErrorWidget panel on the dashboard');
      });
    }
  });
}
