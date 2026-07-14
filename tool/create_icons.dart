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
  stdout.writeln('Created ${outputs.length + 1} Regalia crown-and-grid icons.');
}

Uint8List _iconPng(int size) {
  final pixels = Uint8List(size * size * 4);
  const ivory = [248, 241, 227, 255];
  const ink = [36, 32, 29, 255];
  const gold = [182, 128, 50, 255];

  void pixel(int x, int y, List<int> color) {
    if (x < 0 || y < 0 || x >= size || y >= size) return;
    final index = (y * size + x) * 4;
    pixels.setRange(index, index + 4, color);
  }

  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final radius = size * .19;
      final dx =
          x < radius
              ? radius - x
              : x > size - radius
              ? x - (size - radius)
              : 0;
      final dy =
          y < radius
              ? radius - y
              : y > size - radius
              ? y - (size - radius)
              : 0;
      pixel(x, y, dx * dx + dy * dy > radius * radius ? ink : ivory);
    }
  }

  final line = (size * .035).ceil();
  for (final fraction in [.32, .68]) {
    final center = (size * fraction).round();
    for (var offset = -line ~/ 2; offset <= line ~/ 2; offset++) {
      for (
        var axis = (size * .12).round();
        axis < (size * .88).round();
        axis++
      ) {
        pixel(center + offset, axis, ink);
        pixel(axis, center + offset, ink);
      }
    }
  }

  final crown = <(double, double)>[
    (.18, .39),
    (.34, .57),
    (.50, .24),
    (.66, .57),
    (.82, .39),
    (.74, .73),
    (.26, .73),
  ];
  for (var y = (size * .2).floor(); y <= (size * .78).ceil(); y++) {
    for (var x = (size * .14).floor(); x <= (size * .86).ceil(); x++) {
      if (_inside(x / size, y / size, crown)) pixel(x, y, gold);
    }
  }
  for (var y = (size * .77).floor(); y <= (size * .84).ceil(); y++) {
    for (var x = (size * .24).floor(); x <= (size * .76).ceil(); x++) {
      pixel(x, y, gold);
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

bool _inside(double x, double y, List<(double, double)> polygon) {
  var inside = false;
  for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    final a = polygon[i];
    final b = polygon[j];
    if ((a.$2 > y) != (b.$2 > y) &&
        x < (b.$1 - a.$1) * (y - a.$2) / (b.$2 - a.$2) + a.$1) {
      inside = !inside;
    }
  }
  return inside;
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
