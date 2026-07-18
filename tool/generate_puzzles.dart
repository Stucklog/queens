import 'dart:convert';
import 'dart:io';

import 'package:regalia/core/exact_solver.dart';
import 'package:regalia/core/generator.dart';
import 'package:regalia/core/human_solver.dart';
import 'package:regalia/core/models.dart';
import 'package:regalia/content/content_ids.dart';

Future<void> main(List<String> arguments) async {
  final command = arguments.isEmpty ? 'report' : arguments.first;
  final catalogPath =
      _option(arguments, '--catalog') ?? 'assets/puzzles/catalog.json';
  switch (command) {
    case 'generate':
      final seed = int.tryParse(_option(arguments, '--seed') ?? '') ?? 20260714;
      final plan =
          arguments.contains('--tutorial')
              ? const [GenerationRequest(DifficultyTier.easy, 4, 1)]
              : arguments.contains('--smoke')
              ? const [
                GenerationRequest(DifficultyTier.easy, 6, 1),
                GenerationRequest(DifficultyTier.easy, 7, 1),
                GenerationRequest(DifficultyTier.medium, 7, 1),
                GenerationRequest(DifficultyTier.medium, 8, 1),
                GenerationRequest(DifficultyTier.hard, 8, 1),
                GenerationRequest(DifficultyTier.hard, 9, 1),
                GenerationRequest(DifficultyTier.expert, 9, 1),
                GenerationRequest(DifficultyTier.expert, 10, 1),
                GenerationRequest(DifficultyTier.expert, 12, 1),
              ]
              : originStoryGenerationPlan;
      final generated = const PuzzleGenerator().generateCatalog(
        seed: seed,
        plan: plan,
      );
      final catalog = {
        'schemaVersion': 2,
        'scoringModel': HumanSolver.scoringModel,
        'puzzles': generated.map((entry) => entry.definition.toJson()).toList(),
      };
      final report = {
        'generatedAt': DateTime.now().toUtc().toIso8601String(),
        'seed': seed,
        'puzzles': [
          for (final entry in generated) _generationReportEntry(entry),
        ],
      };
      await File(catalogPath).parent.create(recursive: true);
      await File(
        catalogPath,
      ).writeAsString(const JsonEncoder.withIndent('  ').convert(catalog));
      final reportPath =
          _option(arguments, '--report') ?? 'tool/validation_report.json';
      await File(
        reportPath,
      ).writeAsString(const JsonEncoder.withIndent('  ').convert(report));
      stdout.writeln(
        'Generated ${generated.length} validated puzzles in $catalogPath.',
      );
    case 'generate-boss':
      final selector = arguments.length > 1 ? arguments[1] : '';
      final request = originBossGenerationPlan.firstWhere(
        (candidate) => candidate.puzzleId!.endsWith('/$selector'),
        orElse: () => throw ArgumentError.value(selector, 'boss'),
      );
      final seed = int.tryParse(_option(arguments, '--seed') ?? '') ?? 20260718;
      final maxAttempts =
          int.tryParse(_option(arguments, '--max-attempts') ?? '') ?? 5000;
      final generated =
          const PuzzleGenerator()
              .generateCatalog(
                seed: seed,
                plan: [request],
                maxAttemptsPerPuzzle: maxAttempts,
              )
              .single;
      final output = _option(arguments, '--output');
      final encoded = const JsonEncoder.withIndent(
        '  ',
      ).convert(generated.definition.toJson());
      if (output == null) {
        stdout.writeln(encoded);
      } else {
        await File(output).writeAsString(encoded);
        stdout.writeln('Generated ${request.puzzleId} in $output.');
      }
    case 'generate-bosses':
      final seed = int.tryParse(_option(arguments, '--seed') ?? '') ?? 20260718;
      final existing = await _loadCatalog(catalogPath);
      final generated = <GeneratedPuzzle>[];
      for (var index = 0; index < originBossGenerationPlan.length; index++) {
        final request = originBossGenerationPlan[index];
        stdout.writeln(
          'Generating ${request.puzzleId} (${request.tier.label} ${request.size}x${request.size})...',
        );
        generated.add(
          const PuzzleGenerator()
              .generateCatalog(
                seed: request.size == 12 ? seed : seed + index * 1000003,
                plan: [request],
              )
              .single,
        );
      }
      const bossOrders = [20, 30, 40, 60, 80, 90, 100, 120];
      final replacements = <int, PuzzleDefinition>{};
      for (var index = 0; index < bossOrders.length; index++) {
        final source = generated[index].definition;
        replacements[bossOrders[index]] = PuzzleDefinition(
          id: source.id,
          order: bossOrders[index],
          size: source.size,
          tier: source.tier,
          regions: source.regions,
          schemaVersion: source.schemaVersion,
          contentHash: source.contentHash,
          difficultyScore: source.difficultyScore,
          scoringModel: source.scoringModel,
        );
      }
      final updated = PuzzleCatalog(
        schemaVersion: existing.schemaVersion,
        scoringModel: existing.scoringModel,
        puzzles: [
          for (final puzzle in existing.puzzles)
            replacements[puzzle.order] ?? puzzle,
        ],
      );
      _validate(updated);
      await File(catalogPath).writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'schemaVersion': updated.schemaVersion,
          'scoringModel': updated.scoringModel,
          'puzzles': [for (final puzzle in updated.puzzles) puzzle.toJson()],
        }),
      );
      final reportPath =
          _option(arguments, '--report') ?? 'tool/validation_report.json';
      final report =
          jsonDecode(await File(reportPath).readAsString())
              as Map<String, Object?>;
      final reportPuzzles = report['puzzles']! as List<Object?>;
      for (var index = 0; index < bossOrders.length; index++) {
        reportPuzzles[bossOrders[index] - 1] = _generationReportEntry(
          generated[index],
        );
      }
      report['generatedAt'] = DateTime.now().toUtc().toIso8601String();
      report['seed'] = seed;
      await File(
        reportPath,
      ).writeAsString(const JsonEncoder.withIndent('  ').convert(report));
      stdout.writeln(
        'Generated and installed ${generated.length} chapter bosses in $catalogPath.',
      );
    case 'validate':
      final catalog = await _loadCatalog(catalogPath);
      _validate(catalog);
      final tutorial = PuzzleDefinition.fromJson(
        jsonDecode(await File('assets/puzzles/tutorial.json').readAsString())
            as Map<String, Object?>,
      );
      _validateTutorial(tutorial, catalog);
      stdout.writeln(
        'Validated ${catalog.puzzles.length} puzzles and the guided tutorial.',
      );
    case 'inspect':
      final id = arguments.length > 1 ? arguments[1] : '';
      final catalog = await _loadCatalog(catalogPath);
      final puzzle = catalog.byId(id);
      final exact = const ExactSolver().solve(puzzle, limit: 2);
      final human = const HumanSolver().analyze(puzzle);
      stdout.writeln(
        const JsonEncoder.withIndent('  ').convert({
          ...puzzle.toJson(),
          'solutions': exact.solutionCount,
          'humanTier': human.tier.name,
          'humanScore': human.score,
          'trace':
              human.trace
                  .map(
                    (step) => {
                      'technique': step.technique.name,
                      'explanation': step.explanation,
                    },
                  )
                  .toList(),
        }),
      );
    case 'report':
      final catalog = await _loadCatalog(catalogPath);
      final counts = <String, int>{};
      final observed = <String, int>{};
      final techniques = <String, int>{};
      var mismatches = 0;
      for (final puzzle in catalog.puzzles) {
        final key = '${puzzle.tier.name} ${puzzle.size}x${puzzle.size}';
        counts[key] = (counts[key] ?? 0) + 1;
        final report = const HumanSolver().analyze(puzzle);
        observed[report.tier.name] = (observed[report.tier.name] ?? 0) + 1;
        for (final deduction in report.trace) {
          final key = deduction.technique.name;
          techniques[key] = (techniques[key] ?? 0) + 1;
        }
        if (!report.solved || report.tier != puzzle.tier) mismatches++;
      }
      stdout.writeln(
        'Queen’s Regalia catalog: ${catalog.puzzles.length} puzzles',
      );
      for (final entry in counts.entries) {
        stdout.writeln('  ${entry.key}: ${entry.value}');
      }
      stdout.writeln('Observed human tiers: $observed');
      stdout.writeln('Observed techniques: $techniques');
      stdout.writeln('Tier mismatches: $mismatches');
    default:
      stderr.writeln(
        'Usage: dart run tool/generate_puzzles.dart <generate|generate-boss|generate-bosses|validate|inspect|report> [id] [--catalog path] [--seed n]',
      );
      exitCode = 64;
  }
}

