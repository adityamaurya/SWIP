import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swip/core/theme/swip_theme.dart';
import 'package:swip/data/models/capture_event.dart';
import 'package:swip/data/models/mcc.dart';
import 'package:swip/features/paywall/raw_data_entitlement.dart';
import 'package:swip/widgets/capture_result_sheet.dart';
import 'package:swip/widgets/capture_sheet.dart';
import 'package:swip/widgets/capture_sheet_shell.dart';

/// `F-174`, `F-175` — the non-intrusive capture result, and the striped bar.
///
/// ## The bug this suite is really about
///
/// The owner photographed `BOTTOM OVERFLOWED BY 28 PIXELS` across the foot of
/// a capture screen. `CaptureSheet` is a `Column` with no scroll view in it,
/// and `showModalBottomSheet(isScrollControlled: true)` lets a sheet grow to
/// the height of the screen and then stops — so a tall capture had nowhere to
/// put the excess.
///
/// **That is a debug-only stripe.** In a release build the identical layout
/// clips silently, and whatever fell off the bottom is simply gone with
/// nothing on screen to say so. Which is why the first group below asserts on
/// a surface deliberately too short for its content: it is the only way to
/// catch the release-mode version of this, where there is no stripe to
/// photograph.
void main() {
  final withMcc = CaptureEvent(
    id: 'sheet-1',
    mcc: '5912',
    vector: CaptureVector.qr,
    confidence: MccConfidence.verified,
    capturedAt: DateTime.utc(2026, 9, 15, 12),
    merchantName: 'WELLNESS FOREVER MH 2',
    merchantKey: 'upi:WFMLMH2@ybl',
  );

  final withoutMcc = CaptureEvent(
    id: 'sheet-2',
    mcc: null,
    vector: CaptureVector.qr,
    confidence: MccConfidence.unknown,
    capturedAt: DateTime.utc(2026, 9, 15, 13),
    merchantKey: null,
  );

  const mcc = Mcc(code: '5912', definitions: [
    MccDefinition(
      publication: MccPublication.national,
      name: 'Drug Stores and Pharmacies',
    ),
  ]);

  /// A long field table, which is what pushed the real sheet over the edge.
  const manyDetails = <String, String>{
    'Payment company': 'Google Pay',
    'Pays to': 'dranitaagrawal.1980@okicici',
    'City': 'Mumbai',
    'Merchant country': 'IN',
    'Captured at': 'Bandra West, Mumbai',
    'Amount': 'INR 640.00',
    'Terminal': '12345678',
    'How it was read': 'QR code',
  };

  Widget harness(
    Widget child, {
    Size surface = const Size(400, 780),
    double textScale = 1.0,
  }) =>
      ProviderScope(
        overrides: [
          // The real entitlement waits on SharedPreferences, which never
          // resolves in a widget test — and an unresolved future here would
          // make every assertion below depend on a timeout.
          rawDataUnlockedProvider.overrideWith((ref) => _FakeEntitlement(false)),
        ],
        child: MaterialApp(
          builder: (context, inner) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              size: surface,
              textScaler: TextScaler.linear(textScale),
            ),
            child: inner!,
          ),
          home: Scaffold(body: Center(child: child)),
        ),
      );

  Future<void> surfaced(WidgetTester t, Size size) async {
    final view = t.view;
    view.physicalSize = size;
    view.devicePixelRatio = 1.0;
    addTearDown(view.reset);
  }

  group('the shell, which is the overflow fix', () {
    testWidgets('a capture taller than the screen does not overflow',
        (t) async {
      // 320 px tall: shorter than any phone, and shorter than this content.
      // Before `CaptureSheetShell` this is precisely the case that produced
      // the owner's screenshot.
      await surfaced(t, const Size(400, 320));
      await t.pumpWidget(harness(
        CaptureSheetShell(
          child: CaptureSheet(
            event: withoutMcc,
            mcc: null,
            sourceLabel: 'UPI QR',
            details: manyDetails,
            rawPayload: 'upi://pay?pa=x@y&pn=Somebody',
          ),
        ),
        surface: const Size(400, 320),
      ));
      await t.pump();

      expect(t.takeException(), isNull);
      // The real assertion: the content is in a scroll view, so the excess has
      // somewhere to go rather than being clipped off the bottom.
      expect(find.byType(SingleChildScrollView), findsWidgets);
    });

    testWidgets('it does not overflow at a large text scale either',
        (t) async {
      // A permission-sized text scale on a short screen is the worst case and
      // the one a designer never sees on their own phone.
      await surfaced(t, const Size(400, 420));
      await t.pumpWidget(harness(
        CaptureSheetShell(
          child: CaptureSheet(
            event: withoutMcc,
            mcc: null,
            sourceLabel: 'UPI QR',
            details: manyDetails,
          ),
        ),
        surface: const Size(400, 420),
        textScale: 1.8,
      ));
      await t.pump();
      expect(t.takeException(), isNull);
    });

    testWidgets('a short capture makes a short sheet, not a full-height one',
        (t) async {
      // `Flexible` rather than `Expanded` is what buys this. With `Expanded`
      // the column would always fill its cap, so every capture — however
      // little it had to say — would cover the screen. That would be the
      // full-screen page again wearing a grabber.
      await surfaced(t, const Size(400, 800));
      await t.pumpWidget(harness(
        CaptureSheetShell(
          maxHeightFraction: 0.86,
          child: const SizedBox(height: 120, width: double.infinity),
        ),
        surface: const Size(400, 800),
      ));
      await t.pump();

      final height = t.getSize(find.byType(CaptureSheetShell)).height;
      expect(height, lessThan(800 * 0.86));
    });
  });

  group('the split CTA', () {
    Widget sheet(CaptureEvent event, {VoidCallback? onPos}) =>
        CaptureResultSheet(
          event: event,
          mcc: event.hasMcc ? mcc : null,
          sourceLabel: 'UPI QR',
          details: manyDetails,
          onPos: onPos,
        );

    testWidgets('two buttons when there is somewhere to send them',
        (t) async {
      await surfaced(t, const Size(400, 800));
      await t.pumpWidget(
          harness(sheet(withoutMcc, onPos: () {}), surface: const Size(400, 800)));
      await t.pump();

      expect(find.text('View all'), findsOneWidget);
      expect(find.text('Tap POS'), findsOneWidget);
    });

    testWidgets('no POS button on a capture that came from the POS reader',
        (t) async {
      // `tap_page` passes no `onPos`, because offering to take somebody to the
      // screen they are already on is a button that goes nowhere.
      await surfaced(t, const Size(400, 800));
      await t.pumpWidget(
          harness(sheet(withoutMcc), surface: const Size(400, 800)));
      await t.pump();

      expect(find.text('View all'), findsOneWidget);
      expect(find.text('Tap POS'), findsNothing);
    });

    testWidgets('Tap POS is the filled one when there is no category',
        (t) async {
      // The emphasis carries the finding: the category was not in the code,
      // and the shop's terminal is the one place it certainly is.
      await surfaced(t, const Size(400, 800));
      await t.pumpWidget(
          harness(sheet(withoutMcc, onPos: () {}), surface: const Size(400, 800)));
      await t.pump();

      expect(find.widgetWithText(FilledButton, 'Tap POS'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'View all'), findsOneWidget);
    });

    testWidgets('and View all is the filled one when there is', (t) async {
      await surfaced(t, const Size(400, 800));
      await t.pumpWidget(
          harness(sheet(withMcc, onPos: () {}), surface: const Size(400, 800)));
      // `pumpAndSettle`, not `pump`, and only in the tests that render a
      // capture WITH a category — those draw `_FoilCode`, whose gold sweep is
      // `.animate(onPlay: (c) => c.repeat(count: 4))`. A single `pump` leaves
      // that animation's timer running, and the test then fails on "A Timer is
      // still pending even after the widget tree was disposed" rather than on
      // anything it was asserting.
      //
      // `CLAUDE.md` already records this trap from `F-159` and I walked into
      // it anyway. Settling is safe here because the repeat is bounded; an
      // unbounded one would hang instead, which is why the no-category tests
      // above deliberately stay on a plain `pump`.
      await t.pumpAndSettle();

      expect(find.widgetWithText(FilledButton, 'View all'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Tap POS'), findsOneWidget);
    });

    testWidgets('Tap POS actually reaches its callback', (t) async {
      // The `F-169` lesson, applied before it can happen again: a button
      // wired to nothing looks identical to a button wired to something.
      var went = false;
      await surfaced(t, const Size(400, 800));
      await t.pumpWidget(harness(sheet(withoutMcc, onPos: () => went = true),
          surface: const Size(400, 800)));
      await t.pump();

      await t.tap(find.text('Tap POS'));
      await t.pump();
      expect(went, isTrue);
    });
  });

  group('View all', () {
    testWidgets('never renders the field table — the ledger does that now',
        (t) async {
      // `F-180`. The brief layout is the whole point: at a counter, with
      // somebody waiting to be paid, the reason paragraph and the four routes
      // are the screen the owner called "so messed up". `F-175` unfolded them
      // in place; this round sends them to the ledger instead, so there is no
      // state in which this sheet shows them.
      //
      // **A tall surface, deliberately.** `CLAUDE.md`: a `findsNothing` below
      // the fold passes for the wrong reason, and this suite has shipped that
      // mistake before. 800 px with a `manyDetails` map that measures well
      // under it means the table would be built if it existed.
      await surfaced(t, const Size(400, 800));
      await t.pumpWidget(harness(
        CaptureResultSheet(
          event: withoutMcc,
          mcc: null,
          sourceLabel: 'UPI QR',
          details: manyDetails,
          onPos: () {},
          onViewAll: () {},
        ),
        surface: const Size(400, 800),
      ));
      await t.pump();

      expect(find.text('Payment company'), findsNothing);
      expect(find.text('Terminal'), findsNothing);
      // The positive half of the same pump, so the negatives above cannot be
      // passing because nothing rendered at all.
      expect(find.text('View all'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('calls back rather than expanding in place', (t) async {
      var asked = 0;
      await surfaced(t, const Size(400, 800));
      await t.pumpWidget(harness(
        CaptureResultSheet(
          event: withoutMcc,
          mcc: null,
          sourceLabel: 'UPI QR',
          details: manyDetails,
          onViewAll: () => asked++,
        ),
        surface: const Size(400, 800),
      ));
      await t.pump();

      await t.tap(find.text('View all'));
      await t.pumpAndSettle();

      expect(asked, 1);
      // The label does not flip, the table does not appear, and the sheet is
      // still the sheet. Everything that used to happen here now happens on
      // the screen this button opens.
      expect(find.text('Show less'), findsNothing);
      expect(find.text('Payment company'), findsNothing);
      expect(find.text('View all'), findsOneWidget);
    });

    testWidgets('is disabled, not hidden, when there is nowhere to go',
        (t) async {
      // A footer whose button count changes between captures is a row that has
      // to be re-read every time. Both buttons keep their places.
      await surfaced(t, const Size(400, 800));
      await t.pumpWidget(harness(
        CaptureResultSheet(
          event: withMcc,
          mcc: mcc,
          sourceLabel: 'UPI QR',
          onPos: () {},
        ),
        surface: const Size(400, 800),
      ));
      // `pumpAndSettle`, not `pump`: `withMcc` renders `_FoilCode`, whose gold
      // sweep is `repeat(count: 4)`, and a single pump leaves that timer
      // running so the test dies on the widget tree rather than on the
      // assertion below. Safe because the repeat is bounded. `check_wiring.py`
      // now fails on this shape — it has caught me three times.
      await t.pumpAndSettle();

      expect(find.text('View all'), findsOneWidget);
      final button = t.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'View all'));
      expect(button.onPressed, isNull);
    });

    testWidgets('draws no second primary button', (t) async {
      // `showFurniture: false`. The ledger's sheet layout ends its content
      // with its own button; this one pins a footer. Both at once would be two
      // primary buttons on one sheet, one of which scrolls away.
      await surfaced(t, const Size(400, 800));
      await t.pumpWidget(harness(
        CaptureResultSheet(
          event: withMcc,
          mcc: mcc,
          sourceLabel: 'UPI QR',
          details: manyDetails,
          onPos: () {},
          onViewAll: () {},
        ),
        surface: const Size(400, 800),
      ));
      await t.pumpAndSettle();

      expect(find.text('Capture another'), findsNothing);
      expect(find.text('Try another'), findsNothing);
    });
  });

  group('the grabber, of which there must be exactly one', () {
    /// A 4 px tall rounded bar — the shape both handles had.
    ///
    /// Matched by geometry rather than by type because Flutter's own handle is
    /// a private widget. That makes this test a little blunt and entirely
    /// honest: it finds anything shaped like a grabber, which is exactly the
    /// thing there was one too many of.
    Finder grabbers() => find.byWidgetPredicate((w) {
          if (w is! Container) return false;
          final c = w.constraints;
          return c != null && c.maxHeight == 4 && c.maxWidth > 8;
        });

    testWidgets('the shell draws none of its own', (t) async {
      // `F-180`. `SwipTheme` sets `showDragHandle: true`, so Flutter draws one
      // above this widget on every modal sheet — and this widget only ever
      // appears inside one. The shell used to draw a second, which is the two
      // stacked pills in the owner's screenshot.
      //
      // Rendered bare on a tall surface with a short child, so everything the
      // shell builds is in the tree and a `findsNothing` here cannot be
      // passing because it was never laid out.
      await surfaced(t, const Size(400, 800));
      await t.pumpWidget(harness(
        const CaptureSheetShell(
          child: SizedBox(height: 80, width: double.infinity),
        ),
        surface: const Size(400, 800),
      ));
      await t.pump();

      expect(grabbers(), findsNothing);
      // The positive half: the shell did build, so the line above is a real
      // absence rather than an empty tree.
      expect(find.byType(CaptureSheetShell), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('and the theme still asks Flutter for one', (t) async {
      // The other half of "exactly one". If this ever goes false the sheets
      // lose their handle entirely and the test above would happily agree.
      expect(SwipTheme.dark().bottomSheetTheme.showDragHandle, isTrue);
      expect(SwipTheme.light().bottomSheetTheme.showDragHandle, isTrue);
    });
  });
}

/// A [RawDataEntitlement] in a known state, with no preferences behind it.
///
/// Copied from `capture_result_page_test.dart` deliberately rather than
/// shared: the two suites pin the same provider for opposite reasons, and a
/// shared fake is a thing one of them can change under the other.
class _FakeEntitlement extends RawDataEntitlement {
  _FakeEntitlement(bool unlocked) : super(null) {
    state = unlocked;
  }

  @override
  Future<bool> grant() async {
    state = true;
    return true;
  }
}
