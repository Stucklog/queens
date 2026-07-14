import 'package:flutter/material.dart';

class RegaliaTheme {
  static const ivory = Color(0xfff8f1e3);
  static const ink = Color(0xff24201d);
  static const gold = Color(0xffb68032);
  static const charcoal = Color(0xff17191c);
  static const jewel = Color(0xff3d8078);

  static ThemeData light() => _theme(
    brightness: Brightness.light,
    background: ivory,
    surface: const Color(0xfffffbf3),
    primary: ink,
    secondary: gold,
  );

  static ThemeData dark() => _theme(
    brightness: Brightness.dark,
    background: charcoal,
    surface: const Color(0xff24272b),
    primary: const Color(0xffe9dfcf),
    secondary: jewel,
  );

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: primary,
      ),
      fontFamily: 'RegaliaSans',
      textTheme: _type(ThemeData(brightness: brightness).textTheme, primary),
      focusColor: secondary.withValues(alpha: .35),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
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
