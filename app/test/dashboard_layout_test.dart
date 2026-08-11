import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swip/data/models/capture_event.dart';
import 'package:swip/data/models/mcc.dart';
import 'package:swip/features/dashboard/dashboard_page.dart';

/// `F-84` — the test that should have existed before the dashboard went black.
///
/// ## What happened, and why nothing caught it
///
/// A `Row` inside a `SliverToBoxAdapter` was given
/// `crossAxisAlignment: CrossAxisAlignment.stretch`. A sliver hands its child an
/// **unbounded** height, and `stretch` makes `RenderFlex` pass that height down
/// as a tight constraint — `BoxConstraints.tightFor(height: infinity)`. That
/// throws during layout, the exception takes the whole `CustomScrollView` with
/// it, and every sliver in it disappears at once: header, camera band, tiles,
/// recent list. The screen renders as nothing but the navigation bar.
///
/// `flutter analyze` cannot see it — the code is perfectly legal Dart. The
/// existing suite is pure parser tests, so nothing ever laid the screen out.
/// CI was green on a build whose main screen did not render.
///
/// This is the cheapest possible guard: lay the real screen out and assert that
/// nothing threw. It would have failed on the exact commit that shipped the bug.
///
/// The camera is deliberately inactive (`active: false`) so no platform channel
/// is touched — this is a layout test, not an integration test.
void main() {
  final event = CaptureEvent(
    id: 'test-1',
    mcc: '5499',
    vector: CaptureVector.qr,
    confidence: MccConfidence.verified,
    capturedAt: DateTime.utc(2026, 8, 10, 12, 0),
    merchantName: 'CULINARY BRANDS INDIA PRIVATE LIMITED',
    merchantKey: 'upi:paytmqr6dld0y@ptys',
    placeLabel: 'Kasarvadavali, Thane',
  );

  final uncategorised = CaptureEvent(
    id: 'test-2',
    mcc: null,
    vector: CaptureVector.nfc,
    confidence: MccConfidence.unknown,
    capturedAt: DateTime.utc(2026, 8, 10, 11, 0),
    merchantKey: 'upi:paytmqr6glctn@ptys',
  );

  // The text scaler is applied through `MaterialApp.builder`, not by wrapping
  // the app: `MaterialApp` installs its own `MediaQuery` from the view, so an
  // outer one is simply overwritten and the test would silently prove nothing.
  Widget harness(List<CaptureEvent> recent, {double textScale = 1.0}) =>
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: DashboardPage(
          recent: recent,
          mccFor: (_) => null,
          tapAvailable: true,
          // No camera in a layout test.
          active: false,
        ),
      );

  /// Every phone this is used on, plus the narrow one that finds overflow.
  const sizes = <Size>[
    Size(360, 800), // the common Android baseline
    Size(320, 640), // the narrowest still in the wild
    Size(412, 915), // a Pixel
  ];

  for (final size in sizes) {
    testWidgets('dashboard lays out at ${size.width}x${size.height}',
        (tester) async {
      tester.view.physicalSize = size * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness([event, uncategorised]));
      // Not pumpAndSettle: the viewfinder and the foil run repeating
      // animations, which never settle and would simply time out.
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('dashboard lays out with nothing captured yet', (tester) async {
    tester.view.physicalSize = const Size(360, 800) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(harness(const []));
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
  });

  testWidgets('the two capture routes that matter are on screen and named',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(harness([event]));
    await tester.pump(const Duration(milliseconds: 300));

    // `F-81`. If either of these disappears, the screen has lost its point.
    expect(find.text('Scan QR'), findsOneWidget);
    expect(find.text('Tap POS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a capture with no category reads NA, never a dash',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    // `F-76`. An em-dash is punctuation pretending to be a value.
    await tester.pumpWidget(harness([uncategorised]));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('—'), findsNothing);
    expect(find.text('NA'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard survives a large text scale', (tester) async {
    tester.view.physicalSize = const Size(360, 800) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    // The ledger row reflows to a stacked layout above 1.3; this walks past
    // that boundary so the reflow itself is exercised rather than assumed.
    await tester.pumpWidget(harness([event, uncategorised], textScale: 1.6));
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
  });

  testWidgets('the first-run card survives a large text scale',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    // A different second card entirely — three lines of prose in a
    // fixed-height box — so the empty state needs its own pass at scale.
    await tester.pumpWidget(harness(const [], textScale: 1.6));
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
  });

  testWidgets('Link is gone from the dashboard', (tester) async {
    tester.view.physicalSize = const Size(360, 800) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    // `F-89`. A tile that promises a capability the app does not have is worse
    // than a missing one — it teaches distrust of the two that work.
    await tester.pumpWidget(harness([event]));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Link'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rows name the route in full, and never hedge', (tester) async {
    tester.view.physicalSize = const Size(412, 915) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(harness([event, uncategorised]));
    await tester.pump(const Duration(milliseconds: 300));

    // `F-93`. The three routes, spelled out.
    expect(find.text('QR SCAN'), findsWidgets);
    expect(find.text('POS TAP'), findsWidgets);
    // The abbreviations they replaced, and the vector that was never a route.
    expect(find.text('SCAN'), findsNothing);
    expect(find.text('APP'), findsNothing);
    expect(find.text('KNOWN'), findsNothing);

    // `F-88`. Only ever "Verified" — no hedging word under the number, and no
    // "Unknown" restating the NA directly above it.
    expect(find.text('Likely'), findsNothing);
    expect(find.text('Unknown'), findsNothing);
    expect(find.text('Verified'), findsWidgets);

    expect(tester.takeException(), isNull);
  });
}
