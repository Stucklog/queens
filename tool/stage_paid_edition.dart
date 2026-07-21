import 'dart:io';

/// Creates an isolated native-build workspace whose paid asset declarations
/// are unconditional.
///
/// Flutter 3.29 can filter assets by flavor on Android, iOS, and macOS, but it
/// cannot pass an asset flavor to Linux or Windows builds. Keeping the checked-
/// in pubspec web-safe and materializing a native-only staging workspace gives
/// every paid platform the same complete offline bundle without ever making a
/// web build from the expanded declaration set.
Future<void> main(List<String> arguments) async {
  final outputIndex = arguments.indexOf('--output');
  if (outputIndex < 0 || outputIndex + 1 >= arguments.length) {
    stderr.writeln(
      'Usage: dart run tool/stage_paid_edition.dart --output <empty-directory>',
    );
    exitCode = 64;
    return;
  }

  final source = Directory.current.absolute;
  final output = Directory(arguments[outputIndex + 1]).absolute;
  if (_contains(source.path, output.path) ||
      _contains(output.path, source.path)) {
    stderr.writeln(
      'The paid staging directory must be outside the source repository: '
      '${output.path}',
    );
    exitCode = 64;
    return;
  }
  if (output.existsSync() && output.listSync().isNotEmpty) {
    stderr.writeln(
      'Refusing to overwrite a non-empty paid staging directory: '
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
  final expandedPubspec = _expandPaidAssets(sourcePubspec);
  if (sourcePubspec == expandedPubspec ||
      expandedPubspec.contains(RegExp(r'^\s+flavors:', multiLine: true))) {
    stderr.writeln(
      'Could not materialize a fully expanded paid asset declaration set.',
    );
    exitCode = 65;
    return;
  }
  await stagedPubspec.writeAsString(expandedPubspec, flush: true);

  stdout.writeln('Paid edition staged at ${output.path}');
  stdout.writeln(
    'Verify it with: dart run tool/verify_offline.dart --paid-source',
  );
  stdout.writeln('Run native Flutter build commands from that directory.');
  stdout.writeln('Do not run flutter build web from a paid staging workspace.');
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

String _expandPaidAssets(String pubspec) {
  final lines = pubspec.split('\n');
  final output = <String>[];
  for (var index = 0; index < lines.length; index++) {
    final pathMatch = RegExp(
      r'^    - path:\s+(.+?)\s*$',
    ).firstMatch(lines[index]);
    if (pathMatch == null) {
      output.add(lines[index]);
      continue;
    }

    final block = <String>[lines[index]];
    while (index + 1 < lines.length &&
        !lines[index + 1].startsWith('    - ') &&
        (lines[index + 1].startsWith('      ') ||
            lines[index + 1].trim().isEmpty)) {
      block.add(lines[++index]);
    }
    final flavors =
        block
            .map((line) => RegExp(r'^        -\s+(.+?)\s*$').firstMatch(line))
            .whereType<RegExpMatch>()
            .map((match) => match.group(1)!)
            .toSet();
    if (!flavors.contains('paid')) continue;
    output.add('    - ${pathMatch.group(1)!}');
  }
  return output.join('\n');
}
