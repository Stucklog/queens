import 'dart:io';

import 'package:image/image.dart' as image;

const crownIconMasterPath = 'tool/assets/crown_app_icon_master.png';
const windowsCrownIconPath = 'windows/runner/resources/app_icon.ico';
final crownIconOutputs = <String, int>{
  'web/favicon.png': 32,
  'web/icons/Icon-192.png': 192,
  'web/icons/Icon-512.png': 512,
  'web/icons/Icon-maskable-192.png': 192,
  'web/icons/Icon-maskable-512.png': 512,
  'android/app/src/main/res/mipmap-mdpi/ic_launcher.png': 48,
  'android/app/src/main/res/mipmap-hdpi/ic_launcher.png': 72,
  'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png': 96,
  'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png': 144,
  'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png': 192,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png': 20,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png': 40,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png': 60,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png': 29,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png': 58,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png': 87,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png': 40,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png': 80,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png': 120,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png': 120,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png': 180,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png': 76,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png': 152,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png':
      167,
  'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png':
      1024,
  for (final size in [16, 32, 64, 128, 256, 512, 1024])
    'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_$size.png': size,
};

Future<void> main() async {
  final masterBytes = await File(crownIconMasterPath).readAsBytes();
  final master = image.decodePng(masterBytes);
  if (master == null) {
    throw StateError('Could not decode $crownIconMasterPath.');
  }
  if (master.width != master.height) {
    throw StateError('The crown icon master must be square.');
  }
  _requireSymmetry(master, crownIconMasterPath);

  for (final entry in crownIconOutputs.entries) {
    var icon = _resizeSymmetrically(
      master,
      entry.value,
      maskable: entry.key.contains('Icon-maskable-'),
    );
    if (entry.key.startsWith('ios/')) {
      icon = icon.convert(numChannels: 3);
      _requireSymmetry(icon, '${entry.value} px iOS icon');
    }
    await File(entry.key).writeAsBytes(image.encodePng(icon), flush: true);
  }

  final windowsSizes = [16, 24, 32, 48, 64, 128, 256];
  final windowsIcon = _resizeSymmetrically(master, windowsSizes.first);
  for (final size in windowsSizes.skip(1)) {
    windowsIcon.addFrame(_resizeSymmetrically(master, size));
  }
  await File(
    windowsCrownIconPath,
  ).writeAsBytes(image.encodeIco(windowsIcon), flush: true);

  stdout.writeln(
    'Created ${crownIconOutputs.length + 1} symmetrical Dawn Regalia icons '
    'from $crownIconMasterPath.',
  );
}

image.Image _resizeSymmetrically(
  image.Image master,
  int size, {
  bool maskable = false,
}) {
  var contentSize = maskable ? (size * .74).round() : size;
  if (contentSize.isEven != size.isEven) contentSize--;
  final pixelGridSize = switch (contentSize) {
    <= 64 => 32,
    <= 192 => 64,
    _ => 128,
  };
  final pixelGrid = image.copyResize(
    master,
    width: pixelGridSize,
    height: pixelGridSize,
    interpolation: image.Interpolation.average,
  );
  final resizedContent = image.copyResize(
    pixelGrid,
    width: contentSize,
    height: contentSize,
    interpolation: image.Interpolation.nearest,
  );
  final resized =
      maskable
          ? image.Image(width: size, height: size, numChannels: 4)
          : resizedContent;
  if (maskable) {
    final background = master.getPixel(0, 0);
    resized.clear(
      image.ColorRgba8(
        background.r.toInt(),
        background.g.toInt(),
        background.b.toInt(),
        255,
      ),
    );
    image.compositeImage(
      resized,
      resizedContent,
      center: true,
      blend: image.BlendMode.direct,
    );
  }
  for (var y = 0; y < resized.height; y++) {
    for (var x = 0; x < resized.width ~/ 2; x++) {
      resized.setPixel(resized.width - 1 - x, y, resized.getPixel(x, y));
    }
  }
  _requireSymmetry(resized, '$size px icon');
  return resized;
}

void _requireSymmetry(image.Image icon, String label) {
  for (var y = 0; y < icon.height; y++) {
    for (var x = 0; x < icon.width ~/ 2; x++) {
      final left = icon.getPixel(x, y);
      final right = icon.getPixel(icon.width - 1 - x, y);
      if (left.r != right.r ||
          left.g != right.g ||
          left.b != right.b ||
          left.a != right.a) {
        throw StateError('$label is not horizontally symmetrical at ($x, $y).');
      }
    }
  }
}
