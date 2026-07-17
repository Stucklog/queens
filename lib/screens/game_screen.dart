import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_controller.dart';
import '../app/challenge.dart';
import '../app/journey.dart';
import '../app/theme.dart';
import '../core/models.dart';
import '../widgets/completion_dialog.dart';
import '../widgets/pixel_art.dart';
import '../widgets/pixel_ui.dart';
import '../widgets/regalia_board.dart';
import 'rules_screen.dart';

enum PuzzlePlayMode { journey, challenge }

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.controller,
    required this.puzzle,
    this.playMode = PuzzlePlayMode.journey,
    this.challengeNumber,
  });
  final AppController controller;
  final PuzzleDefinition puzzle;
  final PuzzlePlayMode playMode;
  final int? challengeNumber;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final FocusNode _keyboardFocus = FocusNode(
    debugLabel: 'board keyboard focus',
  );
  Cell _selected = const Cell(0, 0);
  Map<Cell, BoardCue> _cues = {};
  Set<Cell> _conflicts = {};
  KnightAnimation _knightAnimation = KnightAnimation.bounce;
  int _knightRestartToken = 0;
  bool _exclusionDragReacted = false;

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
    final activeKnightAnimation = _knightAnimation;
    final activeKnightRestartToken = _knightRestartToken;
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
    final visualChapter =
        widget.playMode == PuzzlePlayMode.challenge
            ? challengeChapterFor(puzzle.tier, widget.challengeNumber ?? 1)
            : chapterForOrder(puzzle.order);
    final themed = RegaliaTheme.forChapter(visualChapter);
    return Theme(
      data: themed,
      child: Builder(
        builder:
            (context) => PopScope(
              onPopInvokedWithResult: (_, __) => widget.controller.stopTimer(),
              child: KeyboardListener(
                autofocus: true,
                focusNode: _keyboardFocus,
                onKeyEvent: _onKey,
                child: Scaffold(
                  appBar: AppBar(
                    leading: const PixelBackButton(),
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${puzzle.tier.label} · ${puzzle.size} × ${puzzle.size}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          widget.playMode == PuzzlePlayMode.challenge
                              ? 'Challenge ${widget.challengeNumber ?? puzzle.order}'
                              : 'Puzzle ${puzzle.order} of 120',
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
                      PixelIconButton(
                        tooltip: 'Rules',
                        onPressed: _openRules,
                        glyph: PixelGlyph.book,
                      ),
                    ],
                    bottom: PreferredSize(
                      preferredSize: const Size.fromHeight(74),
                      child: RepaintBoundary(
                        key: const ValueKey('puzzle-knight-companion-surface'),
                        child: _KnightCompanionBar(
                          key: const ValueKey('puzzle-knight-companion'),
                          animation: activeKnightAnimation,
                          restartToken: activeKnightRestartToken,
                          line: _knightLine(activeKnightAnimation),
                          onCompleted:
                              () => _completeKnightReaction(
                                activeKnightAnimation,
                                activeKnightRestartToken,
                              ),
                        ),
                      ),
                    ),
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
                            cues: _cues,
                            selected: _selected,
                            onCellPressed: _pressCell,
                            onCellExcluded: _excludeCell,
                            onExclusionDragStarted: _beginExclusionDrag,
                            onExclusionDragEnded: _endExclusionDrag,
                          ),
                        );
                        final controls = _Controls(
                          board: board,
                          onUndo: board.undoStack.isEmpty ? null : _undo,
                          onRedo: board.redoStack.isEmpty ? null : _redo,
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
                                  SizedBox(width: 276, child: controls),
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
            ),
      ),
    );
  }

  void _pressCell(Cell cell) {
    final board = widget.controller.boardFor(widget.puzzle);
    final before = board.at(cell);
    setState(() {
      _selected = cell;
      _cues = {};
      _conflicts = {};
    });
    final outcome = widget.controller.cycle(widget.puzzle, cell);
    _reactToMutation(cell, before, board.at(cell), outcome);
    if (outcome != null) _showCompletion(outcome);
  }

  void _excludeCell(Cell cell) {
    final board = widget.controller.boardFor(widget.puzzle);
    if (board.at(cell) == ManualCellState.crown ||
        board.at(cell) == ManualCellState.cross) {
      return;
    }
    setState(() {
      _selected = cell;
      _cues = {};
      _conflicts = {};
    });
    widget.controller.setCell(widget.puzzle, cell, ManualCellState.cross);
    if (!_exclusionDragReacted) {
      _exclusionDragReacted = true;
      _playKnightAnimation(KnightAnimation.defend);
    }
  }

  void _setSelected(ManualCellState state) {
    final board = widget.controller.boardFor(widget.puzzle);
    final before = board.at(_selected);
    setState(() {
      _cues = {};
      _conflicts = {};
    });
    final outcome = widget.controller.setCell(widget.puzzle, _selected, state);
    _reactToMutation(_selected, before, board.at(_selected), outcome);
    if (outcome != null) _showCompletion(outcome);
  }

  void _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final key = event.logicalKey;
    final size = widget.puzzle.size;
    if (HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed) {
      if (key == LogicalKeyboardKey.keyZ &&
          HardwareKeyboard.instance.isShiftPressed) {
        _redo();
      } else if (key == LogicalKeyboardKey.keyZ) {
        _undo();
      } else if (key == LogicalKeyboardKey.keyY) {
        _redo();
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
      _cues = {
        for (final cell in result.inconsistentMarks) cell: BoardCue.checkError,
      };
      _conflicts = {
        for (final conflict in result.conflicts) ...[
          conflict.first,
          conflict.second,
        ],
      };
    });
    _playKnightAnimation(
      result.isValid ? KnightAnimation.dance : KnightAnimation.damage,
    );
    _message(
      result.isValid ? 'Still regal' : 'A contradiction',
      result.message,
      result.isValid ? PixelGlyph.check : PixelGlyph.error,
    );
  }

  void _hint() {
    final deduction = widget.controller.hint(widget.puzzle);
    _playKnightAnimation(KnightAnimation.surprised);
    if (deduction == null) {
      _message(
        'No hint available',
        'Try clearing a mark and checking the board again.',
        PixelGlyph.hint,
      );
      return;
    }
    setState(() {
      _cues = {
        for (final cell in deduction.sources) cell: BoardCue.hintSource,
        for (final cell in deduction.eliminated) cell: BoardCue.hintElimination,
        if (deduction.placement != null)
          deduction.placement!: BoardCue.hintPlacement,
      };
      _conflicts = {};
    });
    _message('A gentle nudge', deduction.explanation, PixelGlyph.hint);
  }

  void _message(String title, String message, PixelGlyph icon) {
    final colors = Theme.of(context).colorScheme;
    final accent = icon == PixelGlyph.error ? colors.error : colors.secondary;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: accent, width: 3),
          ),
          content: Row(
            children: [
              PixelIcon(
                icon,
                color: accent,
                size: 24,
                excludeFromSemantics: true,
              ),
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
          (context) => PixelDialog(
            semanticLabel: 'Reset this attempt?',
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
        _cues = {};
        _conflicts = {};
      });
      _playKnightAnimation(KnightAnimation.surprised);
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

  Future<void> _showCompletion(PuzzleCompletionOutcome outcome) async {
    final board = widget.controller.boardFor(widget.puzzle);
    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => CompletionDialog(
            board: board,
            advancesJourney: outcome.advancedJourney,
            isJourneyComplete: outcome.isJourneyComplete,
            nextLabel: outcome.isChallenge ? 'Next challenge' : null,
            onReplay: () => Navigator.pop(context, 'replay'),
            onNext: () => Navigator.pop(context, 'next'),
          ),
    );
    if (!mounted) return;
    if (action == 'replay') {
      widget.controller.reset(widget.puzzle);
      widget.controller.startTimer(widget.puzzle.id);
      setState(() {
        _selected = const Cell(0, 0);
        _cues = {};
        _conflicts = {};
        _knightAnimation = KnightAnimation.bounce;
        _knightRestartToken++;
      });
    } else if (action == 'next') {
      widget.controller.stopTimer();
      if (!mounted) return;
      Navigator.of(
        context,
      ).pop(outcome.isChallenge || outcome.advancedJourney ? outcome : null);
    }
  }

  void _beginExclusionDrag() {
    _exclusionDragReacted = false;
    widget.controller.beginCellBatch(widget.puzzle);
  }

  void _endExclusionDrag() {
    _exclusionDragReacted = false;
    widget.controller.endCellBatch(widget.puzzle);
  }

  void _undo() {
    final board = widget.controller.boardFor(widget.puzzle);
    if (board.undoStack.isEmpty) return;
    widget.controller.undo(widget.puzzle);
    setState(() {
      _cues = {};
      _conflicts = {};
    });
    _playKnightAnimation(KnightAnimation.surprised);
  }

  void _redo() {
    final board = widget.controller.boardFor(widget.puzzle);
    if (board.redoStack.isEmpty) return;
    final before = List<ManualCellState>.of(board.cells);
    widget.controller.redo(widget.puzzle);
    setState(() {
      _cues = {};
      _conflicts = {};
    });
    final changedCells = <Cell>[
      for (var index = 0; index < board.cells.length; index++)
        if (before[index] != board.cells[index])
          Cell.fromIndex(index, board.size),
    ];
    if (changedCells.isEmpty) return;
    final crowned = changedCells.where(
      (cell) => board.at(cell) == ManualCellState.crown,
    );
    if (crowned.isNotEmpty) {
      final conflicts = widget.controller.ruleEngine.directConflicts(
        widget.puzzle,
        board,
      );
      final damagesKnight = conflicts.any(
        (conflict) =>
            crowned.contains(conflict.first) ||
            crowned.contains(conflict.second),
      );
      _playKnightAnimation(
        damagesKnight ? KnightAnimation.damage : KnightAnimation.attack,
      );
    } else if (changedCells.any(
      (cell) => board.at(cell) == ManualCellState.cross,
    )) {
      _playKnightAnimation(KnightAnimation.defend);
    } else {
      _playKnightAnimation(KnightAnimation.surprised);
    }
  }

  void _reactToMutation(
    Cell cell,
    ManualCellState before,
    ManualCellState after,
    PuzzleCompletionOutcome? outcome,
  ) {
    if (before == after) return;
    if (outcome != null) {
      _playKnightAnimation(KnightAnimation.special);
      return;
    }
    switch (after) {
      case ManualCellState.cross:
        _playKnightAnimation(KnightAnimation.defend);
        return;
      case ManualCellState.empty:
        _playKnightAnimation(KnightAnimation.surprised);
        return;
      case ManualCellState.crown:
        final conflicts = widget.controller.ruleEngine.directConflicts(
          widget.puzzle,
          widget.controller.boardFor(widget.puzzle),
        );
        final damagesKnight = conflicts.any(
          (conflict) => conflict.first == cell || conflict.second == cell,
        );
        _playKnightAnimation(
          damagesKnight ? KnightAnimation.damage : KnightAnimation.attack,
        );
        return;
    }
  }

  void _playKnightAnimation(KnightAnimation animation) {
    if (!mounted) return;
    setState(() {
      _knightAnimation = animation;
      _knightRestartToken++;
    });
  }

  void _completeKnightReaction(KnightAnimation animation, int restartToken) {
    if (!mounted ||
        animation != _knightAnimation ||
        restartToken != _knightRestartToken ||
        animation == KnightAnimation.bounce) {
      return;
    }
    _playKnightAnimation(
      animation == KnightAnimation.special
          ? KnightAnimation.dance
          : KnightAnimation.bounce,
    );
  }

  String _knightLine(KnightAnimation animation) => switch (animation) {
    KnightAnimation.walk => 'The crown-bearer presses onward.',
    KnightAnimation.bounce => 'Ready for your next command.',
    KnightAnimation.attack => 'A crown claims its ground.',
    KnightAnimation.defend => 'That square is guarded.',
    KnightAnimation.damage => 'The ranks clash. Rethink the line.',
    KnightAnimation.special => 'The final sigil ignites!',
    KnightAnimation.surprised => 'A new path reveals itself.',
    KnightAnimation.dance => 'The formation still holds!',
  };
}

