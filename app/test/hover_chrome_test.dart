import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swip/core/theme/swip_palette.dart';
import 'package:swip/features/bubble/hover_scan.dart';

/// `F-172` — can the close button actually be seen?
///
/// > *"the close button at the below should be a bit more prominent … also
/// > make it compatible with black and white mode"*
///
/// ## Why this is a contrast test and not a golden or a widget test
///
/// The thing that was wrong was not the size, the shape or the wiring — all
/// three were fine. It was that a near-black pill at 80% opacity, on a 45%
/// black scrim, over a dark app, composites to roughly RGB 5 on black. Every
/// widget in that sentence built correctly and rendered exactly what it was
/// asked to; the button was simply the same colour as its surroundings.
///
/// No widget test can see that, because nothing throws. A golden could, but a
/// golden of a hovering card would need a camera behind it and would have to
/// be regenerated whenever the copy changed, which is how goldens end up
/// approved blind.
///
/// So the assertion is made on the arithmetic instead: composite the chrome
/// the way the GPU will, and check the WCAG contrast ratio. That is a claim
/// about legibility stated in the only terms legibility has.
///
/// ## Why "over white" and "over black"
///
/// This card floats over an app SWIP did not draw and cannot measure — a bank,
/// a chat, a photo. Those two are the extremes every real screen sits between,
/// so passing both is passing all of them. Testing against SWIP's own ground
/// would be testing the one background this window never has.
void main() {
  /// Paint [top] onto [bottom], the way the compositor does.
  Color over(Color top, Color bottom) {
    final a = top.a;
    int mix(double t, double b) => (t * 255 * a + b * 255 * (1 - a)).round();
    return Color.fromARGB(255, mix(top.r, bottom.r), mix(top.g, bottom.g),
        mix(top.b, bottom.b));
  }

  /// WCAG relative luminance.
  double luminance(Color c) {
    double channel(double v) => v <= 0.03928
        ? v / 12.92
        // `.toDouble()` rather than `as double`: `math.pow` is declared to
        // return `num`, and a cast that happens to succeed today is a cast
        // that fails the first time an argument makes it return an int.
        : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * channel(c.r) +
        0.7152 * channel(c.g) +
        0.0722 * channel(c.b);
  }

  double contrast(Color a, Color b) {
    final la = luminance(a);
    final lb = luminance(b);
    final hi = math.max(la, lb);
    final lo = math.min(la, lb);
    return (hi + 0.05) / (lo + 0.05);
  }

  const white = Color(0xFFFFFFFF);
  const black = Color(0xFF000000);

  for (final palette in <SwipPalette>[SwipPalette.paper, SwipPalette.foil]) {
    group('in ${palette.name}', () {
      setUp(() => SwipPalette.active = palette);
      // The global is process-wide, so leaving it set would silently decide
      // the next test file's answers. `theme_test.dart` learned this already.
      tearDown(() => SwipPalette.active = SwipPalette.paper);

      for (final entry in <String, Color>{'a white app': white, 'a black app': black}.entries) {
        final app = entry.value;

        test('the close button stands off ${entry.key}', () {
          final ground = over(HoverChrome.scrim, app);
          final pill = over(HoverChrome.closeFill, ground);

          // 3:1 is WCAG's threshold for a non-text graphical object against
          // what is adjacent to it, which is exactly what a pill on a scrim
          // is. The old near-black pill scored 1.03 over a black app.
          expect(contrast(pill, ground), greaterThanOrEqualTo(3.0),
              reason: 'the pill is not distinguishable from the scrim');

          // And the label on the pill, at the 4.5:1 text threshold.
          final ink = over(HoverChrome.closeInk, pill);
          expect(contrast(ink, pill), greaterThanOrEqualTo(4.5),
              reason: 'the word Close is not readable on its own button');
        });

        test('the grip stands off ${entry.key}', () {
          final ground = over(HoverChrome.scrim, app);
          final grip = over(HoverChrome.grip, ground);
          // 2.0, not the 3.0 above, and the lower bar is honest rather than
          // convenient. WCAG's 3:1 covers graphical objects *required to
          // understand the content*; this grip is required for nothing — it
          // duplicates a tap on the scrim and a labelled Close button, and it
          // is there to say "this is a panel". Held to 3:1 it would have to be
          // pure white, which would make the decoration louder than the
          // control beneath it.
          expect(contrast(grip, ground), greaterThanOrEqualTo(2.0));
        });
      }

      test('the scrim actually darkens both extremes', () {
        // A scrim that does not darken is a scrim that is not doing its job,
        // and a light-mode scrim that went pale would be white fog over the
        // camera — `theme_test.dart` records that happening once.
        expect(luminance(over(HoverChrome.scrim, white)),
            lessThan(luminance(white)));
        expect(HoverChrome.scrimAlpha, greaterThan(0.45));
      });
    });
  }

  test('the chrome does NOT follow the palette', () {
    // The deliberate half of "compatible with black and white mode". This card
    // hovers over an app SWIP did not draw, so it is governed by CLAUDE.md's
    // camera-overlay rule rather than the theme: it carries its own contrast.
    //
    // Following the palette is precisely what broke it — the first fix used
    // `SwipColors.surfaceRaised`, which is paper-white in Paper and `#141216`
    // in Foil, so Foil got the invisible near-black pill back. Asserting the
    // colours are palette-independent is asserting that cannot return.
    SwipPalette.active = SwipPalette.paper;
    final fillOnPaper = HoverChrome.closeFill;
    final inkOnPaper = HoverChrome.closeInk;
    final gripOnPaper = HoverChrome.grip;

    SwipPalette.active = SwipPalette.foil;
    expect(HoverChrome.closeFill, fillOnPaper);
    expect(HoverChrome.closeInk, inkOnPaper);
    expect(HoverChrome.grip, gripOnPaper);

    SwipPalette.active = SwipPalette.paper;
  });

  test('the scrim, which is SWIP\'s own, DOES follow it', () {
    // The one piece that should differ, because it is not competing with the
    // app underneath — it is the thing hiding the app underneath.
    SwipPalette.active = SwipPalette.paper;
    final onPaper = HoverChrome.scrimAlpha;
    SwipPalette.active = SwipPalette.foil;
    expect(HoverChrome.scrimAlpha, isNot(onPaper));
    SwipPalette.active = SwipPalette.paper;
  });
}
