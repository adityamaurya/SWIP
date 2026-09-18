import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swip/core/pay/upi_handoff.dart';
import 'package:swip/data/models/capture_event.dart';
import 'package:swip/data/models/mcc.dart';
import 'package:swip/widgets/pay_with_sheet.dart';

/// `F-194` — **the hand-off from a scanned code to the app that pays it.**
///
/// > *"I scan this QR code, get the merchant ID code, and a pop-up comes up
/// > with an answer. I get another button below it, 'Continue Payment', which
/// > leads me to … a list of apps which can make payment to this giver."*
/// > — prompt 54
///
/// Two things are worth asserting here and only one of them is obvious.
///
/// The obvious one is that the right apps appear and the right one is opened.
///
/// The one that matters is **what reaches the platform**. `CLAUDE.md` records
/// four months of a dead floating bubble hidden behind a switch that stored
/// its own state, and the rule it left behind: *assert on what reaches the
/// channel, never on what the widget remembers.* A sheet that renders
/// "PhonePe" and hands the wrong string to it looks identical in a screenshot
/// and fails at a counter.
CaptureEvent _event({String? raw, String? key, String? name}) => CaptureEvent(
      id: 'e1',
      mcc: '5411',
      vector: CaptureVector.qr,
      confidence: MccConfidence.verified,
      capturedAt: DateTime(2026, 9, 17),
      merchantName: name,
      merchantKey: key,
      rawPayload: raw,
    );

