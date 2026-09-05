/// SWIP design tokens — see the class docs below.
library;

import 'package:flutter/widgets.dart';

/// SWIP design tokens.
///
/// The single source of truth for colour, type, space, radius, elevation and
/// motion. Mirrors `docs/06-DESIGN-SYSTEM.md` and the Figma variable
/// collection; if you change a value here, change it in both other places or
/// they drift apart within a sprint.
///
/// Nothing in `features/` may hard-code a colour, size or duration. If a value
/// is missing, add it here.

// ─────────────────────────────────────────────────────────────── colour

/// Brand and surface colours — **monochrome**.
///
/// `F-130`. The foil interior shipped, was lived with, and was replaced. The
/// reference was Ramp and CRED's Circle: paper-white ground, near-black type,
/// hairline borders, and colour used only where it carries meaning.
///
/// ## Why the token names still say "gold"
///
/// Ninety-five call sites reference `gold500` and friends. Renaming them all
/// would be a large, risky diff that changes no pixels, so the **values** were
/// repointed and the names left alone. `gold500` is now near-black ink and is
/// still "the one accent colour" — which is what every one of those call sites
/// actually meant. Read the name as *accent*, not as a hue.
///
/// ## The rule that replaces THE GOLD RULE
///
/// The old rule existed because gold is 2.3:1 on white and fails AA as text.
/// There is no such trap now, and the constraint is aesthetic rather than
/// technical: **exactly one thing on a screen may be near-black at weight.**
/// Normally that is the MCC. On this ground the category is the largest,
/// darkest thing in view and needs no colour at all to be the hero — which is
/// the whole argument for monochrome.
///
/// Semantic colour survives, narrowly: green, amber, red and blue appear only
/// where the meaning *is* the colour (a decline, a warning, a confirmation),
/// and never as decoration. All four are the light-surface variants now, since
/// the ground is white — the `…OnInk` names, like the gold ones, kept their
/// spelling and changed their value.
abstract final class SwipColors {
  // Brand — gold
  static const gold50 = Color(0xFFF7F7F8);
  static const gold100 = Color(0xFFEDEDEF);
  static const gold300 = Color(0xFF3A3A3E);
  static const gold500 = Color(0xFF0B0B0D); // THE accent: ink, not gold
  static const gold700 = Color(0xFFD7D7DB);
  static const goldInk = Color(0xFF0B0B0D); // accent TEXT on light
  static const gold900 = Color(0xFFE6E6EA);

  // Brand — ink
  static const ink900 = Color(0xFF0A0A0A); // SWIP Ink
  static const ink700 = Color(0xFF2E2E2E);
  static const ink500 = Color(0xFF5C5C5C);
  static const ink300 = Color(0xFF8E8E8E); // ≥18px only (3.5:1)
  static const ink200 = Color(0xFFC9C9C9);
  static const ink100 = Color(0xFFE4E4E7);
  static const ink50 = Color(0xFFF4F4F5);

  // ── Surface — PAPER, light everywhere ──────────────────────────────
  //
  // `F-130`. Inverts the foil direction. The accent is ink, so it clears 18:1
  // on this ground and there is no contrast trap left anywhere in the palette.
  //
  // Restraint is still the brief. Where the old rule was "minimal gold, never
  // gaudy", the new one is "minimal weight": one dark element per screen, and
  // hairlines rather than shadows.

  /// The ground. Pure white — the Ramp reference is paper, and an off-white
  /// ground makes every white card on top of it look like a mistake.
  static const bg = Color(0xFFFFFFFF);

  /// Default screen surface.
  static const surface = Color(0xFFFFFFFF);

  /// Cards, sheets, rows.
  static const surfaceRaised = Color(0xFFF6F6F7);

  /// Input wells, code blocks, pressed states.
  static const surfaceRaised2 = Color(0xFFEFEFF1);

  /// 1px separators.
  static const hairline = Color(0xFFE3E3E7);

  // ── Text on the dark ground ──────────────────────────────────────────
  /// Primary text. Near-black, not #000 — pure black on pure white vibrates and
  /// is tiring to read a ledger in. 18.4:1.
  static const textPrimary = Color(0xFF0B0B0D);

  /// Secondary text. 7.1:1 on [bg].
  static const textSecondary = Color(0xFF5B5B63);

  /// Tertiary. 3.2:1 — large or non-essential text only, never body copy.
  static const textTertiary = Color(0xFF8C8C95);

  // Legacy aliases, repointed so existing widgets keep compiling.
  static const surfaceSubdued = surfaceRaised;
  static const surfaceSunken = surfaceRaised2;
  static const surfaceInverse = bg;
  static const border = hairline;
  static const borderStrong = Color(0xFFC7C7CE);

