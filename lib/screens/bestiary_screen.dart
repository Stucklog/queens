import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../app/bestiary.dart';
import '../app/journey.dart';
import '../app/theme.dart';
import '../content/content_models.dart';
import '../core/models.dart';
import '../widgets/combat_presentation.dart';
import '../widgets/pixel_ui.dart';

const _debugBestiaryUnlockAllBuildFlag = bool.fromEnvironment(
  'REGALIA_ENABLE_DEBUG_BESTIARY_UNLOCK_ALL',
  // Make the animation-review control available in ordinary debug launches.
  // It remains impossible to show in profile or release builds because
  // [_debugUnlockAllAvailable] also requires [kDebugMode].
  defaultValue: true,
);

class BestiaryScreen extends StatefulWidget {
  const BestiaryScreen({
    super.key,
    required this.controller,
    this.debugUnlockAllEnabledOverride,
  });

  final AppController controller;

  /// Test seam for the temporary preview control.
  ///
  /// [kDebugMode] is still required, so this cannot enable the control in a
  /// profile or release build.
  @visibleForTesting
  final bool? debugUnlockAllEnabledOverride;

  @override
  State<BestiaryScreen> createState() => _BestiaryScreenState();
}

class _BestiaryScreenState extends State<BestiaryScreen> {
  bool _showAllFoesForThisVisit = false;

  bool get _debugUnlockAllAvailable =>
      kDebugMode &&
      (widget.debugUnlockAllEnabledOverride ??
          _debugBestiaryUnlockAllBuildFlag);

  bool get _showAllFoes => _debugUnlockAllAvailable && _showAllFoesForThisVisit;

  CompletionRecord _recordFor(String puzzleId) =>
      _showAllFoes
          ? const CompletionRecord(status: CompletionStatus.cleanSolved)
          : widget.controller.recordFor(puzzleId);

  void _unlockAllForThisVisit() {
    if (!_debugUnlockAllAvailable || _showAllFoesForThisVisit) return;
    setState(() => _showAllFoesForThisVisit = true);
  }

  @override
  void didUpdateWidget(covariant BestiaryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_debugUnlockAllAvailable) _showAllFoesForThisVisit = false;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: const PixelBackButton(),
      title: const Text('Bestiary'),
    ),
    body: SafeArea(
      top: false,
      child: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final arcs = [
            for (final arc in widget.controller.availableStoryArcs)
              BestiaryArcProgress.derive(arc: arc, recordFor: _recordFor),
          ];
          final total = arcs.fold<int>(
            0,
            (value, arc) => value + arc.totalCount,
          );
          final defeated = arcs.fold<int>(
            0,
            (value, arc) => value + arc.defeatedCount,
          );
          return ListView(
            key: const ValueKey('bestiary-list'),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              _BestiaryHeader(
                defeated: defeated,
                total: total,
                showDebugUnlockAll: _debugUnlockAllAvailable,
                allFoesVisibleForThisVisit: _showAllFoes,
                onDebugUnlockAll: _unlockAllForThisVisit,
              ),
              const SizedBox(height: 18),
              if (arcs.isEmpty)
                const PixelPanel(
                  child: Text(
                    'No story bestiary is available in this edition.',
                  ),
                )
              else
                for (final arc in arcs) ...[
                  _ArcBestiarySection(progress: arc),
                  const SizedBox(height: 20),
                ],
            ],
          );
        },
      ),
    ),
  );
}

class _BestiaryHeader extends StatelessWidget {
  const _BestiaryHeader({
    required this.defeated,
    required this.total,
    required this.showDebugUnlockAll,
    required this.allFoesVisibleForThisVisit,
    required this.onDebugUnlockAll,
  });

  final int defeated;
  final int total;
  final bool showDebugUnlockAll;
  final bool allFoesVisibleForThisVisit;
  final VoidCallback onDebugUnlockAll;

  @override
  Widget build(BuildContext context) => PixelPanel(
    borderColor: Theme.of(context).colorScheme.secondary,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'The Crown-Bearer’s Bestiary',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Defeat story foes to reveal them, then study every movement in their battle atlas.',
        ),
        const SizedBox(height: 16),
        PixelProgressBar(
          value: total == 0 ? 0 : defeated / total,
          segments: total == 0 ? 1 : total,
          semanticLabel: 'Bestiary progress',
          semanticValue: '$defeated of $total foes defeated',
        ),
        const SizedBox(height: 8),
        Text(
          '$defeated / $total foes revealed',
          key: const ValueKey('bestiary-total-progress'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (showDebugUnlockAll) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            key: const ValueKey('bestiary-debug-unlock-all'),
            onPressed: allFoesVisibleForThisVisit ? null : onDebugUnlockAll,
            icon: PixelIcon(
              allFoesVisibleForThisVisit ? PixelGlyph.check : PixelGlyph.lock,
              color: Theme.of(context).colorScheme.secondary,
              size: 24,
              excludeFromSemantics: true,
            ),
            label: Text(
              allFoesVisibleForThisVisit
                  ? 'All Foes Visible for This Visit'
                  : 'Unlock All Foes (Debug)',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Temporary animation preview. Saved progress stays unchanged.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    ),
  );
}

class _ArcBestiarySection extends StatelessWidget {
  const _ArcBestiarySection({required this.progress});

