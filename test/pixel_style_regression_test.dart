import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/app/theme.dart';

void main() {
  test('production Dart uses the shared pixel icon language', () {
    final materialIconReferences =
        Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))
            .where(
              (file) => RegExp(r'\bIcons\.').hasMatch(file.readAsStringSync()),
            )
            .map((file) => file.path)
            .toList();

    expect(
      materialIconReferences,
      isEmpty,
      reason: 'Material glyphs bypass the shared pixel icon vocabulary.',
    );
  });

  test('midnight theme and bundled font use RegaliaPixel', () {
    final theme = RegaliaTheme.midnight();
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(theme.textTheme.bodyMedium?.fontFamily, 'RegaliaPixel');
    expect(theme.textTheme.displayLarge?.fontFamily, 'RegaliaPixel');
    expect(pubspec, contains('family: RegaliaPixel'));
    expect(pubspec, contains('assets/fonts/PixelifySans-Variable.ttf'));
    expect(File('assets/fonts/PixelifySans-Variable.ttf').existsSync(), isTrue);
  });
}