Future<PuzzleCatalog> _loadCatalog(String path) async =>
    PuzzleCatalog.fromJsonString(await File(path).readAsString());

Map<String, Object> _generationReportEntry(GeneratedPuzzle entry) => {
  'id': entry.definition.id,
  'seed': entry.seed,
  'solution':
      entry.solution
          .map((cell) => {'row': cell.row, 'column': cell.column})
          .toList(),
  'exact': {
    'searchNodes': entry.exact.searchNodes,
    'backtracks': entry.exact.backtracks,
    'maxBranching': entry.exact.maxBranching,
  },
  'generationScore': entry.generationScore.toJson(),
  'human': {
    'actualTier': entry.human.tier.name,
    'actualScore': entry.human.score,
    'deductions': entry.human.trace.map((step) => step.technique.name).toList(),
  },
};

void _validate(PuzzleCatalog catalog) {
  catalog.validateSchema();
  final exact = const ExactSolver();
  final generator = const PuzzleGenerator();
  final fingerprints = <String>{};
  for (final puzzle in catalog.puzzles) {
    final issue = generator.validateRegionQuality(puzzle);
    if (issue != null) throw StateError('${puzzle.id}: $issue');
    if (exact.solve(puzzle, limit: 2).solutionCount != 1) {
      throw StateError('${puzzle.id}: not uniquely solvable');
    }
    if (!fingerprints.add(generator.canonicalFingerprint(puzzle))) {
      throw StateError('${puzzle.id}: canonical duplicate');
    }
    final difficulty = const HumanSolver().analyze(puzzle);
    if (!difficulty.solved) {
      throw StateError('${puzzle.id}: no explainable trace');
    }
    if (difficulty.tier != puzzle.tier ||
        difficulty.score != puzzle.difficultyScore ||
        difficulty.score < puzzle.tier.bandStart ||
        difficulty.score > puzzle.tier.bandStart + 24) {
      throw StateError('${puzzle.id}: difficulty calibration mismatch');
    }
  }
  if (catalog.puzzles.length != 120) {
    throw StateError('Expected 120 puzzles, found ${catalog.puzzles.length}');
  }
  for (final request in launchPlan) {
    final actual =
        catalog.puzzles
            .where(
              (puzzle) =>
                  puzzle.tier == request.tier && puzzle.size == request.size,
            )
            .length;
    if (actual != request.count) {
      throw StateError(
        '${request.tier.label} ${request.size}x${request.size}: expected ${request.count}, found $actual',
      );
    }
  }
}

