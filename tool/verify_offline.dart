import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> arguments) async {
  final failures = <String>[];
  final pubspec = await File('pubspec.yaml').readAsString();
  final dependencies = _directDependencies(pubspec);
  const allowedDependencies = {
    'flutter',
    'cupertino_icons',
    'shared_preferences',
    'url_launcher',
  };
  final unexpected = dependencies.difference(allowedDependencies);
  if (unexpected.isNotEmpty) {
    failures.add('network review required for dependencies: $unexpected');
  }

  final networkPatterns = <RegExp>[
    RegExp(r'''import\s+['"]dart:io['"]'''),
    RegExp(r"package:(http|dio|web_socket_channel|socket_io_client)"),
    RegExp(r'\b(HttpClient|WebSocket|Socket\.connect)\b'),
    RegExp(r'''Uri\.parse\(\s*['"]https?://'''),
  ];
  final approvedExternalUri = RegExp(
    r'''Uri\.https\(\s*['"]buymeacoffee\.com['"]\s*,\s*['"]/philosophyforge['"]\s*,?\s*\)''',
    multiLine: true,
  );
  for (final file in Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))) {
    final source = await file.readAsString();
    final externalUriCount = RegExp(r'Uri\.https\(').allMatches(source).length;
    final approvedExternalUriCount =
        approvedExternalUri.allMatches(source).length;
    if (externalUriCount != approvedExternalUriCount) {
      failures.add('${file.path} contains an unapproved external URL');
    }
    for (final pattern in networkPatterns) {
      if (pattern.hasMatch(source)) {
        failures.add(
          '${file.path} contains runtime network capability: $pattern',
        );
      }
    }
  }

  final androidRelease =
      await File('android/app/src/main/AndroidManifest.xml').readAsString();
  if (androidRelease.contains('android.permission.INTERNET')) {
    failures.add('Android release manifest requests INTERNET');
  }
  final macRelease =
      await File('macos/Runner/Release.entitlements').readAsString();
  if (macRelease.contains('com.apple.security.network')) {
    failures.add('macOS release entitlements grant network access');
  }

  final manifest =
      jsonDecode(await File('web/manifest.json').readAsString())
          as Map<String, Object?>;
  if (manifest['display'] != 'standalone' || manifest['start_url'] != '.') {
    failures.add('web manifest is not installable standalone metadata');
  }
  final icons = manifest['icons'] as List<Object?>? ?? const [];
  if (icons.length < 4) failures.add('web manifest is missing PWA icons');
  if (!pubspec.contains('assets/puzzles/catalog.json')) {
    failures.add('catalog is not declared as a bundled Flutter asset');
  }
  if (!pubspec.contains('assets/puzzles/tutorial.json')) {
    failures.add('tutorial is not declared as a bundled Flutter asset');
  }
  if (!pubspec.contains('assets/content/') ||
      !File('assets/content/manifest.json').existsSync() ||
      !File('assets/content/arcs/origin/arc.json').existsSync()) {
    failures.add('content manifest or origin arc metadata is not bundled');
  }
  if (!pubspec.contains('assets/art/') ||
      !File('assets/art/knight_animations.png').existsSync()) {
    failures.add('knight animation atlas is not bundled as an app asset');
  }

  final buildIndex = arguments.indexOf('--web-build');
  if (buildIndex >= 0) {
    if (buildIndex + 1 >= arguments.length) {
      failures.add('--web-build requires a directory');
    } else {
      final root = Directory(arguments[buildIndex + 1]);
      final worker = File('${root.path}/flutter_service_worker.js');
      if (!worker.existsSync()) {
        failures.add('${root.path} has no generated service worker');
      } else {
        final source = await worker.readAsString();
        for (final asset in const [
          'main.dart.js',
          'assets/assets/content/manifest.json',
          'assets/assets/content/arcs/origin/arc.json',
          'assets/assets/puzzles/catalog.json',
          'assets/assets/puzzles/tutorial.json',
          'assets/assets/fonts/PixelifySans-Variable.ttf',
          'assets/assets/fonts/PixelifySans_LICENSE.txt',
          'assets/assets/art/knight_animations.png',
          'icons/Icon-512.png',
        ]) {
          if (!source.contains(asset)) {
            failures.add('service worker does not cache $asset');
          }
        }
      }
    }
  }

  if (failures.isNotEmpty) {
    for (final failure in failures) {
      stderr.writeln('OFFLINE CHECK FAILED: $failure');
    }
    exitCode = 1;
    return;
  }
  stdout.writeln(
    buildIndex >= 0
        ? 'Verified release network isolation and cached PWA assets.'
        : 'Verified release network isolation and installable PWA metadata.',
  );
}

Set<String> _directDependencies(String pubspec) {
  final dependencies = <String>{};
  var inside = false;
  for (final line in const LineSplitter().convert(pubspec)) {
    if (line == 'dependencies:') {
      inside = true;
      continue;
    }
    if (line == 'dev_dependencies:') break;
    if (!inside) continue;
    final match = RegExp(r'^  ([a-zA-Z0-9_]+):').firstMatch(line);
    if (match != null) dependencies.add(match.group(1)!);
  }
  return dependencies;
}
