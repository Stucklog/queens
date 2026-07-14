import 'package:flutter/material.dart';

import '../widgets/crown_mark.dart';

class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('How to play')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 48),
      children: [
        const Center(child: CrownMark(size: 72)),
        const SizedBox(height: 24),
        Text(
          'Rule the board',
          style: Theme.of(context).textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        const _Rule(
          icon: Icons.table_rows_rounded,
          title: 'One per row',
          body: 'Every row holds exactly one crown.',
        ),
        const _Rule(
          icon: Icons.view_column_rounded,
          title: 'One per column',
          body: 'Every column holds exactly one crown.',
        ),
        const _Rule(
          icon: Icons.palette_outlined,
          title: 'One per region',
          body: 'Each colored, outlined region holds exactly one crown.',
        ),
        const _Rule(
          icon: Icons.open_with_rounded,
          title: 'Crowns need space',
          body:
              'Crowns cannot touch, even at a corner. Diagonal alignment farther apart is allowed.',
        ),
        const _Rule(
          icon: Icons.touch_app_outlined,
          title: 'Mark your thinking',
          body:
              'Tap a cell to cycle empty → X → crown → empty, or drag across cells to mark them X. Soft dots are automatic exclusions and do not count as assistance.',
        ),
      ],
    ),
  );
}

class _Rule extends StatelessWidget {
  const _Rule({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: ListTile(
      contentPadding: const EdgeInsets.all(16),
      leading: Icon(icon, color: Theme.of(context).colorScheme.secondary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(body),
      ),
    ),
  );
}