  // ── Semantic, on the dark ground ─────────────────────────────────────
  // The light-surface semantics below are 2–3:1 on [bg] and unusable as text.
  // These are the ones to reach for; all clear AAA on #060507.
  static const successOnInk = Color(0xFF0E7A4A);
  static const warningOnInk = Color(0xFF8A5A00);
  static const dangerOnInk = Color(0xFFB3261E);
  static const infoOnInk = Color(0xFF1A5FB4);

  /// Tinted backfills for banners. Kept very low-alpha: a saturated block on
  /// near-black reads as an error even when it is only information.
  static const successFill = Color(0x140E7A4A);
  static const warningFill = Color(0x148A5A00);
  static const dangerFill = Color(0x14B3261E);
  static const infoFill = Color(0x141A5FB4);

  // Semantic — the originals, now identical in intent to the `…OnInk` set
  // above. Kept so existing call sites compile; prefer the `…OnInk` names.
  static const success = Color(0xFF0E7A4A);
  static const successBg = Color(0xFFE9F6F0);
  static const warning = Color(0xFFA66A00);
  static const warningBg = Color(0xFFFDF3E3);
  static const danger = Color(0xFFB3261E);
  static const dangerBg = Color(0xFFFCEBEA);
  static const info = Color(0xFF1A5FB4);
  static const infoBg = Color(0xFFEAF1FB);

  static const white = Color(0xFFFFFFFF);

  // ── Over the camera feed ────────────────────────────────────────────────
  //
  // `F-130`. **These deliberately do not follow the app's ground.**
  //
  // Every other colour here sits on a surface SWIP controls. These sit on an
  // arbitrary live image — a marble counter, a black terminal, a moving hand —
  // and the only treatment that survives all of them is light-on-dark. When
  // the palette flipped from foil to paper, the scrim was `bg` and silently
  // became a white fog over the feed; that is the bug these constants exist to
  // make impossible to reintroduce.
  //
  // Rule: anything painted over the viewfinder uses `onCamera*`, never
  // `textPrimary`, `bg` or `gold500`.

  /// The dim over the feed. Ink, always, whatever the app ground is.
  static const onCameraScrim = Color(0xFF08070A);

  /// Text and brackets over the feed. 14:1 on the scrim at 58 %.
  static const onCameraInk = Color(0xFFF4F3EF);

  /// The one accent over the feed. Gold survives here because the ground under
  /// it is guaranteed dark — this is the last gold left in the app, and it is
  /// on the only surface where the old rule still holds.
  static const onCameraAccent = Color(0xFFE8C766);

}

/// Confidence colours.
///
/// Not decoration. In a finance app a number shown with unearned certainty is a
/// defect, so every MCC carries its confidence wherever it appears — and always
/// as a dot *and* a word, never colour alone (roughly 1 in 12 men has a colour
/// vision deficiency, and this audience skews heavily male).
abstract final class SwipConfidenceColors {
  static const verified = SwipColors.success;
  static const likely = SwipColors.warning;
  static const unknown = SwipColors.ink500;
  static const conflict = SwipColors.danger;

  /// The same four, for Ink surfaces — the dashboard hero, the virtual card,
  /// the coin balance.
  ///
  /// The set above is tuned for white and collapses on black: [verified] is
  /// 2.2:1 on [SwipColors.ink900]. These are named constants rather than a
  /// computed lift because lerping the light colours toward white does clear
  /// AA but desaturates them — verified lands on a sage #7AB69B and stops
  /// reading as *green*, which is the one thing that colour is carrying. These
  /// hold their hue and clear AAA (~7.2:1 to ~10:1 on ink900).
  ///
  /// The rule generalises: any semantic colour placed on [SwipColors.ink900]
  /// needs an on-ink counterpart. Give `success` and `danger` the same
  /// treatment when they first appear on a black card.
  static const verifiedOnInk = Color(0xFF0E7A4A);
  static const likelyOnInk = Color(0xFF8A5A00);
  static const unknownOnInk = Color(0xFF6B6B73);
  static const conflictOnInk = Color(0xFFB3261E);
}

// ─────────────────────────────────────────────────────────────── type

abstract final class SwipType {
  static const family = 'Inter';

  /// Tabular figures. Applied to every numeral in the app without exception:
  /// MCCs stacked in a ledger must align on the digit or the column reads as
  /// noise — and that column is the single most important thing on screen.
  static const tabular = <FontFeature>[FontFeature.tabularFigures()];

  static const display = TextStyle(
      fontFamily: family,
      fontSize: 40,
      height: 44 / 40,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.8,
      fontFeatures: tabular);

  /// The MCC number itself.
  static const mcc = TextStyle(
      fontFamily: family,
      fontSize: 34,
      height: 38 / 34,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.34,
      fontFeatures: tabular);

  static const titleL = TextStyle(
      fontFamily: family,
      fontSize: 28,
      height: 34 / 28,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.28);

