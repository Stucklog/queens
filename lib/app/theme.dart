import 'package:flutter/material.dart';

import 'journey.dart';

class RegaliaTheme {
  static const ivory = Color(0xfff8f1e3);
  static const ink = Color(0xff24201d);
  static const gold = Color(0xffb68032);
  static const charcoal = Color(0xff17191c);
  static const jewel = Color(0xff3d8078);

  static ThemeData light([JourneyPalette? palette]) => _theme(
    brightness: Brightness.light,
    background: palette?.lightBackground ?? ivory,
    surface: palette?.lightSurface ?? const Color(0xfffffbf3),
    primary: palette?.primary ?? ink,
    secondary: palette?.secondary ?? gold,
  );

  static ThemeData dark([JourneyPalette? palette]) => _theme(
    brightness: Brightness.dark,
    background: palette?.darkBackground ?? charcoal,
    surface: palette?.darkSurface ?? const Color(0xff24272b),
    primary: const Color(0xffe9dfcf),
    secondary: palette?.secondary ?? jewel,
  );

  static ThemeData forChapter(Brightness brightness, JourneyChapter chapter) =>
      brightness == Brightness.dark
          ? dark(chapter.palette)
          : light(chapter.palette);

  static ThemeData _theme({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color primary,
    required Color secondary,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: secondary,
      brightness: brightness,
    ).copyWith(surface: surface, primary: primary, secondary: secondary);
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: const RoundedRectangleBorder(side: BorderSide(width: 2)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: const RoundedRectangleBorder(side: BorderSide(width: 3)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: primary,
      ),
      fontFamily: 'RegaliaSans',
      textTheme: _type(ThemeData(brightness: brightness).textTheme, primary),
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
