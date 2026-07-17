import 'package:flutter/material.dart';

import 'journey.dart';

class RegaliaTheme {
  static const midnightBlue = regaliaMidnight;
  static const midnightSurface = regaliaMidnightSurface;
  static const midnightSurfaceLow = Color(0xff1b2444);
  static const midnightSurfaceHigh = Color(0xff303c60);
  static const ivory = Color(0xfffff3dc);
  static const gold = Color(0xffd6af53);

  static ThemeData midnight([JourneyPalette? palette]) =>
      _theme(secondary: palette?.secondary ?? gold);

  static ThemeData forChapter(JourneyChapter chapter) =>
      midnight(chapter.palette);

  static ThemeData _theme({required Color secondary}) {
    final secondaryContainer = Color.lerp(midnightSurface, secondary, .24)!;
    final scheme = ColorScheme.fromSeed(
      seedColor: secondary,
      brightness: Brightness.dark,
    ).copyWith(
      surface: midnightSurface,
      onSurface: ivory,
      surfaceDim: midnightBlue,
      surfaceBright: midnightSurfaceHigh,
      surfaceContainerLowest: midnightBlue,
      surfaceContainerLow: midnightSurfaceLow,
      surfaceContainer: midnightSurface,
      surfaceContainerHigh: const Color(0xff2a3659),
      surfaceContainerHighest: midnightSurfaceHigh,
      onSurfaceVariant: const Color(0xffd3d7e7),
      outline: const Color(0xff919cbd),
      outlineVariant: const Color(0xff4b587c),
      primary: ivory,
      onPrimary: midnightBlue,
      primaryContainer: midnightSurfaceHigh,
      onPrimaryContainer: ivory,
      secondary: secondary,
      onSecondary: _foregroundFor(secondary),
      secondaryContainer: secondaryContainer,
      onSecondaryContainer: ivory,
      inverseSurface: ivory,
      onInverseSurface: midnightBlue,
      inversePrimary: secondary,
      surfaceTint: Colors.transparent,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: midnightBlue,
      cardTheme: CardThemeData(
        color: midnightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: scheme.outlineVariant, width: 2),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: midnightSurface,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: scheme.outline, width: 3),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: ivory,
      ),
      fontFamily: 'RegaliaSans',
      textTheme: _type(ThemeData.dark().textTheme, ivory),
      focusColor: secondary.withValues(alpha: .35),
      splashFactory: NoSplash.splashFactory,
      filledButtonTheme: const FilledButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(RoundedRectangleBorder()),
        ),
      ),
      outlinedButtonTheme: const OutlinedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(RoundedRectangleBorder()),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _InstantPageTransitionsBuilder(),
          TargetPlatform.iOS: _InstantPageTransitionsBuilder(),
          TargetPlatform.macOS: _InstantPageTransitionsBuilder(),
          TargetPlatform.windows: _InstantPageTransitionsBuilder(),
          TargetPlatform.linux: _InstantPageTransitionsBuilder(),
        },
      ),
    );
  }

  static Color _foregroundFor(Color background) {
    final luminance = background.computeLuminance();
    final darkContrast =
        (luminance + .05) / (midnightBlue.computeLuminance() + .05);
    final lightContrast = (ivory.computeLuminance() + .05) / (luminance + .05);
    return darkContrast >= lightContrast ? midnightBlue : ivory;
  }

  static TextTheme _type(TextTheme base, Color color) => base
      .apply(fontFamily: 'RegaliaSans', bodyColor: color, displayColor: color)
      .copyWith(
        displayLarge: base.displayLarge?.copyWith(
          fontFamily: 'RegaliaDisplay',
          fontWeight: FontWeight.w700,
          color: color,
        ),
        displayMedium: base.displayMedium?.copyWith(
          fontFamily: 'RegaliaDisplay',
          fontWeight: FontWeight.w700,
          color: color,
        ),
        displaySmall: base.displaySmall?.copyWith(
          fontFamily: 'RegaliaDisplay',
          fontWeight: FontWeight.w700,
          color: color,
        ),
        headlineLarge: base.headlineLarge?.copyWith(
          fontFamily: 'RegaliaDisplay',
          fontWeight: FontWeight.w700,
          color: color,
        ),
        headlineMedium: base.headlineMedium?.copyWith(
          fontFamily: 'RegaliaDisplay',
          fontWeight: FontWeight.w700,
          color: color,
        ),
        headlineSmall: base.headlineSmall?.copyWith(
          fontFamily: 'RegaliaDisplay',
          fontWeight: FontWeight.w700,
          color: color,
        ),
      );
}

class _InstantPageTransitionsBuilder extends PageTransitionsBuilder {
  const _InstantPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}