void _validateTutorial(PuzzleDefinition tutorial, PuzzleCatalog catalog) {
  const exact = ExactSolver();
  const human = HumanSolver();
  const generator = PuzzleGenerator();
  if (tutorial.id != ContentIds.tutorialPuzzle ||
      catalog.puzzles.any((puzzle) => puzzle.id == tutorial.id)) {
    throw StateError('Tutorial must have a separate namespaced ID');
  }
  final issue = generator.validateRegionQuality(tutorial);
  if (issue != null) throw StateError('${tutorial.id}: $issue');
  if (exact.solve(tutorial, limit: 2).solutionCount != 1) {
    throw StateError('${tutorial.id}: not uniquely solvable');
  }
  final report = human.analyze(tutorial);
  if (!report.solved || report.tier != DifficultyTier.easy) {
    throw StateError('${tutorial.id}: tutorial must have an Easy trace');
  }
  final tutorialFingerprint = generator.canonicalFingerprint(tutorial);
  if (catalog.puzzles.any(
    (puzzle) => generator.canonicalFingerprint(puzzle) == tutorialFingerprint,
  )) {
    throw StateError('${tutorial.id}: duplicates a catalog board');
  }
}

String? _option(List<String> arguments, String name) {
  final index = arguments.indexOf(name);
  return index >= 0 && index + 1 < arguments.length
      ? arguments[index + 1]
      : null;
}
