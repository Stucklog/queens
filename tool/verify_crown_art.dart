import 'dart:collection';
import 'dart:io';

import 'package:image/image.dart' as image;

import 'create_icons.dart' as icons;

void main() {
  final master = _decodePng(icons.crownIconMasterPath);
  if (master.width < 1024 || master.height < 1024) {
    throw StateError('The crown master must be at least 1024×1024.');
  }
  _requireSymmetry(master, icons.crownIconMasterPath);

  for (final entry in icons.crownIconOutputs.entries) {
    final icon = _decodePng(entry.key);
    if (icon.width != entry.value || icon.height != entry.value) {
      throw StateError(
        '${entry.key} is ${icon.width}×${icon.height}; expected '
        '${entry.value}×${entry.value}.',
      );
    }
    _requireSymmetry(icon, entry.key);
    if (entry.key.contains('Icon-maskable-')) {
      _requireMaskSafeCrown(icon, entry.key);
    }
  }

  final windowsBytes = File(icons.windowsCrownIconPath).readAsBytesSync();
  final windowsIcon = image.decodeIco(windowsBytes);
  if (windowsIcon == null ||
      windowsIcon.width != 256 ||
      windowsIcon.height != 256) {
    throw StateError('The Windows crown icon must decode at 256×256.');
  }
  _requireSymmetry(windowsIcon, icons.windowsCrownIconPath);

  stdout.writeln(
    'Verified the crown master, ${icons.crownIconOutputs.length} PNG icons, '
    'the Windows ICO, exact bilateral symmetry, and the PWA mask-safe area.',
  );
}

image.Image _decodePng(String path) {
  final decoded = image.decodePng(File(path).readAsBytesSync());
  if (decoded == null) throw StateError('Could not decode $path.');
  return decoded;
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

void _requireMaskSafeCrown(image.Image icon, String label) {
  final width = icon.width;
  final height = icon.height;
  final material = List<bool>.filled(width * height, false);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final pixel = icon.getPixel(x, y);
      final isGoldOrIvory =
          pixel.r > 105 &&
          pixel.g > 52 &&
          pixel.r > pixel.b * 1.12 &&
          pixel.g > pixel.b * .68;
      material[y * width + x] = isGoldOrIvory;
    }
  }

  final visited = List<bool>.filled(material.length, false);
  var largest = <int>[];
  for (var index = 0; index < material.length; index++) {
    if (!material[index] || visited[index]) continue;
    final component = <int>[];
    final queue = Queue<int>()..add(index);
    visited[index] = true;
    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      component.add(current);
      final x = current % width;
      final y = current ~/ width;
      for (final neighbor in [
        if (x > 0) current - 1,
        if (x + 1 < width) current + 1,
        if (y > 0) current - width,
        if (y + 1 < height) current + width,
      ]) {
        if (material[neighbor] && !visited[neighbor]) {
          visited[neighbor] = true;
          queue.add(neighbor);
        }
      }
    }
    if (component.length > largest.length) largest = component;
  }

  if (largest.length < width * height * .08) {
    throw StateError('$label does not contain a substantial crown silhouette.');
  }
  final centerX = (width - 1) / 2;
  final centerY = (height - 1) / 2;
  final safeRadius = width * .4 + 1;
  for (final index in largest) {
    final x = index % width;
    final y = index ~/ width;
    final dx = x - centerX;
    final dy = y - centerY;
    if (dx * dx + dy * dy > safeRadius * safeRadius) {
      throw StateError(
        '$label places essential crown artwork outside the mask-safe circle.',
      );
    }
  }
}
