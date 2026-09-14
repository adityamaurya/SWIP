import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swip/core/theme/swip_palette.dart';
import 'package:swip/core/theme/swip_tokens.dart';
import 'package:swip/core/theme/theme_setting.dart';
import 'package:swip/data/models/capture_event.dart';
import 'package:swip/data/models/mcc.dart';
import 'package:swip/features/dashboard/dashboard_page.dart';

/// `F-155` — the two grounds.
///
/// The dashboard has gone black once before for a layout reason (`F-84`) and
/// once for a duplicate key (`F-152`). A palette switch changes 440 colour
/// reads at once, which is exactly the shape of change that breaks a screen
/// without breaking a compile — so the real screen is laid out on both
/// grounds here rather than trusted to.
void main() {
  final event = CaptureEvent(
    id: 'theme-1',
    mcc: '5912',
    vector: CaptureVector.qr,
    confidence: MccConfidence.verified,
    capturedAt: DateTime.utc(2026, 9, 14, 12),
    merchantName: 'WELLNESS FOREVER MH 2',
    merchantKey: 'upi:WFMLMH2@ybl',
  );

  // Every test here mutates a global, so it is put back afterwards. Without
  // this the first test to run would decide the palette for every test in the
  // whole suite that happens to follow it.
  final original = SwipPalette.active;
  tearDown(() => SwipPalette.active = original);

  group('the palettes are actually different', () {
    test('paper is light and foil is dark', () {
      expect(SwipPalette.paper.brightness, Brightness.light);
      expect(SwipPalette.foil.brightness, Brightness.dark);
      expect(SwipPalette.paper.isDark, isFalse);
      expect(SwipPalette.foil.isDark, isTrue);
    });

    test('the accent really is gold on foil and ink on paper', () {
      // `gold500` is the token 41 call sites mean "the accent" by. `F-130`
      // repointed it to ink for Paper and kept the name; this is the assertion
      // that the name now genuinely carries two values.
      expect(SwipPalette.foil.gold500, const Color(0xFFC9A227));
      expect(SwipPalette.paper.gold500, const Color(0xFF0B0B0D));
    });

    test('every switchable token differs between the two grounds', () {
      // Not a style check — a wiring check. If a token were accidentally
      // hard-coded in both palettes it would look right on one ground and be
      // invisible on the other, and nothing else in the suite would notice.
      final p = SwipPalette.paper;
      final f = SwipPalette.foil;
      expect(p.bg, isNot(f.bg));
      expect(p.surface, isNot(f.surface));
      expect(p.surfaceRaised, isNot(f.surfaceRaised));
      expect(p.hairline, isNot(f.hairline));
      expect(p.textPrimary, isNot(f.textPrimary));
      expect(p.textSecondary, isNot(f.textSecondary));
      expect(p.textTertiary, isNot(f.textTertiary));
    });
  });

  group('SwipColors follows the active palette', () {
    test('switching the palette moves every token', () {
      SwipPalette.active = SwipPalette.paper;
      expect(SwipColors.bg, const Color(0xFFFFFFFF));
      expect(SwipColors.textPrimary, const Color(0xFF0B0B0D));
      expect(SwipColors.gold500, const Color(0xFF0B0B0D));

      SwipPalette.active = SwipPalette.foil;
      expect(SwipColors.bg, const Color(0xFF060507));
      expect(SwipColors.textPrimary, const Color(0xFFF2EFE9));
      expect(SwipColors.gold500, const Color(0xFFC9A227));
    });

    test('the aliases follow too', () {
      SwipPalette.active = SwipPalette.foil;
      expect(SwipColors.border, SwipColors.hairline);
      expect(SwipColors.surfaceSubdued, SwipColors.surfaceRaised);
      expect(SwipColors.surfaceInverse, SwipColors.bg);
    });

    test('the camera surfaces do NOT follow, and that is the point', () {
      // `F-130`. The viewfinder is an arbitrary image — a marble counter, a
      // black terminal, a moving hand — and the only overlay treatment that
      // survives all of them is light on dark. These are the constants that
      // exist so a palette flip can never turn the scrim into white fog over
      // the feed, which is exactly what happened once.
      SwipPalette.active = SwipPalette.paper;
      final scrimOnPaper = SwipColors.onCameraScrim;
      final inkOnPaper = SwipColors.onCameraInk;

      SwipPalette.active = SwipPalette.foil;
      expect(SwipColors.onCameraScrim, scrimOnPaper);
      expect(SwipColors.onCameraInk, inkOnPaper);
    });
  });

  group('the choice resolves correctly', () {
    test('explicit choices ignore the phone', () {
      expect(SwipThemeChoice.paper.palette(platformIsDark: true),
          SwipPalette.paper);
      expect(SwipThemeChoice.foil.palette(platformIsDark: false),
          SwipPalette.foil);
    });

    test('system follows the phone', () {
      expect(SwipThemeChoice.system.palette(platformIsDark: true),
          SwipPalette.foil);
      expect(SwipThemeChoice.system.palette(platformIsDark: false),
          SwipPalette.paper);
    });

    test('an unknown stored value falls back to system, not to a crash', () {
      // A preference written by a future build, or a corrupted one.
      expect(SwipThemeChoice.parse('chartreuse'), SwipThemeChoice.system);
      expect(SwipThemeChoice.parse(null), SwipThemeChoice.system);
    });

    test('every choice has a label and a note that says what it looks like',
        () {
      for (final c in SwipThemeChoice.values) {
        expect(c.label, isNotEmpty);
        expect(c.note, isNotEmpty);
        // "Foil" means nothing to anyone who has not read the design docs.
        expect(c.label.toLowerCase(), isNot(contains('foil')));
        expect(c.label.toLowerCase(), isNot(contains('paper')));
      }
    });
  });

  group('the real dashboard lays out on both grounds', () {
    for (final palette in [SwipPalette.paper, SwipPalette.foil]) {
      for (final size in const [Size(360, 800), Size(320, 640)]) {
        testWidgets(
            '${palette.name} at ${size.width.toInt()}x${size.height.toInt()}',
            (tester) async {
          SwipPalette.active = palette;
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(MaterialApp(
            home: DashboardPage(
              recent: [event],
              mccFor: (_) => null,
              tapAvailable: true,
              active: false,
            ),
          ));
          await tester.pump(const Duration(milliseconds: 400));

          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
