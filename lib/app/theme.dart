import 'dart:math' as math;

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
      _theme(palette ?? const JourneyPalette(primary: ivory, secondary: gold));

  static ThemeData forChapter(JourneyChapter chapter) =>
      midnight(chapter.palette);

  /// Keeps a story-authored accent recognizable when it is shown on a shared
  /// surface whose theme may belong to a different arc.
  static Color readableAccent({
    required Color preferred,
    required Color background,
    double minimumContrast = 4.5,
  }) {
    assert(minimumContrast >= 1 && minimumContrast <= 21);
    if (_contrastRatio(preferred, background) >= minimumContrast) {
      return preferred;
    }

    final target =
        _contrastRatio(Colors.black, background) >=
                _contrastRatio(Colors.white, background)
            ? Colors.black
            : Colors.white;
    for (var step = 1; step <= 20; step++) {
      final candidate = Color.lerp(preferred, target, step / 20)!;
      if (_contrastRatio(candidate, background) >= minimumContrast) {
        return candidate;
      }
    }
    return target;
  }

  static ThemeData _theme(JourneyPalette palette) {
    final theme = palette.theme;
    final secondary = palette.secondary;
    final secondaryContainer = Color.lerp(theme.surface, secondary, .24)!;
    final baseTheme =
        theme.brightness == Brightness.dark
            ? ThemeData.dark()
            : ThemeData.light();
    final scheme = ColorScheme.fromSeed(
      seedColor: secondary,
      brightness: theme.brightness,
    ).copyWith(
      surface: theme.surface,
      onSurface: theme.foreground,
      surfaceDim: theme.background,
      surfaceBright: theme.surfaceHigh,
      surfaceContainerLowest: theme.background,
      surfaceContainerLow: theme.surfaceLow,
      surfaceContainer: theme.surface,
      surfaceContainerHigh: theme.surfaceContainerHigh,
      surfaceContainerHighest: theme.surfaceHigh,
      onSurfaceVariant: theme.mutedForeground,
      outline: theme.outline,
      outlineVariant: theme.outlineVariant,
      primary: theme.foreground,
      onPrimary: theme.background,
      primaryContainer: theme.surfaceHigh,
      onPrimaryContainer: theme.foreground,
      secondary: secondary,
      onSecondary: _foregroundFor(
        secondary,
        dark: theme.background,
        light: theme.foreground,
      ),
      secondaryContainer: secondaryContainer,
      onSecondaryContainer: theme.foreground,
      error: theme.danger,
      onError: _foregroundFor(
        theme.danger,
        dark: theme.ink,
        light: theme.foreground,
      ),
      inverseSurface: theme.foreground,
      onInverseSurface: theme.background,
      inversePrimary: secondary,
      shadow: theme.ink,
      scrim: theme.ink,
      surfaceTint: Colors.transparent,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: theme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: theme.background,
      canvasColor: theme.background,
      cardTheme: CardThemeData(
        color: theme.surface,
        elevation: 0,
        shape: PixelOrganicBorder(
          side: BorderSide(color: scheme.outline, width: 2),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: theme.surface,
        elevation: 0,
        shape: PixelOrganicBorder(side: BorderSide(color: secondary, width: 3)),
        titleTextStyle:
            _type(baseTheme.textTheme, theme.foreground).headlineSmall,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: theme.foreground,
        centerTitle: false,
        toolbarHeight: 68,
        titleTextStyle: _type(baseTheme.textTheme, theme.foreground).titleLarge,
      ),
      fontFamily: 'RegaliaPixel',
      textTheme: _type(baseTheme.textTheme, theme.foreground),
      focusColor: theme.foreground.withValues(alpha: .28),
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
          border: theme.ink,
          pressedInk: theme.ink,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _buttonStyle(
          foreground: theme.foreground,
          background: theme.surface,
          border: scheme.outline,
          pressedInk: theme.ink,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: _buttonStyle(
          foreground: secondary,
          background: Colors.transparent,
          border: Colors.transparent,
          pressedInk: theme.ink,
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
                    : theme.foreground,
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
        textColor: theme.foreground,
        shape: PixelOrganicBorder(
          side: BorderSide(color: scheme.outlineVariant, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: theme.ink,
        contentTextStyle:
            _type(baseTheme.textTheme, theme.foreground).bodyMedium,
        elevation: 0,
        shape: PixelOrganicBorder(side: BorderSide(color: secondary, width: 3)),
        behavior: SnackBarBehavior.floating,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: ShapeDecoration(
          color: theme.ink,
          shape: PixelOrganicBorder(
            side: BorderSide(color: secondary, width: 2),
          ),
        ),
        textStyle: _type(baseTheme.textTheme, theme.foreground).labelMedium,
        waitDuration: const Duration(milliseconds: 500),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: secondary,
        linearTrackColor: theme.surfaceHigh,
        circularTrackColor: theme.surfaceHigh,
        linearMinHeight: 10,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: theme.surfaceLow,
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

  static Color _foregroundFor(
    Color background, {
    required Color dark,
    required Color light,
  }) {
    final luminance = background.computeLuminance();
    final darkLuminance = dark.computeLuminance();
    final lightLuminance = light.computeLuminance();
    final darkContrast =
        (math.max(luminance, darkLuminance) + .05) /
        (math.min(luminance, darkLuminance) + .05);
    final lightContrast =
        (math.max(luminance, lightLuminance) + .05) /
        (math.min(luminance, lightLuminance) + .05);
    return darkContrast >= lightContrast ? dark : light;
  }

  static double _contrastRatio(Color first, Color second) {
    final firstLuminance = first.computeLuminance();
    final secondLuminance = second.computeLuminance();
    return (math.max(firstLuminance, secondLuminance) + .05) /
        (math.min(firstLuminance, secondLuminance) + .05);
  }

  static ButtonStyle _buttonStyle({
    required Color foreground,
    required Color background,
    required Color border,
    required Color pressedInk,
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
              ? Color.lerp(background, pressedInk, .22)
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
