import 'package:flutter/material.dart';

import '../widgets/pixel_ui.dart';
import 'journey.dart';

class RegaliaTheme {
  static const midnightBlue = regaliaMidnight;
  static const midnightSurface = regaliaMidnightSurface;
  static const midnightSurfaceLow = Color(0xff1b2444);
  static const midnightSurfaceHigh = Color(0xff303c60);
  static const ivory = Color(0xfffff3dc);
  static const gold = Color(0xffd6af53);
  static const ink = Color(0xff080d20);
  static const danger = Color(0xfff06b6b);

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
      canvasColor: midnightBlue,
      cardTheme: CardThemeData(
        color: midnightSurface,
        elevation: 0,
        shape: PixelOrganicBorder(
          side: BorderSide(color: scheme.outline, width: 2),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: midnightSurface,
        elevation: 0,
        shape: PixelOrganicBorder(side: BorderSide(color: secondary, width: 3)),
        titleTextStyle: _type(ThemeData.dark().textTheme, ivory).headlineSmall,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: ivory,
        centerTitle: false,
        toolbarHeight: 68,
        titleTextStyle: _type(ThemeData.dark().textTheme, ivory).titleLarge,
      ),
      fontFamily: 'RegaliaPixel',
      textTheme: _type(ThemeData.dark().textTheme, ivory),
      focusColor: ivory.withValues(alpha: .28),
      hoverColor: secondary.withValues(alpha: .14),
      highlightColor: secondary.withValues(alpha: .18),
      splashFactory: NoSplash.splashFactory,
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 2,
        space: 2,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: _buttonStyle(
          foreground: scheme.onSecondary,
          background: secondary,
          border: ink,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _buttonStyle(
          foreground: ivory,
          background: midnightSurface,
          border: scheme.outline,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: _buttonStyle(
          foreground: secondary,
          background: Colors.transparent,
          border: Colors.transparent,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size.square(48)),
          iconSize: const WidgetStatePropertyAll(24),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.disabled)
                    ? scheme.outlineVariant
                    : ivory,
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.hovered) ||
                        states.contains(WidgetState.focused)
                    ? secondaryContainer
                    : Colors.transparent,
          ),
          shape: const WidgetStatePropertyAll(PixelOrganicBorder.compact()),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: secondary,
        textColor: ivory,
        shape: PixelOrganicBorder(
          side: BorderSide(color: scheme.outlineVariant, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ink,
        contentTextStyle: _type(ThemeData.dark().textTheme, ivory).bodyMedium,
        elevation: 0,
        shape: PixelOrganicBorder(side: BorderSide(color: secondary, width: 3)),
        behavior: SnackBarBehavior.floating,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: ShapeDecoration(
          color: ink,
          shape: PixelOrganicBorder(
            side: BorderSide(color: secondary, width: 2),
          ),
        ),
        textStyle: _type(ThemeData.dark().textTheme, ivory).labelMedium,
        waitDuration: const Duration(milliseconds: 500),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: secondary,
        linearTrackColor: midnightSurfaceHigh,
        circularTrackColor: midnightSurfaceHigh,
        linearMinHeight: 10,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: midnightSurfaceLow,
        border: const OutlineInputBorder(borderRadius: _inputBorderRadius),
        enabledBorder: OutlineInputBorder(
          borderRadius: _inputBorderRadius,
          borderSide: BorderSide(color: scheme.outline, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: _inputBorderRadius,
          borderSide: BorderSide(color: secondary, width: 3),
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

  static ButtonStyle _buttonStyle({
    required Color foreground,
    required Color background,
    required Color border,
  }) => ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    ),
    foregroundColor: WidgetStateProperty.resolveWith(
      (states) =>
          states.contains(WidgetState.disabled)
              ? foreground.withValues(alpha: .38)
              : foreground,
    ),
    backgroundColor: WidgetStateProperty.resolveWith(
      (states) =>
          states.contains(WidgetState.disabled)
              ? background.withValues(alpha: .22)
              : states.contains(WidgetState.pressed)
              ? Color.lerp(background, ink, .22)
              : background,
    ),
    side: WidgetStatePropertyAll(BorderSide(color: border, width: 2)),
    shape: const WidgetStatePropertyAll(PixelOrganicBorder()),
    elevation: const WidgetStatePropertyAll(0),
    textStyle: const WidgetStatePropertyAll(
      TextStyle(
        fontFamily: 'RegaliaPixel',
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: .3,
      ),
    ),
  );

  static const _inputBorderRadius = BorderRadius.only(
    topLeft: Radius.circular(5),
    topRight: Radius.circular(9),
    bottomRight: Radius.circular(6),
    bottomLeft: Radius.circular(8),
  );

  static TextTheme _type(TextTheme base, Color color) => base
      .apply(fontFamily: 'RegaliaPixel', bodyColor: color, displayColor: color)
      .copyWith(
        displayLarge: base.displayLarge?.copyWith(
          fontFamily: 'RegaliaPixel',
          fontWeight: FontWeight.w700,
          height: .95,
          letterSpacing: -.5,
          color: color,
        ),
        displayMedium: base.displayMedium?.copyWith(
          fontFamily: 'RegaliaPixel',
          fontWeight: FontWeight.w700,
          height: 1,
          color: color,
        ),
        displaySmall: base.displaySmall?.copyWith(
          fontFamily: 'RegaliaPixel',
          fontWeight: FontWeight.w700,
          height: 1,
          color: color,
        ),
        headlineLarge: base.headlineLarge?.copyWith(
          fontFamily: 'RegaliaPixel',
          fontWeight: FontWeight.w700,
          height: 1.05,
          color: color,
        ),
        headlineMedium: base.headlineMedium?.copyWith(
          fontFamily: 'RegaliaPixel',
          fontWeight: FontWeight.w700,
          height: 1.05,
          color: color,
        ),
        headlineSmall: base.headlineSmall?.copyWith(
          fontFamily: 'RegaliaPixel',
          fontWeight: FontWeight.w700,
          height: 1.08,
          color: color,
        ),
        titleLarge: base.titleLarge?.copyWith(
          fontFamily: 'RegaliaPixel',
          fontWeight: FontWeight.w700,
          height: 1.1,
          letterSpacing: .2,
          color: color,
        ),
        titleMedium: base.titleMedium?.copyWith(
          fontFamily: 'RegaliaPixel',
          fontWeight: FontWeight.w700,
          height: 1.15,
          letterSpacing: .2,
          color: color,
        ),
        bodyLarge: base.bodyLarge?.copyWith(
          fontFamily: 'RegaliaPixel',
          fontSize: 17,
          height: 1.3,
          letterSpacing: .15,
          color: color,
        ),
        bodyMedium: base.bodyMedium?.copyWith(
          fontFamily: 'RegaliaPixel',
          fontSize: 15,
          height: 1.3,
          letterSpacing: .15,
          color: color,
        ),
        bodySmall: base.bodySmall?.copyWith(
          fontFamily: 'RegaliaPixel',
          fontSize: 13,
          height: 1.28,
          letterSpacing: .2,
          color: color,
        ),
        labelLarge: base.labelLarge?.copyWith(
          fontFamily: 'RegaliaPixel',
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: .3,
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
