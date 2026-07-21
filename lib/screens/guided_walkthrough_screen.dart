import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../app/journey.dart';
import '../core/human_solver.dart';
import '../core/models.dart';
import '../widgets/completion_dialog.dart';
import '../widgets/pixel_ui.dart';
import '../widgets/regalia_board.dart';

/// Teaches the rules while the player solves the real first Origin puzzle.
///
/// Journey play delegates every mutation to [AppController], so the solve is a
/// normal piece of story progress. A Home-screen replay owns its board here;
/// it never enters the controller's board, record, timer, or save paths.
class GuidedWalkthroughScreen extends StatefulWidget {
  const GuidedWalkthroughScreen({
    super.key,
    required this.controller,
    required this.puzzle,
    this.replay = false,
  });

  final AppController controller;
  final PuzzleDefinition puzzle;
  final bool replay;

  @override
  State<GuidedWalkthroughScreen> createState() =>
      _GuidedWalkthroughScreenState();
}

class _GuidedWalkthroughScreenState extends State<GuidedWalkthroughScreen> {
  BoardState? _replayBoard;
  bool _rulesAcknowledged = false;
  bool _automaticExclusionsAcknowledged = false;
  bool _completionShowing = false;

  BoardState get _board =>
      _replayBoard ?? widget.controller.boardFor(widget.puzzle);

