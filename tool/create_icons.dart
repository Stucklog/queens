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
    "Created ${outputs.length + 1} Queen's Regalia jeweled-crown icons.",
  );
}

Uint8List _iconPng(int size) {
  final pixels = Uint8List(size * size * 4);
  const midnight = [17, 24, 49, 255];
  const midnightLight = [25, 37, 69, 255];
  const royalShadow = [28, 45, 83, 255];
  const royal = [35, 66, 116, 255];
  const royalLight = [45, 83, 139, 255];
  const ink = [43, 29, 36, 255];
  const goldDeep = [108, 65, 29, 255];
  const goldShadow = [166, 105, 31, 255];
  const gold = [218, 153, 43, 255];
  const goldLight = [255, 213, 91, 255];
  const ivory = [255, 239, 178, 255];
  const crimson = [177, 49, 62, 255];
  const crimsonLight = [231, 83, 83, 255];
  const sapphire = [54, 91, 174, 255];
  const teal = [54, 142, 128, 255];
  const gridSize = 64;

  const crownOutline = <(int, int)>[
    (7, 40),
    (8, 21),
    (18, 29),
    (23, 12),
    (31, 27),
    (32, 5),
    (34, 27),
    (42, 12),
    (47, 29),
    (56, 21),
    (57, 40),
    (55, 53),
    (9, 53),
  ];
  const crownFace = <(int, int)>[
    (10, 39),
    (11, 26),
    (18, 33),
    (23, 18),
    (31, 32),
    (32, 11),
    (34, 32),
    (42, 18),
    (47, 33),
    (53, 26),
    (54, 39),
    (52, 49),
    (12, 49),
  ];
  const leftFacet = <(int, int)>[
    (11, 38),
    (12, 28),
    (18, 35),
    (23, 20),
    (24, 25),
    (20, 38),
  ];
  const rightFacet = <(int, int)>[
    (42, 19),
    (47, 34),
    (52, 28),
    (53, 39),
    (45, 39),
  ];

  void pixel(int x, int y, List<int> color) {
    if (x < 0 || y < 0 || x >= size || y >= size) return;
    final index = (y * size + x) * 4;
    pixels.setRange(index, index + 4, color);
  }

  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final gx = x * gridSize ~/ size;
      final gy = y * gridSize ~/ size;
      var color = midnight;

      final diamondDistance = (gx - 32).abs() + (gy - 32).abs();
      if (diamondDistance <= 30) color = royalShadow;
      if (diamondDistance <= 26) color = royal;
      if (diamondDistance <= 22 && gx <= 32) color = royalLight;
      if ((gx * 11 + gy * 7) % 53 == 0 && diamondDistance > 30) {
        color = midnightLight;
      }

      bool inRect(int left, int top, int width, int height) =>
          gx >= left && gx < left + width && gy >= top && gy < top + height;

      if (_insidePolygon(gx, gy, crownOutline)) color = ink;
      if (_insidePolygon(gx, gy, crownFace)) color = gold;
      if (_insidePolygon(gx, gy, leftFacet)) color = goldLight;
      if (_insidePolygon(gx, gy, rightFacet)) color = goldShadow;

      // The broad band keeps the crown readable at 16–20 px while providing
      // enough layers and gemstones to match the in-game 16-bit rendering.
      if (inRect(8, 38, 49, 15)) color = ink;
      if (inRect(11, 38, 43, 11)) color = goldShadow;
      if (inRect(12, 39, 41, 8)) color = gold;
      if (inRect(14, 39, 28, 2)) color = goldLight;
      if (inRect(12, 49, 41, 2)) color = goldDeep;
      if (inRect(14, 51, 37, 2)) color = ink;

      if (inRect(18, 42, 5, 4)) color = crimson;
      if (inRect(19, 42, 3, 1)) color = crimsonLight;
      if (inRect(30, 41, 5, 5)) color = sapphire;
      if (inRect(31, 41, 3, 2)) color = ivory;
      if (inRect(42, 42, 5, 4)) color = teal;
      if (inRect(43, 42, 3, 1)) color = ivory;

      // Bright tip clusters keep the five-point silhouette crisp when the
      // artwork is downsampled to favicons and notification icons.
      if (inRect(7, 21, 3, 3) ||
          inRect(22, 13, 3, 3) ||
          inRect(31, 6, 3, 3) ||
          inRect(41, 13, 3, 3) ||
          inRect(55, 21, 3, 3)) {
        color = goldLight;
      }
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

bool _insidePolygon(int x, int y, List<(int, int)> points) {
  var inside = false;
  for (
    var current = 0, previous = points.length - 1;
    current < points.length;
    previous = current++
  ) {
    final currentPoint = points[current];
    final previousPoint = points[previous];
    final crosses =
        (currentPoint.$2 > y) != (previousPoint.$2 > y) &&
        x <
            (previousPoint.$1 - currentPoint.$1) *
                    (y - currentPoint.$2) /
                    (previousPoint.$2 - currentPoint.$2) +
                currentPoint.$1;
    if (crosses) inside = !inside;
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
