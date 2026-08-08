import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'swip_tokens.dart';

/// The SWIP theme.
///
/// Ideation `A-07`: build on an established design system rather than invent
/// one. The substrate is **Material 3** — not so SWIP looks like Google (it must
/// not), but because M3 gives us, correct and free: touch targets, focus and
/// pressed states, text scaling, RTL, TalkBack/VoiceOver semantics and native
/// scroll physics. Those take a year to get right and nobody notices them until
/// they are wrong.
///
/// Then every visible role is overridden. What survives from Material is
/// behaviour, not appearance.
abstract final class SwipTheme {
  static ThemeData light() {
    const scheme = ColorScheme.light(
      primary: SwipColors.ink900,
      onPrimary: SwipColors.white,
      primaryContainer: SwipColors.gold500,
      onPrimaryContainer: SwipColors.ink900,
      secondary: SwipColors.gold500,
      onSecondary: SwipColors.ink900,
      surface: SwipColors.surface,
      onSurface: SwipColors.ink900,
      surfaceContainerLowest: SwipColors.surface,
      surfaceContainerLow: SwipColors.surfaceSubdued,
      surfaceContainer: SwipColors.surfaceSunken,
      onSurfaceVariant: SwipColors.ink500,
      outline: SwipColors.border,
      outlineVariant: SwipColors.ink100,
      error: SwipColors.danger,
      onError: SwipColors.white,
      inverseSurface: SwipColors.ink900,
      onInverseSurface: SwipColors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: SwipType.family,
      scaffoldBackgroundColor: SwipColors.surface,
      splashFactory: InkSparkle.splashFactory,

      textTheme: const TextTheme(
        displayLarge: SwipType.display,
        headlineLarge: SwipType.titleL,
        headlineMedium: SwipType.titleM,
        titleLarge: SwipType.titleM,
        titleMedium: SwipType.titleS,
        bodyLarge: SwipType.bodyL,
        bodyMedium: SwipType.bodyM,
        bodySmall: SwipType.bodyS,
        labelLarge: SwipType.label,
        labelSmall: SwipType.labelS,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: SwipColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: SwipType.titleM,
        foregroundColor: SwipColors.ink900,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),

      cardTheme: CardTheme(
        color: SwipColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: SwipRadius.cardAll,
          side: const BorderSide(color: SwipColors.border),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: SwipColors.ink100,
        thickness: 1,
        space: 1,
      ),

      // Gold fill with Ink text. Per the gold rule, gold is never the *text*
      // colour on a light surface — only ever the fill beneath Ink.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: SwipColors.gold500,
          foregroundColor: SwipColors.ink900,
          textStyle: SwipType.label,
          minimumSize: const Size(64, 52),
          shape: const RoundedRectangleBorder(borderRadius: SwipRadius.inputAll),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: SwipColors.ink900,
          textStyle: SwipType.label,
          minimumSize: const Size(64, 52),
          side: const BorderSide(color: SwipColors.borderStrong),
          shape: const RoundedRectangleBorder(borderRadius: SwipRadius.inputAll),
        ),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: SwipColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: SwipRadius.sheetTop),
        showDragHandle: true,
        dragHandleColor: SwipColors.ink200,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: SwipColors.surfaceSunken,
        border: OutlineInputBorder(
          borderRadius: SwipRadius.inputAll,
          borderSide: BorderSide.none,
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: SwipRadius.inputAll,
          borderSide: BorderSide(color: SwipColors.gold500, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: SwipSpace.lg, vertical: SwipSpace.lg),
        hintStyle: SwipType.bodyM.copyWith(color: SwipColors.ink300),
      ),

      // 48dp minimum touch targets, everywhere, enforced by the framework.
      materialTapTargetSize: MaterialTapTargetSize.padded,

      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
        // Cupertino transitions on iOS so back-swipe and physics feel native.
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
    );
  }

  /// Dark theme is scaffolded but **off by default** per ideation `A-06` — you
  /// asked for a light interior. Two themes double the QA surface and there is
  /// one designer, so this ships in v1.2, not v1.
  static ThemeData dark() => light();
}
