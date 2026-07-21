import 'package:flutter/material.dart';

/// Arc-wide UI colors. Chapter palettes can still choose their own landscape
/// and combat accents, while these values control every shared surface around
/// them (scaffolds, panels, text, outlines, buttons, dialogs, and inputs).
@immutable
class ArcThemeColors {
  const ArcThemeColors({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceLow,
    required this.surfaceContainerHigh,
    required this.surfaceHigh,
    required this.foreground,
    required this.mutedForeground,
    required this.outline,
    required this.outlineVariant,
    required this.ink,
    required this.danger,
  });

  static const midnight = ArcThemeColors(
    brightness: Brightness.dark,
    background: Color(0xff151d3b),
    surface: Color(0xff253052),
    surfaceLow: Color(0xff1b2444),
    surfaceContainerHigh: Color(0xff2a3659),
    surfaceHigh: Color(0xff303c60),
    foreground: Color(0xfffff3dc),
    mutedForeground: Color(0xffd3d7e7),
    outline: Color(0xff919cbd),
    outlineVariant: Color(0xff4b587c),
    ink: Color(0xff080d20),
    danger: Color(0xfff06b6b),
  );

  final Brightness brightness;
  final Color background;
  final Color surface;
  final Color surfaceLow;
  final Color surfaceContainerHigh;
  final Color surfaceHigh;
  final Color foreground;
  final Color mutedForeground;
  final Color outline;
  final Color outlineVariant;
  final Color ink;
  final Color danger;

  /// Expands the compact palette kept in the lightweight storefront manifest
  /// into a complete accessible UI scheme without loading the arc package.
  factory ArcThemeColors.fromStorefront({
    required Color background,
    required Color surface,
  }) {
    final brightness = ThemeData.estimateBrightnessForColor(background);
    final foreground =
        brightness == Brightness.dark ? const Color(0xfffffff4) : Colors.black;
    final ink =
        brightness == Brightness.dark ? const Color(0xff080808) : foreground;
    return ArcThemeColors(
      brightness: brightness,
      background: background,
      surface: surface,
      surfaceLow: Color.lerp(background, surface, .45)!,
      surfaceContainerHigh: Color.lerp(surface, foreground, .08)!,
      surfaceHigh: Color.lerp(surface, foreground, .14)!,
      foreground: foreground,
      mutedForeground: Color.lerp(foreground, background, .24)!,
      outline: Color.lerp(foreground, background, .45)!,
      outlineVariant: Color.lerp(foreground, background, .7)!,
      ink: ink,
      danger: const Color(0xffd8404f),
    );
  }

  factory ArcThemeColors.fromJson(Object? value) {
    return ArcThemeColors.mergeFromJson(value, base: midnight);
  }

  /// Applies a partial chapter/storefront override to an inherited arc theme.
  factory ArcThemeColors.mergeFromJson(
    Object? value, {
    required ArcThemeColors base,
  }) {
    if (value == null) return base;
    if (value is! Map<String, Object?>) {
      throw const FormatException('theme must be an object');
    }
    final brightness = switch (value['brightness']) {
      null => base.brightness,
      'dark' => Brightness.dark,
      'light' => Brightness.light,
      final invalid =>
        throw FormatException('Unknown story theme brightness $invalid'),
    };
    return ArcThemeColors(
      brightness: brightness,
      background: _color(value, 'backgroundColor', base.background),
      surface: _color(value, 'surfaceColor', base.surface),
      surfaceLow: _color(value, 'surfaceLowColor', base.surfaceLow),
      surfaceContainerHigh: _color(
        value,
        'surfaceContainerHighColor',
        base.surfaceContainerHigh,
      ),
      surfaceHigh: _color(value, 'surfaceHighColor', base.surfaceHigh),
      foreground: _color(value, 'foregroundColor', base.foreground),
      mutedForeground: _color(
        value,
        'mutedForegroundColor',
        base.mutedForeground,
      ),
      outline: _color(value, 'outlineColor', base.outline),
      outlineVariant: _color(value, 'outlineVariantColor', base.outlineVariant),
      ink: _color(value, 'inkColor', base.ink),
      danger: _color(value, 'dangerColor', base.danger),
    );
  }

  static Color _color(Map<String, Object?> json, String key, Color fallback) {
    final source = json[key];
    if (source == null) return fallback;
    if (source is! String || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(source)) {
      throw FormatException('Invalid story theme $key color $source');
    }
    return Color(int.parse('ff${source.substring(1)}', radix: 16));
  }
}