void main() {
  group('payUriFor', () {
    test('forwards a signed payload byte for byte', () {
      // The whole reason this function exists. A PhonePe merchant code carries
      // `mode`, `orgid`, `mc` and a `sign=` DER signature computed over the
      // rest of the string (`docs/42` §4). Rebuilding the URI from `pa` and
      // `pn` would drop all four, and the signature would no longer match what
      // it signs — so a verified merchant becomes an unverified stranger, or
      // the code is rejected outright.
      const raw =
          'upi://pay?pa=paytmqr6twbbd@ptys&pn=Paytm&mc=5411&mode=02'
          '&orgid=159761&sign=MEUCIQDx';
      expect(UpiHandoff.payUriFor(_event(raw: raw)), raw);
    });

    test('composes from the address when there is no payload', () {
      final uri = UpiHandoff.payUriFor(
          _event(key: 'shop@okaxis', name: 'Balaji Stores'))!;
      expect(uri, startsWith('upi://pay?'));
      expect(uri, contains('pa=shop%40okaxis'));
      expect(uri, contains('pn=Balaji+Stores'));
      expect(uri, contains('cu=INR'));
    });

    test('never carries an amount', () {
      // > *"let them first get redirected to the list of payment sheet apps …
      // > and then put their amount into that chosen app"*
      //
      // An `am=` SWIP guessed would be an amount somebody pays. The parameter
      // exists on `compose` so the day this changes is one argument, and it is
      // not reachable from a capture.
      final uri = UpiHandoff.payUriFor(_event(key: 'shop@okaxis'))!;
      expect(uri.contains('am='), isFalse);
    });

    test('a POS tap has nothing to pay', () {
      // `docs/47`: a complete EMV exchange whose merchant-identity fields were
      // all zeros. Even a terminal that filled them in gives a merchant id,
      // not a VPA. The button must not render.
      final tap = CaptureEvent(
        id: 'p1',
        mcc: '5812',
        vector: CaptureVector.nfc,
        confidence: MccConfidence.verified,
        capturedAt: DateTime(2026, 9, 17),
        terminalId: '00000000',
      );
      expect(UpiHandoff.payUriFor(tap), isNull);
    });

    test('a QR that is not a payment is not payable', () {
      for (final junk in const [
        'https://example.com',
        'WIFI:S:cafe;T:WPA;P:hunter2;;',
        'upi://pay?pn=NoAddressHere',
        'upi://pay?pa=notavpa',
        'upi://pay?pa=two@at@signs',
      ]) {
        expect(UpiHandoff.isPayable(junk), isFalse, reason: junk);
        expect(UpiHandoff.payUriFor(_event(raw: junk)), isNull, reason: junk);
      }
    });

    test('the canonical `upi:` merchant key has its prefix stripped', () {
      // `CaptureResolver` writes `upi:<vpa>` for EVERY UPI capture
      // (`capture_resolver.dart:76`), so this is not an edge case — it is the
      // only shape a real row has. Handing it on unchanged would produce
      // `pa=upi%3Awfmlmh2%40ybl`, which no PSP resolves.
      expect(UpiHandoff.payUriFor(_event(key: 'upi:WFMLMH2@ybl')),
          'upi://pay?pa=WFMLMH2%40ybl&cu=INR');
      expect(UpiHandoff.addressOf('upi:shop@okaxis'), 'shop@okaxis');
      // Case-insensitively, because the key is written lower-cased and an
      // import could carry either.
      expect(UpiHandoff.addressOf('UPI:shop@okaxis'), 'shop@okaxis');
    });

    test('any other colon is still refused', () {
      // The prefix is stripped because it is known. A colon SWIP does not
      // recognise is a string it does not understand, and guessing at one
      // ends with a payment app open on a payee that does not exist.
      for (final bad in const [
        'mailto:shop@okaxis',
        'shop:1@okaxis',
        'upi:upi:shop@okaxis',
        'upi:',
        'upi:@okaxis',
      ]) {
        expect(UpiHandoff.addressOf(bad), isNull, reason: bad);
      }
    });

    test('a raw payload that is junk still composes from a known address', () {
      // The row was captured from something unpayable, but SWIP later learned
      // the address. Falling back is right; silently forwarding the junk is
      // not.
      final uri =
          UpiHandoff.payUriFor(_event(raw: 'https://x.test', key: 'a@okicici'));
      expect(uri, 'upi://pay?pa=a%40okicici&cu=INR');
    });
  });

  group('PayWithSheet', () {
    Future<void> pump(
      WidgetTester tester, {
      required List<UpiApp> apps,
      required List<String> opened,
      required List<String> chooserCalls,
      bool succeed = true,
    }) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PayWithSheet(
            payUri: 'upi://pay?pa=shop@okaxis&cu=INR',
            payeeLabel: 'Balaji Stores',
            list: () async => apps,
            pay: (pkg, uri) async {
              opened.add('$pkg|$uri');
              return succeed;
            },
            chooser: (uri) async {
              chooserCalls.add(uri);
              return true;
            },
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('lists the apps the platform reported', (tester) async {
      await pump(tester,
          apps: const [
            UpiApp(package: 'com.phonepe.app', label: 'PhonePe'),
            UpiApp(package: 'net.one97.paytm', label: 'Paytm'),
          ],
          opened: [],
          chooserCalls: []);

      expect(find.text('PhonePe'), findsOneWidget);
      expect(find.text('Paytm'), findsOneWidget);
      // The payee, named once. The user is about to hand money to this.
      expect(find.text('Balaji Stores'), findsOneWidget);
    });

    testWidgets('tapping a row sends that package the exact uri',
        (tester) async {
      final opened = <String>[];
      await pump(tester,
          apps: const [UpiApp(package: 'com.phonepe.app', label: 'PhonePe')],
          opened: opened,
          chooserCalls: []);

      await tester.tap(find.text('PhonePe'));
      await tester.pumpAndSettle();

      // The assertion that matters: the package AND the unmodified uri.
      expect(opened, ['com.phonepe.app|upi://pay?pa=shop@okaxis&cu=INR']);
    });

    testWidgets('an empty list falls through to the system chooser',
        (tester) async {
      final chooserCalls = <String>[];
      await pump(tester, apps: const [], opened: [], chooserCalls: chooserCalls);

      // Not an error state, and it must not say "no apps found" — there is no
      // such finding, only a route SWIP could not draw itself.
      //
      // A positive assertion on purpose. `CLAUDE.md`'s rule about scrolling
      // first applies to `findsNothing`, which passes silently when the thing
      // is merely below the fold; `findsOneWidget` fails loudly either way,
      // and in the empty state there is no scroll view to scroll.
      final more = find.text('More payment apps');
      expect(more, findsOneWidget);

      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(chooserCalls, ['upi://pay?pa=shop@okaxis&cu=INR']);
    });

    testWidgets('the chooser is offered even when the list rendered',
        (tester) async {
      await pump(tester,
          apps: const [UpiApp(package: 'com.phonepe.app', label: 'PhonePe')],
          opened: [],
          chooserCalls: []);
      // A user whose app is missing from a list SWIP drew has no other way
      // out. Asserting presence, so this cannot pass by being off screen.
      expect(find.text('More payment apps'), findsOneWidget);
    });

    testWidgets('an app that will not open says so instead of nothing',
        (tester) async {
      await pump(tester,
          apps: const [UpiApp(package: 'com.dead.app', label: 'Dead')],
          opened: [],
          chooserCalls: [],
          succeed: false);

      await tester.tap(find.text('Dead'));
      await tester.pumpAndSettle();

      expect(find.text('That app could not be opened'), findsOneWidget);
      // And the sheet is still usable — the guard must reset, or the second
      // attempt is silently swallowed and the row looks broken.
      expect(find.text('Dead'), findsOneWidget);
    });

    testWidgets('an icon that failed to load renders a monogram',
        (tester) async {
      await pump(tester,
          apps: const [UpiApp(package: 'x.y', label: 'Zeta')],
          opened: [],
          chooserCalls: []);
      expect(find.text('Z'), findsOneWidget);
    });

    testWidgets('an icon that loaded renders the image', (tester) async {
      // A 1x1 transparent PNG — the smallest thing `Image.memory` will accept.
      final png = Uint8List.fromList(const [
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
        0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
        0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
        0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
        0x42, 0x60, 0x82,
      ]);
      await pump(tester,
          apps: [UpiApp(package: 'x.y', label: 'Zeta', icon: png)],
          opened: [],
          chooserCalls: []);
      expect(find.byType(Image), findsOneWidget);
      // And NOT the monogram, which would mean the icon path was skipped.
      expect(find.text('Z'), findsNothing);
    });
  });
}