  @override
  void initState() {
    super.initState();
    if (widget.replay) {
      _replayBoard = BoardState(
        puzzleId: widget.puzzle.id,
        size: widget.puzzle.size,
      );
    } else {
      final cells = _board.cells;
      _rulesAcknowledged = cells.any((state) => state != ManualCellState.empty);
      _automaticExclusionsAcknowledged =
          cells.where((state) => state == ManualCellState.crown).length >= 2;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.controller.startTimer(widget.puzzle.id);
      });
    }
  }

  @override
  void dispose() {
    if (!widget.replay) widget.controller.stopTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final board = _board;
    final automatic = widget.controller.ruleEngine.automaticExclusions(
      widget.puzzle,
      board,
    );
    final conflicts = {
      for (final conflict in widget.controller.ruleEngine.directConflicts(
        widget.puzzle,
        board,
      )) ...[conflict.first, conflict.second],
    };
    final guide = _guideFor(board);
    final boardWidget = RegaliaBoard(
      key: const ValueKey('guided-walkthrough-board'),
      puzzle: widget.puzzle,
      board: board,
      automaticExclusions: automatic,
      conflicts: conflicts,
      cues: guide.cues,
      onCellPressed: _pressCell,
      onCellDragged: _dragCell,
      onExclusionDragStarted: _beginDrag,
      onExclusionDragEnded: _endDrag,
    );
    return Scaffold(
      appBar: AppBar(
        leading: const PixelBackButton(),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.replay ? 'Rules walkthrough' : 'Your first puzzle',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              widget.replay
                  ? 'Practice only · progress stays unchanged'
                  : 'Guided Origin puzzle · ${widget.puzzle.size} × ${widget.puzzle.size}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: AbsorbPointer(
          absorbing: _completionShowing,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 850;
              if (wide) {
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1080),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        children: [
                          Expanded(
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 650,
                                  maxHeight: 650,
                                ),
                                child: boardWidget,
                              ),
                            ),
                          ),
                          const SizedBox(width: 32),
                          SizedBox(
                            width: 330,
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _GuidePanel(
                                    guide: guide,
                                    onContinue: _continueGuide,
                                  ),
                                  const SizedBox(height: 14),
                                  _WalkthroughControls(
                                    canUndo: board.undoStack.isNotEmpty,
                                    onUndo: _undo,
                                    onReset: _confirmReset,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
              return SingleChildScrollView(
                key: const ValueKey('guided-walkthrough-scroll'),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _GuidePanel(guide: guide, onContinue: _continueGuide),
                        const SizedBox(height: 16),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: boardWidget,
                        ),
                        const SizedBox(height: 16),
                        _WalkthroughControls(
                          canUndo: board.undoStack.isNotEmpty,
                          onUndo: _undo,
                          onReset: _confirmReset,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  _WalkthroughGuide _guideFor(BoardState board) {
    if (!_rulesAcknowledged) {
      return const _WalkthroughGuide(
        title: 'Four rules make every crown certain',
        body:
            'Place exactly one crown in every row, every column, and every outlined region. Crowns also cannot touch, even diagonally.',
        actionLabel: 'Show the first deduction',
      );
    }
    final crowns = board.cells.where((state) => state == ManualCellState.crown);
    if (crowns.isNotEmpty && !_automaticExclusionsAcknowledged) {
      return const _WalkthroughGuide(
        title: 'The board protects each crown',
        body:
            'The faded X marks appeared automatically. They show the crown’s row, column, region, and touching squares, so you do not need to mark those cells yourself.',
        actionLabel: 'Keep solving',
      );
    }
    final deduction = widget.controller.humanSolver.nextDeduction(
      widget.puzzle,
      board,
    );
    if (deduction == null) {
      return const _WalkthroughGuide(
        title: 'Use all four rules together',
        body:
            'Look for a row, column, or region with only one open square. Mark impossible squares with X until a crown has only one place left.',
      );
    }
    if (deduction.placement case final placement?) {
      return _WalkthroughGuide(
        title: crowns.isEmpty ? 'Place your first crown' : 'One place remains',
        body:
            'The gold-highlighted square is the only possible place in its row, column, or region. Tap it until it shows a crown.',
        detail: _cellName(placement),
        cues: _cuesFor(deduction),
      );
    }
    if (deduction.eliminated.isNotEmpty) {
      return _WalkthroughGuide(
        title:
            crowns.isEmpty
                ? 'Start by ruling out a square'
                : 'Narrow the board',
        body:
            'The red-highlighted square${deduction.eliminated.length == 1 ? '' : 's'} cannot hold a crown without breaking another row, column, or region. Tap ${deduction.eliminated.length == 1 ? 'it' : 'each one'} once to mark X.',
        cues: _cuesFor(deduction),
      );
    }
    return _WalkthroughGuide(
      title: 'Repair the contradiction',
      body:
          'The highlighted marks break one of the four rules. Undo the latest mark, then follow the open rows, columns, and regions again.',
      cues: {for (final cell in deduction.sources) cell: BoardCue.checkError},
    );
  }

  Map<Cell, BoardCue> _cuesFor(Deduction deduction) => {
    for (final cell in deduction.sources) cell: BoardCue.hintSource,
    for (final cell in deduction.eliminated) cell: BoardCue.hintElimination,
    if (deduction.placement case final placement?)
      placement: BoardCue.hintPlacement,
  };

  String _cellName(Cell cell) =>
      'Row ${cell.row + 1}, column ${String.fromCharCode(65 + cell.column)}';

  void _continueGuide() {
    setState(() {
      if (!_rulesAcknowledged) {
        _rulesAcknowledged = true;
      } else {
        _automaticExclusionsAcknowledged = true;
      }
    });
  }

  void _pressCell(Cell cell) {
    if (_completionShowing) return;
    PuzzleCompletionOutcome? outcome;
    if (widget.replay) {
      _board.cycle(cell);
    } else {
      outcome = widget.controller.cycle(widget.puzzle, cell);
    }
    setState(() {});
    if (outcome != null) {
      unawaited(_showCompletion(outcome));
    } else if (widget.replay &&
        widget.controller.ruleEngine.isComplete(widget.puzzle, _board)) {
      unawaited(_showCompletion(null));
    }
  }

  void _dragCell(Cell cell, ManualCellState targetState) {
    if (_completionShowing || _board.at(cell) == ManualCellState.crown) return;
    if (widget.replay) {
      _board.set(cell, targetState);
    } else {
      widget.controller.setCell(widget.puzzle, cell, targetState);
    }
    setState(() {});
  }

  void _beginDrag() {
    if (widget.replay) {
      _board.beginBatch();
    } else {
      widget.controller.beginCellBatch(widget.puzzle);
    }
  }

  void _endDrag() {
    if (widget.replay) {
      _board.endBatch();
      setState(() {});
    } else {
      widget.controller.endCellBatch(widget.puzzle);
    }
  }

  void _undo() {
    if (widget.replay) {
      if (_board.undo()) setState(() {});
    } else {
      widget.controller.undo(widget.puzzle);
      setState(() {});
    }
  }

  Future<void> _confirmReset() async {
    if (!widget.replay) widget.controller.stopTimer();
    final reset = await showDialog<bool>(
      context: context,
      builder:
          (context) => PixelDialog(
            semanticLabel: 'Restart the walkthrough?',
            title: const Text('Restart the walkthrough?'),
            content: const Text(
              'Every mark on this practice board will clear.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep solving'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Restart'),
              ),
            ],
          ),
    );
    if (!mounted) return;
    if (reset ?? false) {
      if (widget.replay) {
        _board.reset();
      } else {
        widget.controller.reset(widget.puzzle);
      }
      setState(() {
        _rulesAcknowledged = false;
        _automaticExclusionsAcknowledged = false;
      });
    }
    if (!widget.replay) widget.controller.startTimer(widget.puzzle.id);
  }

  Future<void> _showCompletion(PuzzleCompletionOutcome? outcome) async {
    if (_completionShowing || !mounted) return;
    setState(() => _completionShowing = true);
    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => CompletionDialog(
            board: _board,
            advancesJourney: widget.replay ? false : outcome!.advancedJourney,
            isJourneyComplete: outcome?.isJourneyComplete ?? false,
            nextLabel: widget.replay ? 'Return Home' : null,
            onReplay: () => Navigator.pop(context, 'replay'),
            onNext: () => Navigator.pop(context, 'next'),
          ),
    );
    if (!mounted) return;
    if (action == 'replay') {
      if (widget.replay) {
        _board.reset();
      } else {
        widget.controller.reset(widget.puzzle);
        widget.controller.startTimer(widget.puzzle.id);
      }
      setState(() {
        _rulesAcknowledged = false;
        _automaticExclusionsAcknowledged = false;
        _completionShowing = false;
      });
      return;
    }
    if (action == 'next') {
      Navigator.of(context).pop(outcome);
      return;
    }
    setState(() => _completionShowing = false);
  }
}

class _WalkthroughGuide {
  const _WalkthroughGuide({
    required this.title,
    required this.body,
    this.detail,
    this.actionLabel,
    this.cues = const {},
  });

  final String title;
  final String body;
  final String? detail;
  final String? actionLabel;
  final Map<Cell, BoardCue> cues;
}

class _GuidePanel extends StatelessWidget {
  const _GuidePanel({required this.guide, required this.onContinue});

  final _WalkthroughGuide guide;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) => PixelPanel(
    key: const ValueKey('guided-walkthrough-panel'),
    borderColor: Theme.of(context).colorScheme.secondary,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PixelIcon(
              PixelGlyph.book,
              color: Theme.of(context).colorScheme.secondary,
              size: 32,
              excludeFromSemantics: true,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                guide.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(guide.body),
        if (guide.detail case final detail?) ...[
          const SizedBox(height: 8),
          Text(
            detail,
            style: TextStyle(
              color: Theme.of(context).colorScheme.secondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        if (guide.actionLabel case final label?) ...[
          const SizedBox(height: 12),
          FilledButton(
            key: const ValueKey('guided-walkthrough-continue'),
            onPressed: onContinue,
            child: Text(label),
          ),
        ],
      ],
    ),
  );
}

class _WalkthroughControls extends StatelessWidget {
  const _WalkthroughControls({
    required this.canUndo,
    required this.onUndo,
    required this.onReset,
  });

  final bool canUndo;
  final VoidCallback onUndo;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: OutlinedButton.icon(
          key: const ValueKey('guided-walkthrough-undo'),
          onPressed: canUndo ? onUndo : null,
          icon: PixelIcon(
            PixelGlyph.undo,
            color: Theme.of(context).colorScheme.secondary,
            size: 16,
            excludeFromSemantics: true,
          ),
          label: const Text('Undo'),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: OutlinedButton.icon(
          key: const ValueKey('guided-walkthrough-reset'),
          onPressed: onReset,
          icon: PixelIcon(
            PixelGlyph.reset,
            color: Theme.of(context).colorScheme.secondary,
            size: 16,
            excludeFromSemantics: true,
          ),
          label: const Text('Restart'),
        ),
      ),
    ],
  );
}
