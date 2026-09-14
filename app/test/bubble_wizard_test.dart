import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swip/features/bubble/bubble_wizard.dart';

/// `F-159` — the five-screen permission wizard.
///
/// The wizard exists because a switch was reported broken twice: once when it
/// genuinely did nothing, and once when it worked and the bubble was invisible
/// for a reason nothing on screen explained. So the things worth asserting are
/// not "does it render" but:
///
///   * does every screen survive being built, at phone size and at a large
///     text scale — a permission flow that overflows is a permission flow that
///     ends with nothing granted;
///   * does the button that claims to open Android's settings actually reach
///     the platform;
///   * does granting the permission **start the bubble**, rather than leaving
///     the user to find a second switch afterwards;
///   * and does the last screen tell the truth about what they will see, which
///     is the screen whose absence caused the second report.
void main() {
  const channel = MethodChannel('in.swip.app/nfc');

  late List<MethodCall> calls;
  late bool overlayGranted;
  late bool notificationsGranted;
  late bool wanted;
  late bool running;

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'canDrawOverlays':
          return overlayGranted;
        case 'notificationsAllowed':
          return notificationsGranted;
        case 'bubbleStatus':
          return <String, dynamic>{'wanted': wanted, 'running': running};
        case 'startBubble':
          if (!overlayGranted) return false;
          wanted = true;
          running = true;
          return true;
        case 'requestNotifications':
          notificationsGranted = true;
          return true;
        case 'requestOverlayPermission':
        case 'openThisAppSettings':
          return true;
      }
      return null;
    });
  }

  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    // The wizard is a column of disclosure text with a button pinned to the
    // bottom. At the 800x600 test default the button overlaps the body and
    // taps land on the wrong thing.
    final view = binding.platformDispatcher.implicitView!;
    view.physicalSize = const Size(400, 1600);
    view.devicePixelRatio = 1.0;
    addTearDown(view.reset);

    calls = <MethodCall>[];
    overlayGranted = false;
    notificationsGranted = false;
    wanted = false;
    running = false;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    install();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  List<String> methods() => calls.map((c) => c.method).toList();

  Widget harness({double scale = 1.0}) => MaterialApp(
        // Inside `builder`, not wrapped around the MaterialApp: MaterialApp
        // inserts its own MediaQuery from the view and would replace an
        // ambient one, so wrapping it outside silently does nothing and the
        // text-scale test would have been asserting on the default scale.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const BubbleWizard(),
      );

  /// Walk forward by tapping whichever forward button this screen offers.
  Future<void> advance(WidgetTester t, String label) async {
    await t.tap(find.widgetWithText(FilledButton, label));
    await t.pumpAndSettle();
  }

  group('it opens and asks the platform what is already true', () {
    testWidgets('asks about both permissions and the service', (t) async {
      await t.pumpWidget(harness());
      await t.pumpAndSettle();

      expect(
          methods(),
          containsAll(<String>[
            'canDrawOverlays',
            'notificationsAllowed',
            'bubbleStatus',
          ]));
      expect(find.textContaining('on top of'), findsOneWidget);
    });

    testWidgets('a platform that never answers does not hang it', (t) async {
      // A widget test has no engine behind a channel, so every call hangs
      // forever. Real iOS answers instantly with MissingPluginException; this
      // is harsher than any phone, which is exactly why it is worth running.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);

      await t.pumpWidget(harness());
      await t.pumpAndSettle();

      expect(find.textContaining('on top of'), findsOneWidget);
    });
  });

  group('every screen builds', () {
    for (final scale in <double>[1.0, 1.6]) {
      testWidgets('all five, at text scale $scale', (t) async {
        // 1.6 because a permission flow is exactly the kind of screen someone
        // with large text set will be sent to, and an overflow here means the
        // button is unreachable and the feature is never enabled.
        overlayGranted = true;
        await t.pumpWidget(harness(scale: scale));
        await t.pumpAndSettle();

        await advance(t, 'Next'); // 1 → 2, the overlay permission
        await advance(t, 'Next'); // 2 → 3, notifications
        await advance(t, 'Allow notifications'); // 3 → 4, keeping it running
        await advance(t, 'Open SWIP\'s app settings'); // 4 → 5, all set

        expect(find.textContaining('all set'), findsOneWidget);
        expect(t.takeException(), isNull);
      });
    }
  });

  group('the overlay step', () {
    testWidgets('without permission, the button reaches Android', (t) async {
      await t.pumpWidget(harness());
      await t.pumpAndSettle();
      await advance(t, 'Next');
      calls.clear();

      await advance(t, 'Open settings');
      expect(methods(), contains('requestOverlayPermission'));
    });

    testWidgets('with permission it starts the bubble without a second switch',
        (t) async {
      // The whole point of a wizard called "turn the button on". Making the
      // user find another switch afterwards is how the last two rounds went
      // wrong.
      overlayGranted = true;
      await t.pumpWidget(harness());
      await t.pumpAndSettle();

      expect(methods(), contains('startBubble'));
      expect(running, isTrue);
    });
  });

  group('the last screen, which is the one that was missing', () {
    testWidgets('tells the user they will not see it yet, and why', (t) async {
      overlayGranted = true;
      await t.pumpWidget(harness());
      await t.pumpAndSettle();

      await advance(t, 'Next');
      await advance(t, 'Next');
      await advance(t, 'Allow notifications');
      await advance(t, 'Open SWIP\'s app settings');
      await t.pumpAndSettle();

      expect(find.textContaining('all set'), findsOneWidget);
      // The exact surprise that got the bubble reported as broken.
      expect(find.textContaining('will not see the button right now'),
          findsOneWidget);
      expect(find.textContaining('Leave SWIP'), findsOneWidget);
    });

    testWidgets('without the permission it does not claim success', (t) async {
      overlayGranted = false;
      await t.pumpWidget(harness());
      await t.pumpAndSettle();

      await advance(t, 'Next');
      await t.tap(find.widgetWithText(TextButton, 'Not now'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(TextButton, 'Skip'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(TextButton, 'Skip for now'));
      await t.pumpAndSettle();

      expect(find.textContaining('Not turned on yet'), findsOneWidget);
      expect(find.textContaining('all set'), findsNothing);
    });
  });

  group('the honest warnings', () {
    testWidgets('force stop is called out as unrecoverable', (t) async {
      overlayGranted = true;
      await t.pumpWidget(harness());
      await t.pumpAndSettle();
      await advance(t, 'Next');
      await advance(t, 'Next');
      await advance(t, 'Allow notifications');

      expect(find.textContaining('Do not use Force stop'), findsOneWidget);
    });

    testWidgets('other floating apps are correctly said NOT to disable it',
        (t) async {
      // The owner asked for a warning that another app could switch SWIP's
      // shortcut off. Overlays stack by Z-order and never disable each other,
      // so the truthful version of that warning is this one — and saying the
      // false version would be worse than saying nothing.
      overlayGranted = true;
      await t.pumpWidget(harness());
      await t.pumpAndSettle();
      await advance(t, 'Next');
      await advance(t, 'Next');
      await advance(t, 'Allow notifications');

      expect(find.textContaining('do NOT switch SWIP off'), findsOneWidget);
      expect(find.textContaining('accessibility shortcut'), findsOneWidget);
    });
  });
}
