import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swip/features/bubble/bubble_settings.dart';

/// `F-158` — **the test that exists because the switch lied.**
///
/// The report was four words: *"the floater launcher icon is not working"*.
/// The cause was not a bug in the bubble. There was no bubble. `F-131` shipped
/// this screen, the screen wrote `SharedPreferences['swip.bubble.enabled']`,
/// and nothing in the project ever read it — no service, no overlay, no window.
/// The switch moved, the preference was stored, and Android was never asked to
/// draw anything.
///
/// Nothing in the old suite could have caught that, because the old screen was
/// internally consistent: it set a boolean and showed the boolean it had set.
/// So every test below asserts on **what was sent to the platform**, never on
/// what the widget remembers. That is the only class of assertion that can
/// tell a working feature from a convincing one.
void main() {
  const channel = MethodChannel('in.swip.app/nfc');

  /// The page under test. The surface it is pumped onto is sized in `setUp`,
  /// because at the 800x600 test default this `ListView` of disclosure text
  /// pushes the switch off screen and `tap` throws.
  Widget harness() => const MaterialApp(home: BubbleSettingsPage());

  /// Every call the page made, in order, so a test can assert on absence as
  /// well as presence — "did NOT call startBubble" is the important one.
  late List<MethodCall> calls;

  /// What the fake Android side reports back.
  late bool granted;
  late bool wanted;
  late bool running;
  late int snoozedUntil;

  /// Whether `startBubble` is allowed to succeed. Android refuses when the
  /// permission is missing, and the page must survive being told no.
  late bool startSucceeds;

  /// `F-176`. Whether the fake platform claims this build is debuggable.
  ///
  /// Defaults to **false** in `setUp`, so every other test in this file runs
  /// against a release-shaped build. That is deliberate: the debug row must be
  /// invisible by default, and a test suite whose default had it on would
  /// never notice if that inverted.
  late bool traceEnabled;

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'canDrawOverlays':
          return granted;
        case 'bubbleStatus':
          return <String, dynamic>{
            'wanted': wanted,
            'running': running,
            'snoozedUntil': snoozedUntil,
          };
        case 'wakeBubble':
          snoozedUntil = 0;
          return true;
        case 'startBubble':
          if (!startSucceeds) return false;
          wanted = true;
          running = true;
          return true;
        case 'stopBubble':
          wanted = false;
          running = false;
          return true;
        case 'traceEnabled':
          return traceEnabled;
        case 'requestOverlayPermission':
          // The real one opens Android Settings and returns; the permission
          // does NOT become granted synchronously, which is the whole reason
          // the screen listens for `resumed`.
          return true;
      }
      return null;
    });
  }

  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    // 800x600 landscape is the test default and this page is a tall column of
    // disclosure text; the switch lands off-screen and `tap` throws. A phone
    // shape is also the only shape this screen is ever seen in.
    //
    // `platformDispatcher.implicitView` rather than `binding.window`: the
    // latter is deprecated, and a deprecation is a warning, and a warning
    // fails `flutter analyze` in the gate.
    final view = binding.platformDispatcher.implicitView!;
    view.physicalSize = const Size(390, 1400);
    view.devicePixelRatio = 1.0;
    addTearDown(view.reset);
    calls = <MethodCall>[];
    granted = false;
    wanted = false;
    running = false;
    snoozedUntil = 0;
    startSucceeds = true;
    traceEnabled = false;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    install();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  List<String> methods() => calls.map((c) => c.method).toList();

  Finder theSwitch() => find.byType(SwitchListTile);
  bool switchIsOn(WidgetTester t) =>
      t.widget<SwitchListTile>(theSwitch()).value;

  group('the switch reports the platform, not itself', () {
    testWidgets('it asks Android on open rather than reading a preference',
        (t) async {
      await t.pumpWidget(harness());
      await t.pumpAndSettle();

      // Both questions, every time. `canDrawOverlays` alone is not enough —
      // the permission can be held while the bubble is off.
      expect(methods(), containsAll(<String>['canDrawOverlays', 'bubbleStatus']));
    });

    testWidgets('permission held and bubble on reads as on', (t) async {
      granted = true;
      wanted = true;
      running = true;
      await t.pumpWidget(harness());
      await t.pumpAndSettle();
      expect(switchIsOn(t), isTrue);
    });

    testWidgets('a preference saying on cannot turn the switch on by itself',
        (t) async {
      // THE regression. The old screen would have shown this as ON.
      granted = false;
      wanted = true;
      running = false;
      await t.pumpWidget(harness());
      await t.pumpAndSettle();
      expect(switchIsOn(t), isFalse,
          reason: 'no overlay permission means no bubble, whatever is stored');
    });

    testWidgets('wanted but not on screen says so instead of claiming success',
        (t) async {
      granted = true;
      wanted = true;
      running = false;
      await t.pumpWidget(harness());
      await t.pumpAndSettle();

      expect(switchIsOn(t), isTrue);
      expect(find.textContaining('comes back the next time'), findsOneWidget);
    });

    testWidgets('running says where it is, not just that it is on', (t) async {
      // The service hides the bubble while SWIP is the foreground app, so at
      // the moment this line is read there is nothing to see. A subtitle that
      // said "it is on screen now" would send the user out hunting for a
      // bubble that is hidden on purpose — and they would report the floater
      // as broken for the second time, for a different reason.
      granted = true;
      wanted = true;
      running = true;
      await t.pumpWidget(harness());
      await t.pumpAndSettle();
      expect(find.textContaining('leave the app and it appears'),
          findsOneWidget);
    });
  });

  group('turning it on', () {
    testWidgets('without the permission it asks for it and records nothing',
        (t) async {
      granted = false;
      await t.pumpWidget(harness());
      await t.pumpAndSettle();
      calls.clear();

      await t.tap(theSwitch());
      await t.pumpAndSettle();

      expect(methods(), contains('requestOverlayPermission'));
      // The order in `F-131` was: store the wish, then ask. That is how a
      // switch ends up on with nothing behind it.
      expect(methods(), isNot(contains('startBubble')));
      expect(switchIsOn(t), isFalse);
    });

    testWidgets('with the permission it actually starts the service',
        (t) async {
      granted = true;
      await t.pumpWidget(harness());
      await t.pumpAndSettle();
      calls.clear();

      await t.tap(theSwitch());
      await t.pumpAndSettle();

      expect(methods(), contains('startBubble'));
      expect(switchIsOn(t), isTrue);
    });

    testWidgets('if Android refuses, the switch stays off', (t) async {
      // `startForegroundService` can be refused outright — a background start
      // on Android 12+, or the permission revoked between the check and the
      // call. The screen must not paint success it did not get.
      granted = true;
      startSucceeds = false;
      await t.pumpWidget(harness());
      await t.pumpAndSettle();

      await t.tap(theSwitch());
      await t.pumpAndSettle();

      expect(methods(), contains('startBubble'));
      expect(switchIsOn(t), isFalse, reason: 'Android said no');
    });

    testWidgets('it re-reads the state afterwards rather than assuming it',
        (t) async {
      granted = true;
      await t.pumpWidget(harness());
      await t.pumpAndSettle();
      calls.clear();

      await t.tap(theSwitch());
      await t.pumpAndSettle();

      expect(methods().indexOf('bubbleStatus') > methods().indexOf('startBubble'),
          isTrue,
          reason: 'the screen must show what happened, not what it intended');
    });
  });

  group('the trip to Android Settings, which backgrounds the app', () {
    /// Android grants this permission in Settings, in another app, so the tap
    /// and the answer are separated by SWIP losing the foreground. The screen
    /// learns the outcome only from `didChangeAppLifecycleState`.
    /// Driven through the `flutter/lifecycle` platform channel rather than
    /// `binding.handleAppLifecycleStateChanged`, which is `@protected` and
    /// would be an analyzer warning — and a warning fails the gate.
    ///
    /// The full sequence matters: since Flutter 3.13 the framework asserts on
    /// invalid lifecycle transitions, so it is not possible to jump from
    /// `paused` straight back to `resumed`. This is the real round trip an app
    /// makes when the user leaves for Settings and returns.
    Future<void> comeBackFromSettings(WidgetTester t) async {
      Future<void> send(String state) =>
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .handlePlatformMessage(
        'flutter/lifecycle',
        const StringCodec().encodeMessage('AppLifecycleState.$state'),
        (_) {},
      );

      for (final state in <String>[
        'inactive', 'hidden', 'paused', // leaving for Settings
        'hidden', 'inactive', 'resumed', // and coming back
      ]) {
        await send(state);
      }
      await t.pumpAndSettle();
    }

    testWidgets('granting the permission honours the tap that asked for it',
        (t) async {
      // Without this the user taps the switch, grants the permission, comes
      // back — and the switch is still off, because all SWIP learned on
      // resume is that the permission exists, not that anybody wanted it.
      // They tap again and it works. Which looks exactly like the bug this
      // whole round is about, and would be reported as it.
      granted = false;
      await t.pumpWidget(harness());
      await t.pumpAndSettle();

      await t.tap(theSwitch());
      await t.pumpAndSettle();
      expect(methods(), contains('requestOverlayPermission'));

      granted = true; // they granted it
      await comeBackFromSettings(t);

      expect(methods(), contains('startBubble'));
      expect(switchIsOn(t), isTrue, reason: 'one tap should mean one thing');
    });

    testWidgets('coming back WITHOUT granting turns nothing on', (t) async {
      granted = false;
      await t.pumpWidget(harness());
      await t.pumpAndSettle();

      await t.tap(theSwitch());
      await t.pumpAndSettle();
      await comeBackFromSettings(t); // still not granted

      expect(methods(), isNot(contains('startBubble')));
      expect(switchIsOn(t), isFalse);
    });

    testWidgets('the pending tap is one-shot, not a standing order', (t) async {
      // Somebody who taps the switch, thinks better of it in Settings and
      // comes back without granting must not get a bubble the next time they
      // grant that permission for some unrelated reason.
      granted = false;
      await t.pumpWidget(harness());
      await t.pumpAndSettle();

      await t.tap(theSwitch());
      await t.pumpAndSettle();
      await comeBackFromSettings(t); // declined

      granted = true; // granted much later, for something else
      await comeBackFromSettings(t);

      expect(methods(), isNot(contains('startBubble')));
      expect(switchIsOn(t), isFalse);
    });
  });

  group('sleeping', () {
    testWidgets('awake shows no sleeping row at all', (t) async {
      // A permanent row saying "not snoozed" is a row nobody ever needs.
      granted = true;
      wanted = true;
      running = true;
      await t.pumpWidget(harness());
      await t.pumpAndSettle();
      expect(find.text('Sleeping'), findsNothing);
    });

    testWidgets('asleep says WHEN it comes back', (t) async {
      // "Asleep" with no end is indistinguishable from broken, and this
      // feature has already been reported as broken twice.
      granted = true;
      wanted = true;
      running = true;
      snoozedUntil = DateTime.now()
          .add(const Duration(hours: 1))
          .millisecondsSinceEpoch;

      await t.pumpWidget(harness());
      await t.pumpAndSettle();

      expect(find.text('Sleeping'), findsOneWidget);
      expect(find.textContaining('Back at'), findsOneWidget);
    });

    testWidgets('a snooze in the past is not a snooze', (t) async {
      granted = true;
      wanted = true;
      running = true;
      snoozedUntil = 1;
      await t.pumpWidget(harness());
      await t.pumpAndSettle();
      // The platform reports 0 for an expired snooze, but a stale non-zero
      // value must not strand this screen showing a wake button forever.
      expect(find.text('Sleeping'), findsOneWidget);
    });

    testWidgets('Wake it ends the snooze and the row goes', (t) async {
      granted = true;
      wanted = true;
      running = true;
      snoozedUntil =
          DateTime.now().add(const Duration(hours: 2)).millisecondsSinceEpoch;

      await t.pumpWidget(harness());
      await t.pumpAndSettle();
      calls.clear();

      await t.tap(find.widgetWithText(TextButton, 'Wake it'));
      await t.pumpAndSettle();

      expect(methods(), contains('wakeBubble'));
      expect(find.text('Sleeping'), findsNothing);
    });

    testWidgets('the promise deleted in F-159 is back, because it is true now',
        (t) async {
      granted = true;
      await t.pumpWidget(harness());
      await t.pumpAndSettle();

      // `F-173` rewrote the gesture and this assertion moved with it. It used
      // to look for "until tomorrow"; snoozing is a drag onto a target for ten
      // minutes now, and **the way back is the half worth pinning** — a snooze
      // whose escape hatch is undiscoverable is what made the old one read as
      // the button being broken.
      expect(find.textContaining('ten minutes'), findsOneWidget);
      expect(find.textContaining('shake your phone'), findsOneWidget);
      // And the one that is still not built stays gone.
      expect(find.textContaining('see-through'), findsNothing);
    });
  });

  group('the temporary bubble trace', () {
    /// Drag the settings list to the end.
    ///
    /// **Without this both directions of the assertion below are worthless**,
    /// and one of them passed for the wrong reason before CI said otherwise.
    ///
    /// `CLAUDE.md`: a `ListView` only builds what is near the viewport, so
    /// copy below the fold is not merely invisible — it is not in the tree and
    /// `find` cannot see it. The trace row sits at the bottom of a long page,
    /// so "the row is there" failed on a build where it genuinely was, **and
    /// "the row is absent" would have passed on a build where it was not.**
    /// A test that cannot fail is worse than no test, because it is counted.
    ///
    /// Dragging rather than enlarging the surface, and both cases get the same
    /// preparation, so the two assertions are comparing the same thing.
    Future<void> toBottom(WidgetTester t) async {
      // Nothing to scroll if the page is still on its spinner — which is the
      // case in the "platform never answers" test below, and dragging a finder
      // that matches nothing throws rather than failing the assertion.
      if (find.byType(ListView).evaluate().isEmpty) return;
      for (var i = 0; i < 10; i++) {
        await t.drag(find.byType(ListView), const Offset(0, -600));
        await t.pump();
      }
      await t.pumpAndSettle();
    }

    // `F-176`. The owner asked for a tracker that is *"strictly temporary for
    // debugging"* and *"completely removed from the production/public Play
    // Store build"*.
    //
    // The design answer is stronger than a promise to delete it: the entry
    // point asks the platform whether this APK is debuggable, and a Play Store
    // build is not. These two tests are that claim, checked — the second one
    // is the one that matters, because a debug affordance shipped to users is
    // a thing nobody notices until somebody else does.

    testWidgets('the row is there on a debug build', (t) async {
      granted = true;
      traceEnabled = true;
      await t.pumpWidget(harness());
      await t.pumpAndSettle();
      await toBottom(t);

      expect(find.text('Bubble trace'), findsOneWidget);
    });

    testWidgets('and is absent on a build that is not debuggable', (t) async {
      granted = true;
      traceEnabled = false;
      await t.pumpWidget(harness());
      await t.pumpAndSettle();
      await toBottom(t);

      expect(find.text('Bubble trace'), findsNothing);
    });

    testWidgets('a platform that never answers leaves it absent', (t) async {
      // The safe direction. `_traceAvailable` starts false and the read is
      // timed out, so a channel that hangs — an older build of the Kotlin
      // side, or iOS — produces no debug row rather than one that appears
      // late or throws.
      granted = true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);

      await t.pumpWidget(harness());
      for (var i = 0; i < 4; i++) {
        await t.pump(const Duration(seconds: 3));
      }
      await t.pumpAndSettle();
      await toBottom(t);

      expect(find.text('Bubble trace'), findsNothing);
    });
  });

  group('turning it off', () {
    testWidgets('stops the service', (t) async {
      granted = true;
      wanted = true;
      running = true;
      await t.pumpWidget(harness());
      await t.pumpAndSettle();
      calls.clear();

      await t.tap(theSwitch());
      await t.pumpAndSettle();

      expect(methods(), contains('stopBubble'));
      expect(switchIsOn(t), isFalse);
    });
  });

  group('the wish that F-131 stored and never honoured', () {
    testWidgets('is carried across once', (t) async {
      SharedPreferences.setMockInitialValues(
          <String, Object>{BubbleSettingsPage.prefKey: true});
      granted = true;

      await t.pumpWidget(harness());
      await t.pumpAndSettle();

      expect(methods(), contains('startBubble'),
          reason: 'somebody turned this on in the old build and got nothing');
      expect(switchIsOn(t), isTrue);
    });

    testWidgets('and then deleted, so it can never fire twice', (t) async {
      SharedPreferences.setMockInitialValues(
          <String, Object>{BubbleSettingsPage.prefKey: true});
      granted = true;

      await t.pumpWidget(harness());
      await t.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(BubbleSettingsPage.prefKey), isNull);
    });

    testWidgets('a stored false does not turn anything on', (t) async {
      SharedPreferences.setMockInitialValues(
          <String, Object>{BubbleSettingsPage.prefKey: false});
      granted = true;

      await t.pumpWidget(harness());
      await t.pumpAndSettle();

      expect(methods(), isNot(contains('startBubble')));
      expect(switchIsOn(t), isFalse);
    });

    testWidgets('it is not honoured without the permission', (t) async {
      // Otherwise opening this screen would fire a start that Android refuses,
      // for a wish made in a build where it meant nothing.
      SharedPreferences.setMockInitialValues(
          <String, Object>{BubbleSettingsPage.prefKey: true});
      granted = false;

      await t.pumpWidget(harness());
      await t.pumpAndSettle();

      expect(methods(), isNot(contains('startBubble')));
      expect(switchIsOn(t), isFalse);
    });
  });

  group('the screen survives a platform that answers nothing', () {
    testWidgets('a platform that never replies does not spin forever',
        (t) async {
      // **This test found a real defect rather than confirming one.**
      //
      // A `MethodChannel` future completes when the platform replies, and
      // there is no reply here at all — a widget test has no engine behind the
      // channel. The first version of this screen awaited that future with no
      // deadline, so `_loading` was never cleared, the spinner animated
      // forever, and `pumpAndSettle` timed out.
      //
      // On a device the same shape is reachable whenever the Activity fails to
      // call `result`: a Settings screen stuck on a spinner with no way out
      // but force-quitting. The fix is the timeout in `_ask`, and this is what
      // holds it in place.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);

      await t.pumpWidget(harness());
      await t.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(theSwitch(), findsOneWidget);
      expect(switchIsOn(t), isFalse);
    });

    testWidgets('a PlatformException is not a crash', (t) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'boom');
      });

      await t.pumpWidget(harness());
      await t.pumpAndSettle();

      expect(switchIsOn(t), isFalse);
    });

    testWidgets('a MissingPluginException — iOS — is not a crash', (t) async {
      // What a real non-Android build does. The page already tells the user
      // this is an Android feature; it must not also be a red screen.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        throw MissingPluginException('no such method');
      });

      await t.pumpWidget(harness());
      await t.pumpAndSettle();

      expect(theSwitch(), findsOneWidget);
      expect(switchIsOn(t), isFalse);
    });
  });
}
