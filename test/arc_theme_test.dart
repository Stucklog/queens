import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/app/arc_theme.dart';

void main() {
  test('arc theme accepts a complete light color scheme', () {
    final theme = ArcThemeColors.fromJson({
      'brightness': 'light',
      'backgroundColor': '#f4ead7',
      'surfaceColor': '#fffaf0',
      'surfaceLowColor': '#ead9bb',
      'surfaceContainerHighColor': '#e2ccaa',
      'surfaceHighColor': '#d7bd91',
      'foregroundColor': '#2b2118',
      'mutedForegroundColor': '#655848',
      'outlineColor': '#75634e',
      'outlineVariantColor': '#bba88c',
      'inkColor': '#17110c',
      'dangerColor': '#a22631',
    });

    expect(theme.brightness, Brightness.light);
    expect(theme.background, const Color(0xfff4ead7));
    expect(theme.surface, const Color(0xfffffaf0));
    expect(theme.surfaceContainerHigh, const Color(0xffe2ccaa));
    expect(theme.foreground, const Color(0xff2b2118));
    expect(theme.danger, const Color(0xffa22631));
  });

  test('omitted theme remains the established midnight scheme', () {
    expect(ArcThemeColors.fromJson(null), same(ArcThemeColors.midnight));
  });

  test('invalid theme colors fail during package loading', () {
    expect(
      () => ArcThemeColors.fromJson({'backgroundColor': 'navy'}),
      throwsFormatException,
    );
  });
}
