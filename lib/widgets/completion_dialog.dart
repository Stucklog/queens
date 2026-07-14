import 'package:flutter/material.dart';

import '../core/models.dart';
import 'crown_mark.dart';

class CompletionDialog extends StatelessWidget {
  const CompletionDialog({
    super.key,
    required this.board,
    required this.onReplay,
    required this.onNext,
  });

  final BoardState board;
  final VoidCallback onReplay;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => AlertDialog(
    icon: const CrownMark(size: 64),
    title: Text(board.assisted ? 'Board complete' : 'A clean coronation'),
    content: Text(
      board.assisted
          ? 'Solved in ${formatTime(board.elapsedSeconds)} with ${board.hintCount} hint${board.hintCount == 1 ? '' : 's'} and ${board.checkCount} check${board.checkCount == 1 ? '' : 's'}. Replay anytime for a clean crown.'
          : 'Solved without hints or checks in ${formatTime(board.elapsedSeconds)}.',
    ),
    actions: [
      TextButton(onPressed: onReplay, child: const Text('Replay')),
      FilledButton(onPressed: onNext, child: const Text('Next puzzle')),
    ],
  );

  static String formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    return '${minutes.toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}
