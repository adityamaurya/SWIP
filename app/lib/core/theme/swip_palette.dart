import 'package:flutter/material.dart';

/// `F-155` — **two grounds, one set of token names.**
///
/// > *"also fix the dark and white mode add a toggle for this in the settings
/// > uss design reference from the screenshots given"*
///
/// ## Why this exists rather than `Theme.of(context)`
///
/// The honest Flutter answer to theming is a `ThemeExtension` read through the
/// element tree. It is also a rewrite: there are **440 references to
/// `SwipColors.*` across 28 files**, every one of them a static read with no
/// `BuildContext` in scope, and several inside `const` constructors. Converting
/// all of that would be the largest diff this project has ever taken, would
/// touch every screen at once, and would be impossible to bisect if a single
/// colour came out wrong.
///
/// So the token *names* stay exactly where they are and only their **values**
/// move. [SwipColors] becomes a set of static getters over [active], and
/// switching the palette is one assignment plus a rebuild of the root widget.
/// That is a two-line change at 440 call sites' worth of leverage.
///
/// ## What that costs, stated plainly
///
/// A static getter is not `const`, so any `const Foo(color: SwipColors.bg)`
/// stops compiling. There were eleven of those and they are now non-`const`.
/// `tool/check_const.py` already exists to catch the reverse mistake and it
/// still runs in the gate.
///
/// The second cost is that nothing rebuilds automatically when [active]
/// changes — there is no `InheritedWidget` to depend on. That is handled by
/// rebuilding from the root: `main.dart` watches the theme setting and keys
/// its `MaterialApp` on it, so a switch rebuilds the whole tree exactly once.
/// For a preference that changes perhaps twice in an install's life, a full
/// rebuild is the right trade against 440 context lookups on every frame.
///
/// ## The two palettes
///
/// **Paper** is the current light ground — `F-130`, argued in
/// `docs/33-VISUAL-DIRECTION-PAPER.md`: white, near-black type, hairlines
/// rather than shadows, and one dark object per screen.
///
/// **Foil** is the original dark ground, recovered from commit `f2acf31^`
/// rather than re-invented. It is the theme in the owner's own screenshots —
/// gold `#C9A227` on `#060507` — and the reason it is coming back as an
/// *option* rather than a replacement is that both are right for different
/// rooms. A ledger read at a counter in daylight wants paper; the same ledger
/// checked in a cinema queue wants foil.
@immutable
class SwipPalette {
  const SwipPalette({
    required this.name,
    required this.brightness,
    required this.bg,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceRaised2,
    required this.hairline,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.gold50,
    required this.gold100,
    required this.gold300,
    required this.gold500,
    required this.gold700,
    required this.goldInk,
    required this.gold900,
    required this.successOnInk,
    required this.warningOnInk,
    required this.dangerOnInk,
    required this.infoOnInk,
    required this.successFill,
    required this.warningFill,
    required this.dangerFill,
    required this.infoFill,
  });

  /// For the settings screen and for debugging. Never shown as a brand name.
  final String name;

  final Brightness brightness;

  final Color bg;
  final Color surface;
  final Color surfaceRaised;
  final Color surfaceRaised2;
  final Color hairline;
  final Color borderStrong;

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  /// The accent ramp. The names say "gold" and in [foil] they are gold; in
  /// [paper] they are a grey ramp with ink at `gold500`.
  ///
  /// The names were kept through `F-130` because 41 call sites mean "the
  /// accent" by `gold500`, and renaming them would have been a large diff that
  /// changed no pixels. Read them as *accent*, not as a hue — which is exactly
  /// what makes them work unchanged across both palettes now.
  final Color gold50;
  final Color gold100;
  final Color gold300;
  final Color gold500;
  final Color gold700;
  final Color goldInk;
  final Color gold900;

  final Color successOnInk;
  final Color warningOnInk;
  final Color dangerOnInk;
  final Color infoOnInk;

  final Color successFill;
  final Color warningFill;
  final Color dangerFill;
  final Color infoFill;

  bool get isDark => brightness == Brightness.dark;

  // ── Paper: the light ground, `F-130` ────────────────────────────────────
  static const paper = SwipPalette(
    name: 'Paper',
    brightness: Brightness.light,
    bg: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFF6F6F7),
    surfaceRaised2: Color(0xFFEFEFF1),
    hairline: Color(0xFFE3E3E7),
    borderStrong: Color(0xFFC7C7CE),
    textPrimary: Color(0xFF0B0B0D),
    textSecondary: Color(0xFF5B5B63),
    textTertiary: Color(0xFF8C8C95),
    gold50: Color(0xFFF7F7F8),
    gold100: Color(0xFFEDEDEF),
    gold300: Color(0xFF3A3A3E),
    gold500: Color(0xFF0B0B0D),
    gold700: Color(0xFFD7D7DB),
    goldInk: Color(0xFF0B0B0D),
    gold900: Color(0xFFE6E6EA),
    successOnInk: Color(0xFF0E7A4A),
    warningOnInk: Color(0xFF8A5A00),
    dangerOnInk: Color(0xFFB3261E),
    infoOnInk: Color(0xFF1A5FB4),
    successFill: Color(0x140E7A4A),
    warningFill: Color(0x148A5A00),
    dangerFill: Color(0x14B3261E),
    infoFill: Color(0x141A5FB4),
  );

  // ── Foil: the dark ground, recovered from `f2acf31^` ─────────────────────
  //
  // Every value below is the original, not a re-derivation. Recovering them
  // from git rather than eyeballing the screenshots matters: these were
  // contrast-checked when they shipped, and a hand-matched approximation would
  // have quietly lost that.
  static const foil = SwipPalette(
    name: 'Foil',
    brightness: Brightness.dark,
    bg: Color(0xFF060507),
    surface: Color(0xFF0C0B0E),
    surfaceRaised: Color(0xFF141216),
    surfaceRaised2: Color(0xFF1C191F),
    hairline: Color(0xFF262229),
    borderStrong: Color(0xFF3A353F),
    textPrimary: Color(0xFFF2EFE9),
    textSecondary: Color(0xFF8E8896),
    textTertiary: Color(0xFF5D5866),
    gold50: Color(0xFFFBF6E6),
    gold100: Color(0xFFF7E7B4),
    gold300: Color(0xFFE8C766),
    gold500: Color(0xFFC9A227),
    gold700: Color(0xFF8A6620),
    goldInk: Color(0xFF7A5E12),
    gold900: Color(0xFF4A3610),
    successOnInk: Color(0xFF34C77B),
    warningOnInk: Color(0xFFE0A22B),
    dangerOnInk: Color(0xFFF2685E),
    infoOnInk: Color(0xFF6FA8F5),
    successFill: Color(0x1A34C77B),
    warningFill: Color(0x1AE0A22B),
    dangerFill: Color(0x1AF2685E),
    infoFill: Color(0x1A6FA8F5),
  );

  /// The palette every [SwipColors] getter reads.
  ///
  /// Mutable global state, which is not a thing to reach for lightly. It is
  /// justified here by the alternative being 440 threaded parameters, and
  /// bounded by one rule: **it is written in exactly one place**, by
  /// `SwipApp` before it builds, and read everywhere else.
  static SwipPalette active = paper;
}
