import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> arguments) async {
  final failures = <String>[];
  final paidSource = arguments.contains('--paid-source');
  final pubspec = await File('pubspec.yaml').readAsString();
  final flutterAssets = _flutterAssetDeclarations(pubspec);
  if (RegExp(r'^  default-flavor:', multiLine: true).hasMatch(pubspec)) {
    failures.add(
      'pubspec.yaml must not set default-flavor; unflavored web builds are the '
      'secure baseline',
    );
  }
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

  final contentManifestFile = File('assets/content/manifest.json');
  String? contentManifestSource;
  var contentPolicy = const _ContentOfflinePolicy.empty();
  if (!contentManifestFile.existsSync()) {
    failures.add('content manifest is missing');
  } else {
    contentManifestSource = await contentManifestFile.readAsString();
    try {
      final decoded = jsonDecode(contentManifestSource);
      if (decoded is! Map<String, Object?>) {
        throw const FormatException('manifest root must be an object');
      }
      contentPolicy = _contentOfflinePolicy(
        decoded,
        failures: failures,
        flutterAssets: flutterAssets,
        paidSource: paidSource,
      );
    } on Object catch (error) {
      failures.add('invalid content manifest: $error');
    }
  }

  final originArcFile = File('assets/content/arcs/origin/arc.json');
  final originArc =
      jsonDecode(await originArcFile.readAsString()) as Map<String, Object?>;
  final combatAssets = <String>{};
  for (final chapterValue in originArc['chapters']! as List<Object?>) {
    final chapter = chapterValue! as Map<String, Object?>;
    final boss = chapter['boss']! as Map<String, Object?>;
    combatAssets.add(boss['spriteAsset']! as String);
    for (final encounterValue in chapter['encounters']! as List<Object?>) {
      final encounter = encounterValue! as Map<String, Object?>;
      combatAssets.add(encounter['spriteAsset']! as String);
    }
  }
  if (!pubspec.contains('assets/puzzles/catalog.json')) {
    failures.add('catalog is not declared as a bundled Flutter asset');
  }
  if (!pubspec.contains('assets/puzzles/tutorial.json')) {
    failures.add('tutorial is not declared as a bundled Flutter asset');
  }
  if (!pubspec.contains('assets/content/') || !originArcFile.existsSync()) {
    failures.add('content manifest or origin arc metadata is not bundled');
  }
  if (!pubspec.contains('assets/art/') ||
      !File('assets/art/knight_animations.png').existsSync()) {
    failures.add('knight animation atlas is not bundled as an app asset');
  }
  if (!pubspec.contains('assets/art/combat/') ||
      !pubspec.contains('assets/art/combat/opponents/') ||
      !File('assets/art/combat/knight_finishers.png').existsSync()) {
    failures.add('combat animation atlases are not bundled as app assets');
  }
  for (final asset in combatAssets) {
    if (!File(asset).existsSync()) {
      failures.add('combat sprite atlas is missing: $asset');
    }
  }

  final buildIndex = arguments.indexOf('--web-build');
  final nativeBuildIndex = arguments.indexOf('--native-build');
  if (paidSource && buildIndex >= 0) {
    failures.add('a paid staging workspace must never be used for a web build');
  }
  if (buildIndex >= 0 && nativeBuildIndex >= 0) {
    failures.add('verify web and native build artifacts in separate commands');
  }
  if (buildIndex >= 0) {
    if (buildIndex + 1 >= arguments.length) {
      failures.add('--web-build requires a directory');
    } else {
      final root = Directory(arguments[buildIndex + 1]);
      final worker = File('${root.path}/flutter_service_worker.js');
      final builtContentManifest = File(
        '${root.path}/assets/assets/content/manifest.json',
      );
      if (!builtContentManifest.existsSync()) {
        failures.add('${root.path} has no bundled content manifest');
      } else if (contentManifestSource != null &&
          await builtContentManifest.readAsString() != contentManifestSource) {
        failures.add('${root.path} contains a stale content manifest');
      }
      if (!worker.existsSync()) {
        failures.add('${root.path} has no generated service worker');
      } else {
        final source = await worker.readAsString();
        final requiredAssets = <String>{
          'main.dart.js',
          'assets/assets/content/manifest.json',
          'assets/assets/puzzles/catalog.json',
          'assets/assets/puzzles/tutorial.json',
          'assets/assets/fonts/PixelifySans-Variable.ttf',
          'assets/assets/fonts/PixelifySans_LICENSE.txt',
          'assets/assets/art/knight_animations.png',
          'assets/assets/art/queen.png',
          'assets/assets/art/combat/knight_finishers.png',
          ...combatAssets.map((asset) => 'assets/$asset'),
          ...contentPolicy.webPackageAssets.map(_webAssetPath),
          ...contentPolicy.storefrontAssets.map(_webAssetPath),
          'icons/Icon-512.png',
        };
        for (final asset in requiredAssets) {
          if (!_serviceWorkerContains(source, asset)) {
            failures.add(
              'service worker does not list offline resource $asset',
            );
          }
        }
        final allowedWebAssets = {
          ...contentPolicy.webPackageAssets,
          ...contentPolicy.storefrontAssets,
          'assets/puzzles/catalog.json',
          'assets/puzzles/tutorial.json',
          'assets/fonts/PixelifySans-Variable.ttf',
          'assets/fonts/PixelifySans_LICENSE.txt',
          'assets/art/knight_animations.png',
          'assets/art/queen.png',
          'assets/art/combat/knight_finishers.png',
          ...combatAssets,
        };
        final excludedAssets = contentPolicy.webExcludedPackageAssets
            .difference(allowedWebAssets);
        for (final asset in excludedAssets) {
          final webAsset = _webAssetPath(asset);
          if (_serviceWorkerContains(source, webAsset)) {
            failures.add(
              'service worker lists web-excluded package asset $webAsset',
            );
          }
          if (File('${root.path}/$webAsset').existsSync()) {
            failures.add('web build bundles web-excluded package asset $asset');
          }
        }
      }
    }
  }
  if (nativeBuildIndex >= 0) {
    if (!paidSource) {
      failures.add('--native-build requires an expanded --paid-source');
    }
    if (nativeBuildIndex + 1 >= arguments.length) {
      failures.add('--native-build requires an artifact path');
    } else {
      final artifact = FileSystemEntity.typeSync(
        arguments[nativeBuildIndex + 1],
        followLinks: true,
      );
      if (artifact == FileSystemEntityType.notFound) {
        failures.add(
          'native build artifact is missing: '
          '${arguments[nativeBuildIndex + 1]}',
        );
      } else {
        final entries = await _nativeBundleEntries(
          arguments[nativeBuildIndex + 1],
          failures,
        );
        final requiredNativeAssets = <String>{
          'assets/content/manifest.json',
          'assets/puzzles/catalog.json',
          'assets/puzzles/tutorial.json',
          'assets/fonts/PixelifySans-Variable.ttf',
          'assets/fonts/PixelifySans_LICENSE.txt',
          'assets/art/knight_animations.png',
          'assets/art/queen.png',
          'assets/art/combat/knight_finishers.png',
          ...combatAssets,
          ...contentPolicy.webPackageAssets,
          ...contentPolicy.webExcludedPackageAssets,
          ...contentPolicy.storefrontAssets,
        };
        for (final asset in requiredNativeAssets) {
          if (!entries.any(
            (entry) => entry.endsWith('/flutter_assets/$asset'),
          )) {
            failures.add('native build omits bundled asset $asset');
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
    paidSource
        ? nativeBuildIndex >= 0
            ? 'Verified the paid native artifact and offline package set.'
            : 'Verified the expanded paid-edition source and offline package set.'
        : buildIndex >= 0
        ? 'Verified release network isolation and offline PWA resources.'
        : 'Verified release network isolation and installable PWA metadata.',
  );
}

Future<Set<String>> _nativeBundleEntries(
  String artifactPath,
  List<String> failures,
) async {
  final type = FileSystemEntity.typeSync(artifactPath, followLinks: true);
  if (type == FileSystemEntityType.directory) {
    final entries = <String>{};
    await for (final entity in Directory(
      artifactPath,
    ).list(recursive: true, followLinks: false)) {
      if (entity is File) {
        entries.add(entity.path.replaceAll('\\', '/'));
      }
    }
    return entries;
  }
  if (type == FileSystemEntityType.file) {
    final listing = await Process.run('unzip', ['-Z1', artifactPath]);
    if (listing.exitCode != 0) {
      failures.add('could not inspect native archive $artifactPath');
      return const {};
    }
    return LineSplitter.split(
      listing.stdout as String,
    ).map((entry) => entry.replaceAll('\\', '/')).toSet();
  }
  failures.add('unsupported native build artifact $artifactPath');
  return const {};
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

final class _ContentOfflinePolicy {
  const _ContentOfflinePolicy({
    required this.webPackageAssets,
    required this.webExcludedPackageAssets,
    required this.storefrontAssets,
  });

  const _ContentOfflinePolicy.empty()
    : webPackageAssets = const {},
      webExcludedPackageAssets = const {},
      storefrontAssets = const {};

  final Set<String> webPackageAssets;
  final Set<String> webExcludedPackageAssets;
  final Set<String> storefrontAssets;
}

_ContentOfflinePolicy _contentOfflinePolicy(
  Map<String, Object?> manifest, {
  required List<String> failures,
  required List<_FlutterAssetDeclaration> flutterAssets,
  required bool paidSource,
}) {
  _validateStoreLinks(manifest['storeLinks'], failures);
  final arcs = manifest['arcs'];
  if (arcs is! List<Object?>) {
    failures.add('content manifest arcs must be a list');
    return const _ContentOfflinePolicy.empty();
  }

  final webPackageAssets = <String>{};
  final webExcludedPackageAssets = <String>{};
  final storefrontAssets = <String>{};
  var originIncludedOnWeb = false;
  for (final (index, value) in arcs.indexed) {
    if (value is! Map<String, Object?>) {
      failures.add('content manifest arc $index must be an object');
      continue;
    }
    final arcId = value['arcId'] as String? ?? 'arc $index';
    final metadataAsset = _manifestAsset(
      value['metadataAsset'],
      '$arcId metadataAsset',
      failures,
    );
    final channels = switch (value['channels']) {
      final List<Object?> values => values.whereType<String>().toSet(),
      _ => const <String>{},
    };
    const knownChannels = {'web', 'paidPlatform'};
    if (channels.isEmpty) {
      failures.add('$arcId has no valid release channels');
    }
    final unknownChannels = channels.difference(knownChannels);
    if (unknownChannels.isNotEmpty) {
      failures.add('$arcId has unknown release channels $unknownChannels');
    }
    final lockedPreviewChannels = switch (value['lockedPreviewChannels']) {
      final List<Object?> values => values.whereType<String>().toSet(),
      null => const <String>{},
      _ => const <String>{'invalid'},
    };
    final unknownLockedChannels = lockedPreviewChannels.difference(
      knownChannels,
    );
    if (unknownLockedChannels.isNotEmpty) {
      failures.add(
        '$arcId has unknown locked-preview channels $unknownLockedChannels',
      );
    }
    final conflictingChannels = channels.intersection(lockedPreviewChannels);
    if (conflictingChannels.isNotEmpty) {
      failures.add(
        '$arcId is both available and locked on $conflictingChannels',
      );
    }
    final includedOnWeb = channels.contains('web');
    if (arcId == 'regalia:arc/origin' && includedOnWeb) {
      originIncludedOnWeb = true;
    }

    final packageAssets = <String>{if (metadataAsset != null) metadataAsset};
    if (metadataAsset != null) {
      final metadataFile = File(metadataAsset);
      final packageDirectory = metadataFile.parent;
      if (metadataAsset.startsWith('assets/content/arcs/') &&
          packageDirectory.existsSync()) {
        packageAssets.addAll(
          packageDirectory
              .listSync(recursive: true)
              .whereType<File>()
              .map((file) => file.path),
        );
      }
      if (metadataFile.existsSync()) {
        try {
          _collectAssetPaths(
            jsonDecode(metadataFile.readAsStringSync()),
            packageAssets,
          );
        } on Object catch (error) {
          failures.add('cannot inspect $metadataAsset: $error');
        }
      } else if (includedOnWeb) {
        failures.add('web arc metadata is missing: $metadataAsset');
      }
    }
    if (includedOnWeb) {
      webPackageAssets.addAll(packageAssets);
    } else {
      webExcludedPackageAssets.addAll(packageAssets);
    }

    final storefront = value['storefront'];
    if (storefront is! Map<String, Object?>) {
      failures.add('$arcId has no lightweight storefront content');
      continue;
    }
    final tileArt = _manifestAsset(
      storefront['tileArtAsset'],
      '$arcId storefront tileArtAsset',
      failures,
    );
    if (tileArt != null) storefrontAssets.add(tileArt);
    final tileForeground = storefront['tileForegroundAsset'];
    if (tileForeground != null) {
      final asset = _manifestAsset(
        tileForeground,
        '$arcId storefront tileForegroundAsset',
        failures,
      );
      if (asset != null) storefrontAssets.add(asset);
    }
    final preview = storefront['prologuePreview'];
    final previewAssets = <String>{};
    if (preview is! Map<String, Object?>) {
      failures.add('$arcId has no lightweight storefront prologue preview');
    } else {
      _collectAssetPaths(preview, previewAssets);
      if (previewAssets.isEmpty) {
        failures.add('$arcId storefront prologue preview has no art asset');
      }
      storefrontAssets.addAll(previewAssets);
    }
  }

  if (!originIncludedOnWeb) {
    failures.add('regalia:arc/origin must remain available on web');
  }

  for (final asset in storefrontAssets) {
    if (!File(asset).existsSync()) {
      failures.add('storefront asset is missing: $asset');
    }
    if (!_isFlutterAssetDeclared(asset, flutterAssets, flavor: null)) {
      failures.add(
        'storefront asset is not declared for the unflavored web edition: '
        '$asset',
      );
    }
  }
  for (final asset in webPackageAssets) {
    if (!File(asset).existsSync()) {
      failures.add('web content package asset is missing: $asset');
    }
    if (!_isFlutterAssetDeclared(asset, flutterAssets, flavor: null)) {
      failures.add(
        'web content package asset is not declared for the unflavored web '
        'edition: $asset',
      );
    }
  }

  final sharedWebAssets = {...webPackageAssets, ...storefrontAssets};
  for (final asset in webExcludedPackageAssets) {
    if (!File(asset).existsSync()) {
      failures.add('paid content package asset is missing: $asset');
      continue;
    }
    if (sharedWebAssets.contains(asset)) continue;
    if (paidSource) {
      if (!_isFlutterAssetDeclared(asset, flutterAssets, flavor: null)) {
        failures.add(
          'paid content package asset is not declared in the expanded paid '
          'edition: $asset',
        );
      }
      continue;
    }
    if (_isFlutterAssetDeclared(asset, flutterAssets, flavor: null)) {
      failures.add(
        'paid-only content asset leaks into the unflavored web edition: '
        '$asset',
      );
    }
    if (!_isFlutterAssetDeclared(asset, flutterAssets, flavor: 'paid')) {
      failures.add(
        'paid content package asset is not declared for the paid edition: '
        '$asset',
      );
    }
  }
  return _ContentOfflinePolicy(
    webPackageAssets: Set.unmodifiable(webPackageAssets),
    webExcludedPackageAssets: Set.unmodifiable(webExcludedPackageAssets),
    storefrontAssets: Set.unmodifiable(storefrontAssets),
  );
}

void _validateStoreLinks(Object? source, List<String> failures) {
  if (source is! Map<String, Object?>) {
    failures.add('content manifest has no storefront links');
    return;
  }
  const allowedHosts = {
    'appStore': 'apps.apple.com',
    'playStore': 'play.google.com',
  };
  for (final MapEntry(key: store, value: allowedHost) in allowedHosts.entries) {
    final link = source[store];
    final uri = link is String ? Uri.tryParse(link) : null;
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.toLowerCase() != allowedHost) {
      failures.add('$store must use https://$allowedHost');
    }
  }
}

String? _manifestAsset(Object? value, String label, List<String> failures) {
  if (value is! String ||
      !value.startsWith('assets/') ||
      value.contains('..')) {
    failures.add('$label is not a safe bundled asset path');
    return null;
  }
  return value;
}

void _collectAssetPaths(Object? value, Set<String> result) {
  switch (value) {
    case final String path when path.startsWith('assets/'):
      if (!path.contains('..')) result.add(path);
    case final List<Object?> values:
      for (final value in values) {
        _collectAssetPaths(value, result);
      }
    case final Map<String, Object?> values:
      for (final value in values.values) {
        _collectAssetPaths(value, result);
      }
  }
}

final class _FlutterAssetDeclaration {
  const _FlutterAssetDeclaration({required this.path, required this.flavors});

  final String path;
  final Set<String> flavors;

  bool includesFlavor(String? flavor) =>
      flavors.isEmpty || (flavor != null && flavors.contains(flavor));
}

List<_FlutterAssetDeclaration> _flutterAssetDeclarations(String pubspec) {
  final assets = <_FlutterAssetDeclaration>[];
  var inFlutter = false;
  var inAssets = false;
  String? pendingPath;
  var pendingFlavors = <String>{};
  var inFlavors = false;

  void flushPending() {
    final path = pendingPath;
    if (path != null) {
      assets.add(
        _FlutterAssetDeclaration(
          path: path,
          flavors: Set.unmodifiable(pendingFlavors),
        ),
      );
    }
    pendingPath = null;
    pendingFlavors = <String>{};
    inFlavors = false;
  }

  for (final line in const LineSplitter().convert(pubspec)) {
    if (line == 'flutter:') {
      inFlutter = true;
      continue;
    }
    if (inFlutter && line.isNotEmpty && !line.startsWith(' ')) {
      flushPending();
      break;
    }
    if (!inFlutter) continue;
    if (line == '  assets:') {
      inAssets = true;
      continue;
    }
    if (inAssets && line.startsWith('  ') && !line.startsWith('    ')) {
      flushPending();
      break;
    }
    if (!inAssets) continue;

    final item = RegExp(r'^    -\s+(.+?)\s*$').firstMatch(line);
    if (item != null) {
      flushPending();
      final value = item.group(1)!;
      final path = RegExp(r'^path:\s+(.+?)\s*$').firstMatch(value);
      if (path != null) {
        pendingPath = _yamlScalar(path.group(1)!);
      } else {
        assets.add(
          _FlutterAssetDeclaration(path: _yamlScalar(value), flavors: const {}),
        );
      }
      continue;
    }
    if (pendingPath == null) continue;
    if (line == '      flavors:') {
      inFlavors = true;
      continue;
    }
    if (inFlavors) {
      final flavor = RegExp(r'^        -\s+(.+?)\s*$').firstMatch(line);
      if (flavor != null) {
        pendingFlavors.add(_yamlScalar(flavor.group(1)!));
        continue;
      }
    }
    if (line.startsWith('      ') && line.trim().isNotEmpty) {
      inFlavors = false;
    }
  }
  flushPending();
  return List.unmodifiable(assets);
}

String _yamlScalar(String value) {
  final withoutComment = value.split(' #').first.trim();
  if (withoutComment.length >= 2 &&
      ((withoutComment.startsWith("'") && withoutComment.endsWith("'")) ||
          (withoutComment.startsWith('"') && withoutComment.endsWith('"')))) {
    return withoutComment.substring(1, withoutComment.length - 1);
  }
  return withoutComment;
}

bool _isFlutterAssetDeclared(
  String asset,
  List<_FlutterAssetDeclaration> declarations, {
  required String? flavor,
}) => declarations.any(
  (declaration) =>
      declaration.includesFlavor(flavor) &&
      (declaration.path == asset ||
          (declaration.path.endsWith('/') &&
              asset.startsWith(declaration.path) &&
              !asset.substring(declaration.path.length).contains('/'))),
);

String _webAssetPath(String asset) => 'assets/$asset';

bool _serviceWorkerContains(String source, String asset) =>
    source.contains('"$asset"');
