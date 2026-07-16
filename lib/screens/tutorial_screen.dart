import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../app/branding.dart';
import '../core/models.dart';
import '../widgets/crown_mark.dart';
import '../widgets/regalia_board.dart';

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key, required this.controller});
  final AppController controller;

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  late final PageController _pages;
  late final PuzzleDefinition _puzzle;
  late final BoardState _board;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _pages = PageController();
    _puzzle = widget.controller.tutorialPuzzle!;
    _board = BoardState(puzzleId: _puzzle.id, size: _puzzle.size);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: widget.controller.finishTutorial,
              child: const Text('Skip'),
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pages,
              onPageChanged: (value) => setState(() => _page = value),
              children: [_intro(context), _rules(context), _tryBoard(context)],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Row(
              children: [
                for (var index = 0; index < 3; index++)
                  Container(
                    width: index == _page ? 24 : 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color:
                          index == _page
                              ? Theme.of(context).colorScheme.secondary
                              : Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: () {
                    if (_page == 2) {
                      widget.controller.finishTutorial();
                    } else {
                      _pages.jumpToPage(_page + 1);
                    }
                  },
                  child: Text(_page == 2 ? 'Begin journey' : 'Next'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _intro(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: math.max(0, constraints.maxHeight - 56),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CrownMark(size: 88),
              const SizedBox(height: 24),
              Text(
                'Welcome to $appName',
                style: Theme.of(context).textTheme.displaySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              Text(
                'A quiet logic journey. No accounts, no ads, and every puzzle is available offline.',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _rules(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      return SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Three kinds of royalty',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                const _TutorialRule(
                  icon: Icons.table_rows,
                  text: 'Exactly one crown in every row',
                ),
                const _TutorialRule(
                  icon: Icons.view_column,
                  text: 'Exactly one crown in every column',
                ),
                const _TutorialRule(
                  icon: Icons.grid_view_rounded,
                  text: 'Exactly one crown in every colored region',
                ),
                const _TutorialRule(
                  icon: Icons.open_with_rounded,
                  text: 'Crowns may not touch, including diagonally',
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _tryBoard(BuildContext context) => LayoutBuilder(
    builder:
        (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              Text(
                'Try the board',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(_practicePrompt, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth:
                      constraints.maxWidth > 440 ? 440 : constraints.maxWidth,
                ),
                child: RegaliaBoard(
                  puzzle: _puzzle,
                  board: _board,
                  automaticExclusions: widget.controller.ruleEngine
                      .automaticExclusions(_puzzle, _board),
                  onCellPressed: (cell) => setState(() => _board.cycle(cell)),
                  onCellExcluded: (cell) {
                    if (_board.at(cell) != ManualCellState.crown) {
                      setState(() => _board.set(cell, ManualCellState.cross));
                    }
                  },
                ),
              ),
            ],
          ),
        ),
  );

  String get _practicePrompt {
    if (_board.cells.contains(ManualCellState.crown)) {
      return 'Crown placed — the soft dots show its automatic exclusions.';
    }
    if (_board.cells.contains(ManualCellState.cross)) {
      return 'Good. Tap that X again to turn it into a crown.';
    }
    return 'Tap once, or drag across several cells, to mark them with X.';
  }
}

class _TutorialRule extends StatelessWidget {
  const _TutorialRule({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.secondary),
        const SizedBox(width: 16),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
