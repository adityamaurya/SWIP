import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../settings/prefs.dart';
import 'swip_palette.dart';

/// `F-155` — which ground the app is on, and who decides.
///
/// Three options rather than two, and the third is the default.
///
/// | Choice | What it means |
/// |---|---|
/// | [SwipThemeChoice.system] | Follow the phone. **Default** |
/// | [SwipThemeChoice.paper] | Always light |
/// | [SwipThemeChoice.foil] | Always dark |
///
/// "Follow the phone" is the default because a person who has set their phone
/// to dark has already answered this question once and should not be asked
/// again by every app they install. The two explicit options exist because
/// that preference is about the whole phone, and a ledger read at a counter in
/// daylight is a different situation from the same ledger checked in a cinema
/// queue.
enum SwipThemeChoice {
  system,
  paper,
  foil;

  String get label => switch (this) {
        SwipThemeChoice.system => 'Match my phone',
        SwipThemeChoice.paper => 'Light',
        SwipThemeChoice.foil => 'Dark',
      };

  /// The one-line description under each option. Says what it *looks* like
  /// rather than what it is called, because "Foil" means nothing to anybody
  /// who has not read the design docs.
  String get note => switch (this) {
        SwipThemeChoice.system =>
          'Changes with your phone\'s light and dark setting',
        SwipThemeChoice.paper => 'Paper white, near-black type',
        SwipThemeChoice.foil => 'Near-black, with the gold accent',
      };

  ThemeMode get themeMode => switch (this) {
        SwipThemeChoice.system => ThemeMode.system,
        SwipThemeChoice.paper => ThemeMode.light,
        SwipThemeChoice.foil => ThemeMode.dark,
      };

  /// Resolve to an actual palette.
  ///
  /// [platformIsDark] is only consulted for [system]; it comes from the view's
  /// `platformBrightness` rather than from `MediaQuery`, because the palette
  /// has to be chosen **before** the first widget is built and there is no
  /// context at that point.
  SwipPalette palette({required bool platformIsDark}) => switch (this) {
        SwipThemeChoice.paper => SwipPalette.paper,
        SwipThemeChoice.foil => SwipPalette.foil,
        SwipThemeChoice.system =>
          platformIsDark ? SwipPalette.foil : SwipPalette.paper,
      };

  static SwipThemeChoice parse(String? s) => SwipThemeChoice.values
      .firstWhere((c) => c.name == s, orElse: () => SwipThemeChoice.system);
}

const _kThemeKey = 'swip.theme.choice';

class ThemeSettingNotifier extends StateNotifier<SwipThemeChoice> {
  ThemeSettingNotifier(this._prefs)
      : super(SwipThemeChoice.parse(_prefs?.getString(_kThemeKey)));

  final SharedPreferences? _prefs;

  Future<void> choose(SwipThemeChoice choice) async {
    if (choice == state) return;
    state = choice;
    await _prefs?.setString(_kThemeKey, choice.name);
  }
}

final themeSettingProvider =
    StateNotifierProvider<ThemeSettingNotifier, SwipThemeChoice>(
  (ref) => ThemeSettingNotifier(
    ref.watch(sharedPreferencesProvider).valueOrNull,
  ),
);
