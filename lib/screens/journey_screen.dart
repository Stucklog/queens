import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../core/models.dart';
import '../widgets/crown_mark.dart';
import 'game_screen.dart';
import 'rules_screen.dart';
import 'settings_screen.dart';

class JourneyScreen extends StatelessWidget {
  const JourneyScreen({super.key, required this.controller});
  final AppController controller;

  void _open(BuildContext context, PuzzleDefinition puzzle) {
    controller.openPuzzle(puzzle);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(controller: controller, puzzle: puzzle),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = controller.catalog!;
    final clean =
        catalog.puzzles
            .where(
              (puzzle) =>
                  controller.recordFor(puzzle.id).status ==
                  CompletionStatus.cleanSolved,
            )
            .length;
    final assisted =
        catalog.puzzles
            .where(
              (puzzle) =>
                  controller.recordFor(puzzle.id).status ==
                  CompletionStatus.assistedSolved,
            )
            .length;
    final recommended = controller.recommendedPuzzle();
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CrownMark(size: 30),
            SizedBox(width: 10),
            Text(
              "QUEEN'S\nREGALIA",
              style: TextStyle(
                height: .9,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'How to play',
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RulesScreen()),
                ),
            icon: const Icon(Icons.menu_book_outlined),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SettingsScreen(controller: controller),
                  ),
                ),
            icon: const Icon(Icons.tune_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Your royal journey',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 14),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Wrap(
                            spacing: 24,
                            runSpacing: 16,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              SizedBox(
                                width: 120,
                                height: 120,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    CircularProgressIndicator(
                                      value: clean / 120,
                                      strokeWidth: 9,
                                      backgroundColor:
                                          Theme.of(
                                            context,
                                          ).colorScheme.surfaceContainerHighest,
                                    ),
                                    Center(
                                      child: Text(
                                        '$clean\nclean',
                                        textAlign: TextAlign.center,
                                        style:
                                            Theme.of(
                                              context,
                                            ).textTheme.titleLarge,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: 280,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$clean of 120 mastered',
                                      style:
                                          Theme.of(
                                            context,
                                          ).textTheme.titleLarge,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      assisted == 0
                                          ? 'Every board is open. Choose your path.'
                                          : '$assisted assisted completion${assisted == 1 ? '' : 's'} can be replayed clean.',
                                    ),
                                    const SizedBox(height: 14),
                                    FilledButton.icon(
                                      onPressed:
                                          () => _open(context, recommended),
                                      icon: const Icon(
                                        Icons.play_arrow_rounded,
                                      ),
                                      label: Text(
                                        controller.hasActiveBoard(recommended)
                                            ? 'Continue'
                                            : _continueLabel(
                                              controller
                                                  .recordFor(recommended.id)
                                                  .status,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'The collection',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.crossAxisExtent;
                final columns =
                    width >= 1000
                        ? 6
                        : width >= 720
                        ? 4
                        : width >= 440
                        ? 3
                        : 2;
                return SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.15,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final puzzle = catalog.puzzles[index];
                    return _PuzzleCard(
                      puzzle: puzzle,
                      status: controller.statusFor(puzzle),
                      onTap: () => _open(context, puzzle),
                    );
                  }, childCount: catalog.puzzles.length),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _continueLabel(CompletionStatus status) => switch (status) {
    CompletionStatus.inProgress => 'Continue',
    CompletionStatus.assistedSolved => 'Replay clean',
    _ => 'Play next',
  };
}

class _PuzzleCard extends StatelessWidget {
  const _PuzzleCard({
    required this.puzzle,
    required this.status,
    required this.onTap,
  });
  final PuzzleDefinition puzzle;
  final CompletionStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '#${puzzle.order.toString().padLeft(3, '0')}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Icon(
                  switch (status) {
                    CompletionStatus.cleanSolved => Icons.workspace_premium,
                    CompletionStatus.assistedSolved => Icons.auto_awesome,
                    CompletionStatus.inProgress => Icons.more_horiz,
                    CompletionStatus.newPuzzle => Icons.circle_outlined,
                  },
                  size: 20,
                  color:
                      status == CompletionStatus.cleanSolved
                          ? Theme.of(context).colorScheme.secondary
                          : null,
                ),
              ],
            ),
            const Spacer(),
            Text(
              '${puzzle.size} × ${puzzle.size}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(puzzle.tier.label),
          ],
        ),
      ),
    ),
  );
}
