import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'swip_tokens.dart';

/// The SWIP theme — "Foil".
///
/// Dark everywhere. Material 3 is the substrate (touch targets, focus and
/// pressed states, text scaling, RTL, TalkBack/VoiceOver semantics, platform
/// scroll physics) and every visible surface of it is overridden. What survives
/// from M3 is *behaviour*, not appearance — those are the things that take a
/// year to get right and that nobody notices until they are wrong.
///
/// See `docs/14-VISUAL-DIRECTION-FOIL.md`.
abstract final class SwipTheme {
  /// The only theme. [light] is kept as an alias so nothing breaks, but it
  /// returns the same dark theme — SWIP has one look.
  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: SwipColors.gold500,
      onPrimary: Color(0xFF14100A),
      primaryContainer: SwipColors.gold900,
      onPrimaryContainer: SwipColors.gold100,
      secondary: SwipColors.gold300,
      onSecondary: Color(0xFF14100A),
      surface: SwipColors.surface,
      onSurface: SwipColors.textPrimary,
      surfaceContainerHighest: SwipColors.surfaceRaised2,
      onSurfaceVariant: SwipColors.textSecondary,
      outline: SwipColors.hairline,
      outlineVariant: SwipColors.hairline,
      error: SwipColors.dangerOnInk,
      onError: Color(0xFF14100A),
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: SwipColors.bg,
      canvasColor: SwipColors.bg,
      fontFamily: SwipType.family,
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      textTheme: _text(base.textTheme),

      appBarTheme: const AppBarTheme(
        backgroundColor: SwipColors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: SwipColors.textPrimary),
        titleTextStyle: TextStyle(
          fontFamily: SwipType.family,
          fontSize: 22,
          height: 28 / 22,
          fontWeight: FontWeight.w600,
          color: SwipColors.textPrimary,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: SwipColors.bg,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      ),

      // Borders first, shadows barely. A shadow on near-black is invisible;
      // what separates surfaces here is a 1px hairline and a lift in value.
      cardTheme: CardThemeData(
        color: SwipColors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: SwipRadius.cardAll,
          side: const BorderSide(color: SwipColors.hairline, width: 1),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: SwipColors.hairline,
        thickness: 1,
        space: 1,
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: SwipColors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: SwipColors.borderStrong,
        shape: RoundedRectangleBorder(borderRadius: SwipRadius.sheetTop),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: SwipColors.gold500,
          foregroundColor: const Color(0xFF14100A),
          minimumSize: const Size(0, 52),
          shape: const RoundedRectangleBorder(borderRadius: SwipRadius.inputAll),
          textStyle: SwipType.label.copyWith(fontSize: 15),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: SwipColors.textPrimary,
          minimumSize: const Size(0, 52),
          side: const BorderSide(color: SwipColors.borderStrong),
          shape: const RoundedRectangleBorder(borderRadius: SwipRadius.inputAll),
          textStyle: SwipType.label.copyWith(fontSize: 15),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: SwipColors.gold300,
          minimumSize: const Size(0, 48),
          textStyle: SwipType.label,
        ),
      ),

      iconTheme: const IconThemeData(color: SwipColors.textSecondary, size: 24),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: SwipColors.surfaceRaised2,
        hintStyle: SwipType.bodyM.copyWith(color: SwipColors.textTertiary),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: SwipSpace.lg, vertical: SwipSpace.lg),
        border: OutlineInputBorder(
          borderRadius: SwipRadius.inputAll,
          borderSide: const BorderSide(color: SwipColors.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: SwipRadius.inputAll,
          borderSide: const BorderSide(color: SwipColors.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: SwipRadius.inputAll,
          borderSide: const BorderSide(color: SwipColors.gold500, width: 2),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: SwipColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: SwipColors.gold900,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => SwipType.labelS.copyWith(
            color: s.contains(WidgetState.selected)
                ? SwipColors.gold300
                : SwipColors.textTertiary,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            size: 24,
            color: s.contains(WidgetState.selected)
                ? SwipColors.gold300
                : SwipColors.textTertiary,
          ),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: SwipColors.surfaceRaised2,
        contentTextStyle: SwipType.bodyM.copyWith(color: SwipColors.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: SwipRadius.inputAll),
      ),

      listTileTheme: const ListTileThemeData(
        iconColor: SwipColors.textSecondary,
        textColor: SwipColors.textPrimary,
        minVerticalPadding: SwipSpace.md,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? const Color(0xFF14100A)
                : SwipColors.textSecondary),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? SwipColors.gold500
                : SwipColors.surfaceRaised2),
      ),

    );
  }

  /// Deprecated alias. SWIP is dark-only; this returns [dark].
  static ThemeData light() => dark();

  static TextTheme _text(TextTheme base) => base.copyWith(
        displayLarge: SwipType.display.copyWith(color: SwipColors.textPrimary),
        headlineLarge: SwipType.titleL.copyWith(color: SwipColors.textPrimary),
        headlineMedium: SwipType.titleM.copyWith(color: SwipColors.textPrimary),
        titleLarge: SwipType.titleM.copyWith(color: SwipColors.textPrimary),
        titleMedium: SwipType.titleS.copyWith(color: SwipColors.textPrimary),
        bodyLarge: SwipType.bodyL.copyWith(color: SwipColors.textPrimary),
        bodyMedium: SwipType.bodyM.copyWith(color: SwipColors.textPrimary),
        bodySmall: SwipType.bodyS.copyWith(color: SwipColors.textSecondary),
        labelLarge: SwipType.label.copyWith(color: SwipColors.textPrimary),
        labelSmall: SwipType.labelS.copyWith(color: SwipColors.textSecondary),
      );
}
