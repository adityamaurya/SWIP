import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:swip/features/bubble/blackbox_page.dart';

/// `F-187` — **that each black box reads its own file, and not another's.**
///
/// One screen now serves three recorders, and what tells them apart is a
/// `switch` on an enum holding three pairs of channel names. Get one branch
/// wrong and **nothing fails**: the screen still loads, still renders lines,
/// still exports. It would simply show the battery log under the heading *POS
/// tap black box*, and the first anyone would know is a session spent reading
/// the wrong file while a real failure sat unreproduced in the other one.
///
/// That is the same shape as everything `check_wiring.py` exists for — every
/// piece works and the wire goes to the wrong place — and the check cannot see
/// it, because all six names *are* present and *are* matched in
/// `MainActivity.kt`. Only the pairing is wrong, and a pairing needs a test.
///
/// ## Two things `CLAUDE.md` says about tests like this
///
/// **Every un-mocked platform call hangs**, because a widget test has no
/// engine at all — `pumpAndSettle timed out` is the symptom, not a slow test.
/// So the handler below answers every method it is asked, and returns `null`
/// rather than throwing for anything it does not know.
///
/// **A screen with a spinner keeps scheduling frames**, which is what makes
/// `pumpAndSettle` safe here where it is not safe on a still screen: the load
/// resolves, the spinner is replaced, and the tree goes quiet.
void main() {
  const channel = MethodChannel('in.swip.app/nfc');

  late List<MethodCall> calls;

  /// A different body per recorder, so an assertion can tell which file the
  /// screen actually asked for rather than only which method it called.
  const bodies = <String, String>{
    'traceDump': '{"t":"2026-09-16T14:38:20.000+0530","e":"bubble.shown"}\n',
    'tapTraceDump': '{"t":"2026-09-16T14:38:20.000+0530","e":"hce.field"}\n',
    'powerTraceDump': '{"t":"2026-09-16T14:38:20.000+0530","e":"power.awake"}\n',
  };

  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    final view = binding.platformDispatcher.implicitView!;
    // A phone shape. The preamble is several paragraphs and the list sits
    // under it; on the 800x600 test default the lines are below the fold.
    view.physicalSize = const Size(390, 1400);
    view.devicePixelRatio = 1.0;
    addTearDown(view.reset);

    calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (bodies.containsKey(call.method)) return bodies[call.method];
      switch (call.method) {
        case 'blackboxEnabled':
        case 'traceEnabled':
          return true;
        case 'traceClear':
        case 'tapTraceClear':
        case 'powerTraceClear':
          return true;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> open(WidgetTester tester, Blackbox box) async {
    await tester.pumpWidget(MaterialApp(home: BlackboxPage(box: box)));
    await tester.pumpAndSettle();
  }

  group('each box reads its own recorder', () {
    for (final (box, dump, body) in <(Blackbox, String, String)>[
      (Blackbox.bubble, 'traceDump', 'bubble.shown'),
      (Blackbox.tap, 'tapTraceDump', 'hce.field'),
      (Blackbox.power, 'powerTraceDump', 'power.awake'),
    ]) {
      testWidgets('${box.name} calls $dump and shows what it returned',
          (tester) async {
        await open(tester, box);

        final methods = calls.map((c) => c.method).toList();
        expect(methods, contains(dump));

        // And nothing else. A screen that dumped all three and displayed one
        // would pass the assertion above while reading two files it has no
        // business touching.
        for (final other in bodies.keys.where((m) => m != dump)) {
          expect(methods, isNot(contains(other)),
              reason: '${box.name} also called $other');
        }

        expect(find.text(box.title), findsOneWidget);
        expect(find.textContaining(body), findsOneWidget);
      });
    }
  });

  testWidgets('the three boxes do not share an export filename',
      (tester) async {
    // The slug is what a shared file is named when it reaches the owner, and
    // three identically named files in a Downloads folder is a bad way to find
    // out they collide.
    final slugs = Blackbox.values.map((b) => b.slug).toSet();
    expect(slugs.length, Blackbox.values.length);
  });

  testWidgets('availability asks the gate that outlives the bubble trace',
      (tester) async {
    // `traceEnabled` is deleted along with `BubbleTrace` (docs/38 §4 step 4).
    // If this screen's availability check were still asking it, that deletion
    // would silently take the POS and battery boxes off the Settings screen —
    // the future would resolve false, the section would stop drawing, and
    // nothing anywhere would fail.
    await BlackboxPage.available();
    expect(calls.map((c) => c.method), contains('blackboxEnabled'));
    expect(calls.map((c) => c.method), isNot(contains('traceEnabled')));
  });

  testWidgets('the bubble trace row asks its own gate', (tester) async {
    // The mirror of the above: this one *must* keep asking `traceEnabled`, so
    // that deleting the trace takes its row with it.
    await BlackboxPage.bubbleTraceAvailable();
    expect(calls.map((c) => c.method), contains('traceEnabled'));
  });

  testWidgets('a POS box with nothing in it says so rather than looking broken',
      (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'tapTraceDump') return '';
      return null;
    });

    await open(tester, Blackbox.tap);

    // An empty recorder and a broken screen look identical otherwise, which is
    // exactly the confusion this whole feature exists to end. `_Empty` is a
    // `Center`, not a `ListView` child, so it is genuinely in the tree —
    // `CLAUDE.md`'s warning about a `findsNothing` below the fold does not
    // apply, and the positive assertion below is the one carrying the weight.
    expect(find.textContaining('Nothing recorded yet'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('the privacy line is on the screen, not only in the docs',
      (tester) async {
    // These files are meant to be exported and sent. The promise about what is
    // in them belongs where the export button is.
    await open(tester, Blackbox.tap);
    expect(find.textContaining('never values'), findsOneWidget);
  });
}