class _KnightCompanionBar extends StatelessWidget {
  const _KnightCompanionBar({
    super.key,
    required this.animation,
    required this.restartToken,
    required this.line,
    required this.onCompleted,
  });

  final KnightAnimation animation;
  final int restartToken;
  final String line;
  final VoidCallback onCompleted;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      excludeSemantics: true,
      liveRegion: true,
      label: 'Knight companion. $line',
      child: Container(
        height: 66,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          border: Border.all(color: colors.secondary, width: 2),
          boxShadow: const [
            BoxShadow(color: Color(0x77080d20), offset: Offset(4, 4)),
          ],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 96,
              child: Center(
                child: PixelKnightSprite(
                  key: const ValueKey('puzzle-knight-sprite'),
                  animation: animation,
                  loop: animation == KnightAnimation.bounce,
                  restartToken: restartToken,
                  onCompleted: onCompleted,
                  width: 92,
                  height: 57,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CROWN-BEARER',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.secondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      line,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(height: 1.05),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
          PixelIconButton(
            tooltip: 'Undo (Ctrl+Z)',
            onPressed: onUndo,
            glyph: PixelGlyph.undo,
            style: _toolStyle(context),
          ),
          PixelIconButton(
            tooltip: 'Redo (Ctrl+Y)',
            onPressed: onRedo,
            glyph: PixelGlyph.redo,
            style: _toolStyle(context),
          ),
          PixelIconButton(
            tooltip: 'Reset',
            onPressed: onReset,
            glyph: PixelGlyph.reset,
            style: _toolStyle(context),
          ),
        ],
      ),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: onCheck,
        icon: const PixelIcon(
          PixelGlyph.checklist,
          size: 24,
          excludeFromSemantics: true,
        ),
        label: const Text('Check progress'),
      ),
      const SizedBox(height: 8),
      FilledButton.tonalIcon(
        onPressed: onHint,
        icon: const PixelIcon(
          PixelGlyph.hint,
          size: 24,
          excludeFromSemantics: true,
        ),
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

  static ButtonStyle _toolStyle(BuildContext context) => ButtonStyle(
    backgroundColor: WidgetStatePropertyAll(
      Theme.of(context).colorScheme.surfaceContainerHighest,
    ),
    side: WidgetStatePropertyAll(
      BorderSide(color: Theme.of(context).colorScheme.outline, width: 2),
    ),
  );
}
