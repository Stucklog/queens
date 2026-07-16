import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

Future<void> main() async {
  final outputs = <String, int>{
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
      'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_$size.png':
          size,
  };
  for (final entry in outputs.entries) {
    await File(entry.key).writeAsBytes(_iconPng(entry.value), flush: true);
  }
  final windowsPng = _iconPng(256);
  await File(
    'windows/runner/resources/app_icon.ico',
  ).writeAsBytes(_ico(windowsPng), flush: true);
  stdout.writeln(
    "Created ${outputs.length + 1} Queen's Regalia crown-and-grid icons.",
  );
}

Uint8List _iconPng(int size) {
  final pixels = Uint8List(size * size * 4);
  const ivory = [248, 241, 227, 255];
  const ivoryShade = [222, 211, 191, 255];
  const ink = [36, 32, 29, 255];
  const inkLight = [70, 62, 55, 255];
  const gold = [182, 128, 50, 255];
  const goldShadow = [120, 78, 35, 255];
  const goldLight = [240, 190, 78, 255];
  const jewel = [61, 128, 120, 255];
  const gridSize = 48;

  void pixel(int x, int y, List<int> color) {
    if (x < 0 || y < 0 || x >= size || y >= size) return;
    final index = (y * size + x) * 4;
    pixels.setRange(index, index + 4, color);
  }

  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final gx = x * gridSize ~/ size;
      final gy = y * gridSize ~/ size;
      final edgeX = gx < gridSize - 1 - gx ? gx : gridSize - 1 - gx;
      final edgeY = gy < gridSize - 1 - gy ? gy : gridSize - 1 - gy;
      final clippedCorner = edgeX < 5 && edgeY < 5 && edgeX + edgeY < 5;
      var color = clippedCorner ? ink : ivory;

      final onGrid =
          ((gx == 15 || gx == 16 || gx == 31 || gx == 32) &&
              gy >= 6 &&
              gy <= 41) ||
          ((gy == 15 || gy == 16 || gy == 31 || gy == 32) &&
              gx >= 6 &&
              gx <= 41);
      if (onGrid) color = ink;
      final gridHighlight =
          ((gx == 17 || gx == 33) && gy >= 6 && gy <= 41) ||
          ((gy == 17 || gy == 33) && gx >= 6 && gx <= 41);
      if (gridHighlight) color = inkLight;

      bool inRect(int left, int top, int width, int height) =>
          gx >= left && gx < left + width && gy >= top && gy < top + height;
      final crownShadow =
          inRect(8, 14, 7, 18) ||
          inRect(21, 8, 8, 24) ||
          inRect(35, 14, 6, 18) ||
          inRect(10, 25, 31, 12) ||
          inRect(13, 40, 26, 5);
      if (crownShadow) color = goldShadow;
      final onCrown =
          inRect(10, 14, 5, 16) ||
          inRect(23, 8, 6, 22) ||
          inRect(36, 14, 5, 16) ||
          inRect(11, 25, 30, 10) ||
          inRect(14, 39, 25, 4);
      if (onCrown) color = gold;
      final crownHighlight =
          inRect(11, 14, 2, 12) ||
          inRect(24, 8, 2, 17) ||
          inRect(37, 14, 2, 12) ||
          inRect(13, 26, 19, 2) ||
          inRect(16, 39, 16, 1);
      if (crownHighlight) color = goldLight;
      if (inRect(22, 30, 7, 4)) color = jewel;
      if (inRect(23, 30, 4, 1)) color = ivoryShade;
      pixel(x, y, color);
    }
  }

  final raw = BytesBuilder();
  for (var row = 0; row < size; row++) {
    raw.addByte(0);
    raw.add(pixels.sublist(row * size * 4, (row + 1) * size * 4));
  }
  final png = BytesBuilder()..add(const [137, 80, 78, 71, 13, 10, 26, 10]);
  png.add(
    _chunk('IHDR', _uint32(size) + _uint32(size) + const [8, 6, 0, 0, 0]),
  );
  png.add(_chunk('IDAT', ZLibEncoder().convert(raw.takeBytes())));
  png.add(_chunk('IEND', const []));
  return png.takeBytes();
}

List<int> _chunk(String type, List<int> data) {
  final name = ascii.encode(type);
  return _uint32(data.length) +
      name +
      data +
      _uint32(_crc32([...name, ...data]));
}

List<int> _uint32(int value) => [
  (value >> 24) & 255,
  (value >> 16) & 255,
  (value >> 8) & 255,
  value & 255,
];

int _crc32(List<int> data) {
  var crc = 0xffffffff;
  for (final byte in data) {
    crc ^= byte;
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc & 1) != 0 ? 0xedb88320 ^ (crc >> 1) : crc >> 1;
    }
  }
  return (crc ^ 0xffffffff) & 0xffffffff;
}

Uint8List _ico(Uint8List png) {
  final header =
      ByteData(22)
        ..setUint16(0, 0, Endian.little)
        ..setUint16(2, 1, Endian.little)
        ..setUint16(4, 1, Endian.little)
        ..setUint8(6, 0)
        ..setUint8(7, 0)
        ..setUint8(8, 0)
        ..setUint8(9, 0)
        ..setUint16(10, 1, Endian.little)
        ..setUint16(12, 32, Endian.little)
        ..setUint32(14, png.length, Endian.little)
        ..setUint32(18, 22, Endian.little);
  return Uint8List.fromList([...header.buffer.asUint8List(), ...png]);
}