  final BestiaryArcProgress progress;

  @override
  Widget build(BuildContext context) => Column(
    key: ValueKey('bestiary-arc-${progress.arc.id}'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text(
              progress.arc.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${progress.defeatedCount} / ${progress.totalCount}',
            key: ValueKey('bestiary-arc-progress-${progress.arc.id}'),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      LayoutBuilder(
        builder: (context, constraints) {
          const spacing = 12.0;
          final twoColumns = constraints.maxWidth >= 520;
          final cardWidth =
              twoColumns
                  ? (constraints.maxWidth - spacing) / 2
                  : constraints.maxWidth;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final chapter in progress.chapters)
                SizedBox(
                  width: cardWidth,
                  child: _ChapterBestiaryPanel(
                    arc: progress.arc,
                    progress: chapter,
                  ),
                ),
            ],
          );
        },
      ),
    ],
  );
}

class _ChapterBestiaryPanel extends StatelessWidget {
  const _ChapterBestiaryPanel({required this.arc, required this.progress});

  final StoryArc arc;
  final BestiaryChapterProgress progress;

  @override
  Widget build(BuildContext context) {
    final chapter = progress.chapter;
    final colors = Theme.of(context).colorScheme;
    final accent = RegaliaTheme.readableAccent(
      preferred: chapter.palette.secondary,
      background: colors.surface,
    );
    return PixelPanel(
      key: ValueKey('bestiary-chapter-${chapter.id}'),
      padding: const EdgeInsets.all(12),
      borderColor: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  chapter.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${progress.defeatedCount}/${progress.foes.length}',
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: accent),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < progress.foes.length; index++) ...[
            _FoeSlot(
              slotKey: ValueKey(
                'bestiary-slot-${arc.id}-${chapter.visualIndex}-$index',
              ),
              chapter: chapter,
              entry: progress.foes[index],
              accent: accent,
            ),
            if (index + 1 < progress.foes.length) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _FoeSlot extends StatelessWidget {
  const _FoeSlot({
    required this.slotKey,
    required this.chapter,
    required this.entry,
    required this.accent,
  });

  final Key slotKey;
  final JourneyChapter chapter;
  final BestiaryFoeEntry entry;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    if (!entry.defeated) {
      return Semantics(
        key: slotKey,
        container: true,
        label: 'Undiscovered foe. Defeat this story encounter to reveal it.',
        child: ExcludeSemantics(
          child: Container(
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: ShapeDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              shape: PixelOrganicBorder.compact(
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  width: 2,
                ),
              ),
            ),
            child: Row(
              children: [
                PixelIcon(
                  PixelGlyph.lock,
                  size: 32,
                  color: Theme.of(context).colorScheme.outline,
                  excludeFromSemantics: true,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '???',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Text('Undiscovered foe'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final encounter = entry.encounter;
    return Semantics(
      key: slotKey,
      button: true,
      excludeSemantics: true,
      label:
          '${encounter.isBoss ? 'Boss' : 'Enemy'} ${encounter.name}. Open animation study.',
      child: Material(
        color: Colors.transparent,
        shape: PixelOrganicBorder.compact(
          side: BorderSide(color: accent, width: 2),
        ),
        clipBehavior: Clip.hardEdge,
        child: InkWell(
          key: ValueKey('open-bestiary-foe-${encounter.id}'),
          onTap:
              () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder:
                      (_) => BestiaryFoeScreen(
                        encounter: encounter,
                        chapter: chapter,
                      ),
                ),
              ),
          customBorder: const PixelOrganicBorder.compact(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
            child: Row(
              children: [
                PixelEnemySprite.preview(
                  key: ValueKey('bestiary-thumbnail-${encounter.id}'),
                  encounter: encounter,
                  reaction: EnemyReaction.idle,
                  frame: 0,
                  width: 62,
                  height: 62,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        encounter.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        encounter.isBoss ? 'Boss · Defeated' : 'Foe · Defeated',
                        style: Theme.of(
                          context,
                        ).textTheme.labelSmall?.copyWith(color: accent),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                PixelIcon(
                  PixelGlyph.arrowRight,
                  color: accent,
                  size: 24,
                  excludeFromSemantics: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BestiaryFoeScreen extends StatefulWidget {
  const BestiaryFoeScreen({
    super.key,
    required this.encounter,
    required this.chapter,
  });

  final CombatEncounter encounter;
  final JourneyChapter chapter;

  @override
  State<BestiaryFoeScreen> createState() => _BestiaryFoeScreenState();
}

class _BestiaryFoeScreenState extends State<BestiaryFoeScreen> {
  EnemyReaction _reaction = EnemyReaction.idle;
  int _restartToken = 0;

  void _replay(EnemyReaction reaction) {
    setState(() {
      _reaction = reaction;
      _restartToken++;
    });
  }

  void _resumeIdle(EnemyReaction completedReaction, int restartToken) {
    if (!mounted ||
        completedReaction == EnemyReaction.idle ||
        completedReaction == EnemyReaction.defeated ||
        _reaction != completedReaction ||
        _restartToken != restartToken) {
      return;
    }
    setState(() => _reaction = EnemyReaction.idle);
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: RegaliaTheme.forChapter(widget.chapter),
    child: Builder(
      builder:
          (context) => Scaffold(
            appBar: AppBar(
              leading: const PixelBackButton(),
              title: Text(widget.encounter.name),
            ),
            body: SafeArea(
              top: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 520;
                  final stage = _ReactionStage(
                    encounter: widget.encounter,
                    reaction: _reaction,
                    restartToken: _restartToken,
                    onCompleted: _resumeIdle,
                  );
                  final controls = _ReactionControls(
                    selected: _reaction,
                    onReplay: _replay,
                  );
                  return SingleChildScrollView(
                    key: const ValueKey('bestiary-foe-scroll'),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child:
                            wide
                                ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: stage),
                                    const SizedBox(width: 16),
                                    Expanded(child: controls),
                                  ],
                                )
                                : Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    stage,
                                    const SizedBox(height: 16),
                                    controls,
                                  ],
                                ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
    ),
  );
}

class _ReactionStage extends StatelessWidget {
  const _ReactionStage({
    required this.encounter,
    required this.reaction,
    required this.restartToken,
    required this.onCompleted,
  });

  final CombatEncounter encounter;
  final EnemyReaction reaction;
  final int restartToken;
  final void Function(EnemyReaction reaction, int restartToken) onCompleted;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: true,
    label: '${encounter.name}. ${reaction.replayLabel} animation.',
    child: ExcludeSemantics(
      child: PixelPanel(
        key: const ValueKey('bestiary-reaction-stage'),
        borderColor: Theme.of(context).colorScheme.secondary,
        child: Column(
          children: [
            Text(
              encounter.isBoss ? 'DEFEATED BOSS' : 'DEFEATED FOE',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              encounter.name,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 208,
              child: Center(
                child: PixelEnemySprite.preview(
                  key: const ValueKey('bestiary-replay-sprite'),
                  encounter: encounter,
                  reaction: reaction,
                  restartToken: restartToken,
                  onCompleted:
                      reaction == EnemyReaction.defeated
                          ? null
                          : () => onCompleted(reaction, restartToken),
                  width: 196,
                  height: 196,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              reaction.label,
              key: const ValueKey('bestiary-reaction-label'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ReactionControls extends StatelessWidget {
  const _ReactionControls({required this.selected, required this.onReplay});

  final EnemyReaction selected;
  final ValueChanged<EnemyReaction> onReplay;

  @override
  Widget build(BuildContext context) => PixelPanel(
    key: const ValueKey('bestiary-reaction-controls'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Replay animations',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        const Text(
          'Moves play once, then idle resumes. Defeat holds on its last frame.',
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 8.0;
            final buttonWidth = (constraints.maxWidth - spacing) / 2;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final reaction in EnemyReaction.values)
                  SizedBox(
                    width: buttonWidth,
                    child:
                        reaction == selected
                            ? FilledButton(
                              key: ValueKey(
                                'bestiary-reaction-${reaction.name}',
                              ),
                              onPressed: () => onReplay(reaction),
                              child: Text(reaction.replayLabel),
                            )
                            : OutlinedButton(
                              key: ValueKey(
                                'bestiary-reaction-${reaction.name}',
                              ),
                              onPressed: () => onReplay(reaction),
                              child: Text(reaction.replayLabel),
                            ),
                  ),
              ],
            );
          },
        ),
      ],
    ),
  );
}