  static const titleM = TextStyle(
      fontFamily: family,
      fontSize: 22,
      height: 28 / 22,
      fontWeight: FontWeight.w600);

  static const titleS = TextStyle(
      fontFamily: family,
      fontSize: 18,
      height: 24 / 18,
      fontWeight: FontWeight.w600);

  static const bodyL = TextStyle(
      fontFamily: family,
      fontSize: 17,
      height: 24 / 17,
      fontWeight: FontWeight.w400);

  static const bodyM = TextStyle(
      fontFamily: family,
      fontSize: 15,
      height: 22 / 15,
      fontWeight: FontWeight.w400);

  static const bodyS = TextStyle(
      fontFamily: family,
      fontSize: 13,
      height: 18 / 13,
      fontWeight: FontWeight.w400);

  static const label = TextStyle(
      fontFamily: family,
      fontSize: 13,
      height: 16 / 13,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.26);

  /// Publication chips: NATIONAL / INTL / RUPAY.
  static const labelS = TextStyle(
      fontFamily: family,
      fontSize: 11,
      height: 14 / 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.44);

  /// VPAs, terminal IDs, raw TLV.
  static const mono = TextStyle(
      fontFamily: family,
      fontSize: 15,
      height: 20 / 15,
      fontWeight: FontWeight.w500,
      fontFeatures: tabular);
}

// ─────────────────────────────────────────────────────────── space & shape

abstract final class SwipSpace {
  static const xxs = 2.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;
  static const huge = 40.0;
  static const giant = 56.0;
  static const colossal = 72.0;

  /// Screen gutter.
  static const gutter = xl;

  /// Card padding.
  static const card = lg;

  /// Gap between sections.
  static const section = xxl;
}

abstract final class SwipRadius {
  static const chip = Radius.circular(8);
  static const input = Radius.circular(12);
  static const card = Radius.circular(16);
  static const sheet = Radius.circular(24);
  static const pill = Radius.circular(999);

  static const chipAll = BorderRadius.all(chip);
  static const inputAll = BorderRadius.all(input);
  static const cardAll = BorderRadius.all(card);
  static const pillAll = BorderRadius.all(pill);
  static const sheetTop =
      BorderRadius.only(topLeft: sheet, topRight: sheet);
}

/// Elevation.
///
/// The light theme leans on borders and uses shadow sparingly — Material's
/// default elevation ramp looks cheap on white. [e1] is the default for cards
/// and rows and is a *border*, not a shadow.
abstract final class SwipElevation {
  static const List<BoxShadow> e0 = [];

  static const List<BoxShadow> e2 = [
    BoxShadow(
        color: Color(0x0F0A0A0A), blurRadius: 2, offset: Offset(0, 1)),
  ];

  static const List<BoxShadow> e3 = [
    BoxShadow(
        color: Color(0x1A0A0A0A), blurRadius: 24, offset: Offset(0, 8)),
  ];

  static const List<BoxShadow> e4 = [
    BoxShadow(
        color: Color(0x290A0A0A), blurRadius: 48, offset: Offset(0, 16)),
  ];

  /// The default card/row treatment: a hairline, no shadow.
  static Border get e1 => Border.all(color: SwipColors.border, width: 1);
}

// ─────────────────────────────────────────────────────────────── motion

abstract final class SwipMotion {
  static const micro = Duration(milliseconds: 120);
  static const standard = Duration(milliseconds: 200);
  static const emphasized = Duration(milliseconds: 320);

  /// The capture reveal.
  static const capture = Duration(milliseconds: 480);

  /// The signature foil sweep. Splash, verified capture, coin transfer —
  /// and nowhere else. Using it anywhere else destroys it.
  static const foilSweep = Duration(milliseconds: 900);

  static const standardCurve = Cubic(0.2, 0, 0, 1);
  static const emphasizedCurve = Cubic(0.05, 0.7, 0.1, 1);
  static const captureCurve = Cubic(0.16, 1, 0.3, 1);
}

/// `F-130`. The graphite gradient. Was gold foil; the geometry and the stops
/// are unchanged, only the hues — so anything already using it (the goal bar,
/// the capture shimmer) keeps its motion and loses its colour.
///
/// Use with a shader that spans the whole text run — per-glyph gradients
/// shatter it into unrelated shards, which is the single most common way a
/// metallic treatment goes wrong.
abstract final class SwipGradients {
  static const foil = LinearGradient(
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
    colors: [
      Color(0xFF2A2A2E),
      Color(0xFF4A4A52),
      Color(0xFF6E6E78),
      Color(0xFF9A9AA4),
      Color(0xFFC9C9D1),
      Color(0xFF9A9AA4),
      Color(0xFF6E6E78),
      Color(0xFF3A3A40),
      Color(0xFF1A1A1E),
    ],
    stops: [0.0, 0.14, 0.33, 0.47, 0.53, 0.62, 0.78, 0.90, 1.0],
  );
}
