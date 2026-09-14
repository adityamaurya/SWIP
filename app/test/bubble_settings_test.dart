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

  /// Whether `startBubble` is allowed to succeed. Android refuses when the
  /// permission is missing, and the page must survive being told no.
  late bool startSucceeds;

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'canDrawOverlays':
          return granted;
        case 'bubbleStatus':
          return <String, dynamic>{'wanted': wanted, 'running': running};
        case 'startBubble':
          if (!startSucceeds) return false;
          wanted = true;
          running = true;
          return true;
        case 'stopBubble':
          wanted = false;
          running = false;
          return true;
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
    startSucceeds = true;
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
    testWidgets('no handler at all still renders', (t) async {
      // iOS, or an Activity older than these methods. The page already says
      // this is an Android feature; it must not be a crash.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);

      await t.pumpWidget(harness());
      await t.pumpAndSettle();

      // `pumpAndSettle` rethrows anything the build threw, so reaching this
      // line is half the assertion and the switch state is the other half.
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
  });
}
