import 'dart:io';

/// Creates an isolated web-build workspace with app-only story packages
/// removed from Flutter's asset declarations.
///
/// The checked-in source remains the complete installed app. This temporary
/// copy keeps only Origin plus lightweight storefront previews for web.
Future<void> main(List<String> arguments) async {
  final outputIndex = arguments.indexOf('--output');
  if (outputIndex < 0 || outputIndex + 1 >= arguments.length) {
    stderr.writeln(
      'Usage: dart run tool/stage_web_edition.dart '
      '--output <empty-directory>',
    );
    exitCode = 64;
    return;
  }

  final source = Directory.current.absolute;
  final output = Directory(arguments[outputIndex + 1]).absolute;
  if (_contains(source.path, output.path) ||
      _contains(output.path, source.path)) {
    stderr.writeln(
      'The web staging directory must be outside the source repository: '
      '${output.path}',
    );
    exitCode = 64;
    return;
  }
  if (output.existsSync() && output.listSync().isNotEmpty) {
    stderr.writeln(
      'Refusing to overwrite a non-empty web staging directory: '
      '${output.path}',
    );
    exitCode = 73;
    return;
  }

  output.createSync(recursive: true);
  await _copyDirectory(source, output);

  final stagedPubspec = File(
    '${output.path}${Platform.pathSeparator}pubspec.yaml',
  );
  final sourcePubspec = await stagedPubspec.readAsString();
  final (filteredPubspec, removedCount) = _removeWebExcludedAssets(
    sourcePubspec,
  );
  if (removedCount == 0 || filteredPubspec.contains('# web-excluded')) {
    stderr.writeln(
      'Could not remove the web-excluded Flutter asset declarations.',
    );
    exitCode = 65;
    return;
  }
  await stagedPubspec.writeAsString(filteredPubspec, flush: true);

  stdout.writeln(
    'Web source staged at ${output.path} '
    '($removedCount channel-restricted asset roots excluded).',
  );
  stdout.writeln(
    'Build web only from this temporary directory; build every native target '
    'from the checked-in source.',
  );
}

bool _contains(String parent, String child) {
  final separator = Platform.pathSeparator;
  final normalizedParent =
      parent.endsWith(separator)
          ? parent.substring(0, parent.length - 1)
          : parent;
  return child == normalizedParent ||
      child.startsWith('$normalizedParent$separator');
}

Future<void> _copyDirectory(Directory source, Directory destination) async {
  const skippedDirectories = {
    '.dart_tool',
    '.git',
    '.gradle',
    '.idea',
    '.symlinks',
    '.venv',
    'Pods',
    'build',
    'ephemeral',
    'tmp',
  };
  await for (final entity in source.list(followLinks: false)) {
    final name =
        entity.uri.pathSegments.where((segment) => segment.isNotEmpty).last;
    if (entity is Directory && skippedDirectories.contains(name)) continue;

    final targetPath = '${destination.path}${Platform.pathSeparator}$name';
    switch (entity) {
      case final File file:
        await file.copy(targetPath);
      case final Directory directory:
        final target = Directory(targetPath)..createSync();
        await _copyDirectory(directory, target);
      case final Link link:
        await Link(targetPath).create(await link.target());
    }
  }
}

(String, int) _removeWebExcludedAssets(String pubspec) {
  final marker = RegExp(r'^    -\s+.+?\s+# web-excluded\s*$');
  var removedCount = 0;
  final lines = <String>[];
  for (final line in pubspec.split('\n')) {
    if (marker.hasMatch(line)) {
      removedCount++;
      continue;
    }
    lines.add(line);
  }
  return (lines.join('\n'), removedCount);
}
