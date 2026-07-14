import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_controller.dart';
import '../core/models.dart';
import '../widgets/completion_dialog.dart';
import '../widgets/regalia_board.dart';
import 'rules_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.controller, required this.puzzle});
  final AppController controller;
  final PuzzleDefinition puzzle;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final FocusNode _keyboardFocus = FocusNode(
    debugLabel: 'board keyboard focus',
  );
  Cell _selected = const Cell(0, 0);
  Set<Cell> _highlighted = {};
  Set<Cell> _conflicts = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.startTimer(widget.puzzle.id);
      _keyboardFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    widget.controller.stopTimer();
    _keyboardFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final puzzle = widget.puzzle;
    final board = widget.controller.boardFor(puzzle);
    final automatic =
        widget.controller.settings.showAutomaticExclusions
            ? widget.controller.ruleEngine.automaticExclusions(puzzle, board)
            : <Cell>{};
    final directConflictCells = {
      for (final conflict in widget.controller.ruleEngine.directConflicts(
        puzzle,
        board,
      )) ...[conflict.first, conflict.second],
    };
    return PopScope(
      onPopInvokedWithResult: (_, __) => widget.controller.stopTimer(),
      child: KeyboardListener(
        autofocus: true,
        focusNode: _keyboardFocus,
        onKeyEvent: _onKey,
        child: Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${puzzle.tier.label} · ${puzzle.size} × ${puzzle.size}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  'Puzzle ${puzzle.order} of 120',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            actions: [
              if (widget.controller.settings.showTimer)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Center(
                    child: Text(
                      CompletionDialog.formatTime(board.elapsedSeconds),
                      style: const TextStyle(
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              IconButton(
                tooltip: 'Rules',
                onPressed: _openRules,
                icon: const Icon(Icons.menu_book_outlined),
              ),
            ],
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 850;
                final boardWidget = ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: wide ? 650 : 620,
                    maxHeight: wide ? 650 : 620,
                  ),
                  child: RegaliaBoard(
                    puzzle: puzzle,
                    board: board,
                    automaticExclusions: automatic,
                    conflicts: {...directConflictCells, ..._conflicts},
                    highlighted: _highlighted,
                    selected: _selected,
                    onCellPressed: _pressCell,
                  ),
                );
                final controls = _Controls(
                  board: board,
                  onUndo:
                      board.undoStack.isEmpty
                          ? null
                          : () => widget.controller.undo(puzzle),
                  onRedo:
                      board.redoStack.isEmpty
                          ? null
                          : () => widget.controller.redo(puzzle),
                  onReset: _confirmReset,
                  onCheck: _check,
                  onHint: _hint,
                );
                if (wide) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(child: Center(child: boardWidget)),
                          const SizedBox(width: 36),
                          SizedBox(width: 240, child: controls),
                        ],
                      ),
                    ),
                  );
                }
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  child: Column(
                    children: [
                      boardWidget,
                      const SizedBox(height: 18),
                      controls,
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _pressCell(Cell cell) {
    setState(() {
      _selected = cell;
      _highlighted = {};
      _conflicts = {};
    });
    final completed = widget.controller.cycle(widget.puzzle, cell);
    if (completed) _showCompletion();
  }

  void _setSelected(ManualCellState state) {
    setState(() {
      _highlighted = {};
      _conflicts = {};
    });
    final completed = widget.controller.setCell(
      widget.puzzle,
      _selected,
      state,
    );
    if (completed) _showCompletion();
  }

  void _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final key = event.logicalKey;
    final size = widget.puzzle.size;
    if (HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed) {
      if (key == LogicalKeyboardKey.keyZ &&
          HardwareKeyboard.instance.isShiftPressed) {
        widget.controller.redo(widget.puzzle);
      } else if (key == LogicalKeyboardKey.keyZ) {
        widget.controller.undo(widget.puzzle);
      } else if (key == LogicalKeyboardKey.keyY) {
        widget.controller.redo(widget.puzzle);
      }
      return;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      setState(
        () =>
            _selected = Cell(
              (_selected.row - 1 + size) % size,
              _selected.column,
            ),
      );
    } else if (key == LogicalKeyboardKey.arrowDown) {
      setState(
        () => _selected = Cell((_selected.row + 1) % size, _selected.column),
      );
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      setState(
        () =>
            _selected = Cell(
              _selected.row,
              (_selected.column - 1 + size) % size,
            ),
      );
    } else if (key == LogicalKeyboardKey.arrowRight) {
      setState(
        () => _selected = Cell(_selected.row, (_selected.column + 1) % size),
      );
    } else if (key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.enter) {
      _pressCell(_selected);
    } else if (key == LogicalKeyboardKey.keyX) {
      _setSelected(ManualCellState.cross);
    } else if (key == LogicalKeyboardKey.keyC) {
      _setSelected(ManualCellState.crown);
    } else if (key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.backspace) {
      _setSelected(ManualCellState.empty);
    }
  }

  void _check() {
    final result = widget.controller.checkProgress(widget.puzzle);
    setState(() {
      _highlighted = result.inconsistentMarks;
      _conflicts = {
        for (final conflict in result.conflicts) ...[
          conflict.first,
          conflict.second,
        ],
      };
    });
    _message(
      result.isValid ? 'Still regal' : 'A contradiction',
      result.message,
      result.isValid ? Icons.check_circle_outline : Icons.error_outline,
    );
  }

  void _hint() {
    final deduction = widget.controller.hint(widget.puzzle);
    if (deduction == null) {
      _message(
        'No hint available',
        'Try clearing a mark and checking the board again.',
        Icons.lightbulb_outline,
      );
      return;
    }
    setState(() {
      _highlighted = {
        ...deduction.sources,
        ...deduction.eliminated,
        if (deduction.placement != null) deduction.placement!,
      };
      _conflicts = {};
    });
    _message('A gentle nudge', deduction.explanation, Icons.lightbulb_outline);
  }

  void _message(String title, String message, IconData icon) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.inversePrimary),
              const SizedBox(width: 12),
              Expanded(child: Text('$title — $message')),
            ],
          ),
        ),
      );
  }

  Future<void> _confirmReset() async {
    widget.controller.stopTimer();
    final reset = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Reset this attempt?'),
            content: const Text(
              'All marks and elapsed time on this board will be cleared.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep playing'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Reset'),
              ),
            ],
          ),
    );
    if (reset ?? false) {
      widget.controller.reset(widget.puzzle);
      widget.controller.startTimer(widget.puzzle.id);
      setState(() {
        _highlighted = {};
        _conflicts = {};
      });
    } else if (mounted) {
      widget.controller.startTimer(widget.puzzle.id);
    }
  }

  Future<void> _openRules() async {
    widget.controller.stopTimer();
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RulesScreen()),
    );
    if (mounted) widget.controller.startTimer(widget.puzzle.id);
  }

  Future<void> _showCompletion() async {
    final board = widget.controller.boardFor(widget.puzzle);
    final nextIndex =
        widget.puzzle.order < widget.controller.catalog!.puzzles.length
            ? widget.puzzle.order
            : 0;
    final next = widget.controller.catalog!.puzzles[nextIndex];
    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => CompletionDialog(
            board: board,
            onReplay: () => Navigator.pop(context, 'replay'),
            onNext: () => Navigator.pop(context, 'next'),
          ),
    );
    if (!mounted) return;
    if (action == 'replay') {
      widget.controller.reset(widget.puzzle);
      widget.controller.startTimer(widget.puzzle.id);
    } else if (action == 'next') {
      widget.controller.stopTimer();
      widget.controller.openPuzzle(next);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder:
              (_) => GameScreen(controller: widget.controller, puzzle: next),
        ),
      );
    }
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.board,
    required this.onUndo,
    required this.onRedo,
    required this.onReset,
    required this.onCheck,
    required this.onHint,
  });
  final BoardState board;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final VoidCallback onReset;
  final VoidCallback onCheck;
  final VoidCallback onHint;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 4,
        children: [
          IconButton.filledTonal(
            tooltip: 'Undo (Ctrl+Z)',
            onPressed: onUndo,
            icon: const Icon(Icons.undo_rounded),
          ),
          IconButton.filledTonal(
            tooltip: 'Redo (Ctrl+Y)',
            onPressed: onRedo,
            icon: const Icon(Icons.redo_rounded),
          ),
          IconButton.filledTonal(
            tooltip: 'Reset',
            onPressed: onReset,
            icon: const Icon(Icons.restart_alt_rounded),
          ),
        ],
      ),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: onCheck,
        icon: const Icon(Icons.fact_check_outlined),
        label: const Text('Check progress'),
      ),
      const SizedBox(height: 8),
      FilledButton.tonalIcon(
        onPressed: onHint,
        icon: const Icon(Icons.lightbulb_outline),
        label: const Text('Hint'),
      ),
      if (board.assisted) ...[
        const SizedBox(height: 12),
        Text(
          'Assisted attempt',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.secondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
      const SizedBox(height: 16),
      Text(
        'Keyboard: arrows move · Space cycles · X marks · C crowns',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );
}
