import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swip/data/models/capture_event.dart';
import 'package:swip/data/models/mcc.dart';
import 'package:swip/features/paywall/raw_data_entitlement.dart';
import 'package:swip/widgets/capture_result_page.dart';
import 'package:swip/widgets/raw_data_lock.dart';

/// `F-144`, `F-145`, `F-146` — the full-screen capture result.
///
/// The dashboard went black once because a sliver was handed a tight infinite
/// constraint, and nothing caught it: the code was legal Dart and the suite was
/// all parser tests. `dashboard_layout_test` exists because of that, and this
/// is the same guard for the screen that has replaced the capture sheet.
///
/// It also pins the one property of the paywall that is a security claim
/// rather than a design choice — see the last group.
void main() {
  final withMcc = CaptureEvent(
    id: 'result-1',
    mcc: '5912',
    vector: CaptureVector.qr,
    confidence: MccConfidence.verified,
    capturedAt: DateTime.utc(2026, 9, 5, 12),
    merchantName: 'WELLNESS FOREVER MH 2',
    merchantKey: 'upi:WFMLMH2@ybl',
  );

  final withoutMcc = CaptureEvent(
    id: 'result-2',
    mcc: null,
    vector: CaptureVector.nfc,
    confidence: MccConfidence.unknown,
    capturedAt: DateTime.utc(2026, 9, 5, 13),
    merchantKey: null,
  );

  const rawUpi = 'upi://pay?pa=WFMLMH2@ybl&pn=WELLNESS%20FOREVER%20MH%202'
      '&am=76.66&tr=PINE2269706791&mc=5912&mode=15';

  Widget harness(
    CaptureEvent event, {
    bool unlocked = false,
    double textScale = 1.0,
    String? rawPayload = rawUpi,
    Map<String, String> details = const {'Pays to': 'WFMLMH2@ybl'},
  }) =>
      ProviderScope(
        overrides: [
          // The real provider waits on SharedPreferences, which never
          // resolves in a widget test. Both states are pinned explicitly so
          // the locked case is tested as the *default*, not as an accident of
          // an unresolved future.
          rawDataUnlockedProvider.overrideWith(
            (ref) => _FakeEntitlement(unlocked),
          ),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: CaptureResultPage(
            event: event,
            mcc: event.mcc == null
                ? null
                : const Mcc(code: '5912', definitions: [
                    MccDefinition(
                      publication: MccPublication.national,
                      name: 'Drug Stores and Pharmacies',
                    ),
                  ]),
            sourceLabel: 'UPI QR',
            rawPayload: rawPayload,
            details: details,
          ),
        ),
      );

  group('it lays out', () {
    for (final size in const [
      Size(360, 800), // the common Android baseline
      Size(320, 640), // the narrow one that finds overflow
      Size(412, 915),
    ]) {
      testWidgets('at ${size.width}x${size.height}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(harness(withMcc));
        await tester.pump(const Duration(milliseconds: 600));

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('with no category, which is a different layout', (t) async {
      t.view.physicalSize = const Size(360, 800);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);

      await t.pumpWidget(harness(withoutMcc));
      await t.pump(const Duration(milliseconds: 600));

      expect(t.takeException(), isNull);
    });

    testWidgets('at a large text scale', (t) async {
      t.view.physicalSize = const Size(360, 800);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);

      await t.pumpWidget(harness(withMcc, textScale: 1.6));
      await t.pump(const Duration(milliseconds: 600));

      expect(t.takeException(), isNull);
    });

    testWidgets('with nothing technical to show, the panel is absent',
        (t) async {
      t.view.physicalSize = const Size(360, 800);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);

      await t.pumpWidget(
          harness(withMcc, rawPayload: null, details: const {}));
      await t.pump(const Duration(milliseconds: 600));

      expect(t.takeException(), isNull);
      expect(find.text('TECHNICAL DETAILS'), findsNothing);
    });
  });

  group('`F-145` the CTA says the right thing', () {
    testWidgets('a capture with a category invites another', (t) async {
      await t.pumpWidget(harness(withMcc));
      await t.pump(const Duration(milliseconds: 600));
      expect(find.text('Capture another'), findsOneWidget);
      expect(find.text('Try another'), findsNothing);
    });

    testWidgets('a capture without one does not claim a success', (t) async {
      await t.pumpWidget(harness(withoutMcc));
      await t.pump(const Duration(milliseconds: 600));
      // "Capture another" after a miss would quietly claim the miss was a hit.
      expect(find.text('Try another'), findsOneWidget);
      expect(find.text('Capture another'), findsNothing);
    });

    testWidgets('an explicit label wins, for the pay-by-app handover',
        (t) async {
      await t.pumpWidget(ProviderScope(
        overrides: [
          rawDataUnlockedProvider.overrideWith((ref) => _FakeEntitlement(false)),
        ],
        child: MaterialApp(
          home: CaptureResultPage(
            event: withoutMcc,
            mcc: null,
            sourceLabel: 'Pay-by-app',
            primaryLabel: 'Continue to pay',
          ),
        ),
      ));
      await t.pump(const Duration(milliseconds: 600));
      expect(find.text('Continue to pay'), findsOneWidget);
      expect(find.text('Try another'), findsNothing);
    });
  });

  group('`F-145` the technical panel starts collapsed and opens', () {
    testWidgets('collapsed by default, expanded on tap', (t) async {
      t.view.physicalSize = const Size(360, 800);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);

      await t.pumpWidget(harness(withMcc));
      await t.pump(const Duration(milliseconds: 600));

      // The header is there…
      expect(find.text('TECHNICAL DETAILS'), findsOneWidget);
      // …and its contents are not.
      expect(find.text('Pays to'), findsNothing);

      await t.tap(find.text('TECHNICAL DETAILS'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));

      expect(find.text('Pays to'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // `F-146` — the one assertion in this file that is a security claim.
  // ─────────────────────────────────────────────────────────────────────────
  //
  // The locked state deliberately does not blur the payload, because a blur is
  // a rendering effect over a widget that still holds the string: a screenshot,
  // a text-scale change or an accessibility reader can all recover it.
  //
  // The guarantee is stronger and simpler — **when locked, the payload is not
  // in the widget tree at all.** That is a property a test can actually check,
  // and it is the one that would silently rot if someone later "improved" the
  // locked state by passing the string down to blur it.
  group('`F-146` the locked payload is not in the tree', () {
    testWidgets('locked: the raw string appears nowhere', (t) async {
      t.view.physicalSize = const Size(360, 800);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);

      await t.pumpWidget(harness(withMcc, unlocked: false));
      await t.pump(const Duration(milliseconds: 600));
      await t.tap(find.text('TECHNICAL DETAILS'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));

      expect(find.byType(RawDataLock), findsOneWidget);

      // `tr=PINE2269706791` is the terminal reference. It exists **only** in
      // the raw payload — unlike the payee handle, which SWIP also shows as a
      // plain "Pays to" detail and which is therefore not what the wall is
      // around. Picking a token that is unique to the gated string is the
      // whole difference between this test proving something and proving
      // nothing; the first version of it asserted on the handle and failed for
      // exactly that reason.
      const gatedOnly = 'PINE2269706791';
      expect(rawUpi, contains(gatedOnly));

      // Not "is not visible" — is not present. Walk every Text and
      // SelectableText in the tree and assert none of them carries it.
      for (final w in t.allWidgets) {
        if (w is Text && w.data != null) {
          expect(w.data, isNot(contains(gatedOnly)),
              reason: 'a locked payload leaked into a Text');
        }
        if (w is SelectableText) {
          expect(w.data ?? '', isNot(contains(gatedOnly)),
              reason: 'a locked payload leaked into a SelectableText');
        }
      }

      // What it *does* say is the shape, which cannot be inverted back.
      expect(find.textContaining('UPI payment code'), findsOneWidget);
      expect(find.textContaining('characters'), findsOneWidget);
    });

    testWidgets('unlocked: the raw string is shown in full', (t) async {
      t.view.physicalSize = const Size(360, 800);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);

      await t.pumpWidget(harness(withMcc, unlocked: true));
      await t.pump(const Duration(milliseconds: 600));
      await t.tap(find.text('TECHNICAL DETAILS'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));

      final shown = t.allWidgets
          .whereType<SelectableText>()
          .any((w) => (w.data ?? '').contains('PINE2269706791'));
      expect(shown, isTrue, reason: 'paid for it, so it is shown');
    });

    testWidgets('the export is never gated, and the locked copy says so',
        (t) async {
      t.view.physicalSize = const Size(360, 800);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);

      await t.pumpWidget(harness(withMcc, unlocked: false));
      await t.pump(const Duration(milliseconds: 600));
      await t.tap(find.text('TECHNICAL DETAILS'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));

      // A paywall that does not state what is still free reads as a paywall on
      // everything, and in this app that would be a paywall on the user's own
      // ledger. The sentence is load-bearing.
      expect(find.textContaining('Exporting is free'), findsOneWidget);
    });
  });
}

/// A [RawDataEntitlement] in a known state, with no preferences behind it.
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
