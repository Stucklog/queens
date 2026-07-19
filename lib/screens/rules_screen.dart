import 'package:flutter/material.dart';

import '../widgets/crown_mark.dart';
import '../widgets/pixel_ui.dart';

class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: const PixelBackButton(),
      title: const Text('How to play'),
    ),
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
          icon: PixelGlyph.row,
          title: 'One per row',
          body: 'Every row holds exactly one crown.',
        ),
        const _Rule(
          icon: PixelGlyph.column,
          title: 'One per column',
          body: 'Every column holds exactly one crown.',
        ),
        const _Rule(
          icon: PixelGlyph.region,
          title: 'One per region',
          body: 'Each patterned, outlined region holds exactly one crown.',
        ),
        const _Rule(
          icon: PixelGlyph.spacing,
          title: 'Crowns need space',
          body:
              'Crowns cannot touch, even at a corner. Diagonal alignment farther apart is allowed.',
        ),
        const _Rule(
          icon: PixelGlyph.tap,
          title: 'Mark your thinking',
          body:
              'Tap a cell to cycle empty > X > crown > empty, or drag across cells to mark them X. After a crown is placed, matching X marks show automatic exclusions; they do not count as assistance.',
        ),
      ],
    ),
  );
}

class _Rule extends StatelessWidget {
  const _Rule({required this.icon, required this.title, required this.body});
  final PixelGlyph icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16, right: 4),
    child: PixelPanel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PixelIcon(
            icon,
            color: Theme.of(context).colorScheme.secondary,
            size: 32,
            excludeFromSemantics: true,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(body),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
