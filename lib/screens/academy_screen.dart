import 'package:flutter/material.dart';

import '../app/academy.dart';
import '../app/app_controller.dart';
import '../app/theme.dart';
import '../core/models.dart';
import '../widgets/pixel_ui.dart';
import 'game_screen.dart';

class AcademyScreen extends StatelessWidget {
  const AcademyScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: const PixelBackButton(),
      title: const Text('Academy'),
    ),
    body: SafeArea(
      top: false,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final lessons = controller.academyLessons;
          final completed = controller.academyCompletedCount;
          return ListView(
            key: const ValueKey('academy-lesson-list'),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              PixelPanel(
                borderColor: Theme.of(context).colorScheme.secondary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'The Deduction Hall',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Study one idea at a time, inspect its board example, then prove it on a practice puzzle.',
                    ),
                    const SizedBox(height: 16),
                    PixelProgressBar(
                      value: lessons.isEmpty ? 0 : completed / lessons.length,
                      segments: lessons.isEmpty ? 1 : lessons.length,
                      semanticLabel: 'Academy progress',
                      semanticValue:
                          '$completed of ${lessons.length} lessons complete',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$completed / ${lessons.length} lessons mastered',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              for (final lesson in lessons) ...[
                _LessonTile(controller: controller, lesson: lesson),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    ),
  );
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({required this.controller, required this.lesson});

  final AppController controller;
  final AcademyLesson lesson;

  @override
  Widget build(BuildContext context) {
    final unlocked = controller.isAcademyLessonUnlocked(lesson);
    final complete = controller.isAcademyLessonComplete(lesson);
    final colors = Theme.of(context).colorScheme;
    final status =
        complete
            ? 'Mastered'
            : unlocked
            ? 'Ready'
            : 'Locked';
    return Semantics(
      button: unlocked,
      label: 'Lesson ${lesson.order}, ${lesson.title}. $status.',
      child: PixelPanel(
        padding: EdgeInsets.zero,
        borderColor: complete ? colors.secondary : colors.outline,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: ValueKey('academy-lesson-${lesson.order}'),
            onTap:
                unlocked
                    ? () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder:
                            (_) => AcademyLessonScreen(
                              controller: controller,
                              lesson: lesson,
                            ),
                      ),
                    )
                    : null,
            customBorder: const PixelOrganicBorder(),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: ShapeDecoration(
                      color:
                          complete
                              ? colors.secondaryContainer
                              : colors.surfaceContainerHighest,
                      shape: PixelOrganicBorder.compact(
                        side: BorderSide(
                          color: complete ? colors.secondary : colors.outline,
                          width: 2,
                        ),
                      ),
                    ),
                    child:
                        complete
                            ? PixelIcon(
                              PixelGlyph.check,
                              color: colors.secondary,
                              semanticLabel: 'Complete',
                            )
                            : unlocked
                            ? Text(
                              '${lesson.order}',
                              style: Theme.of(context).textTheme.titleLarge,
                            )
                            : PixelIcon(
                              PixelGlyph.lock,
                              color: colors.outline,
                              semanticLabel: 'Locked',
                            ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lesson ${lesson.order} · $status',
                          style: Theme.of(
                            context,
                          ).textTheme.labelLarge?.copyWith(
                            color:
                                complete
                                    ? colors.secondary
                                    : colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          lesson.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          unlocked
                              ? lesson.summary
                              : 'Complete lesson ${lesson.order - 1} to unlock.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (unlocked)
                    PixelIcon(
                      PixelGlyph.arrowRight,
                      color: colors.secondary,
                      excludeFromSemantics: true,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AcademyLessonScreen extends StatefulWidget {
  const AcademyLessonScreen({
    super.key,
    required this.controller,
    required this.lesson,
  });

  final AppController controller;
  final AcademyLesson lesson;

  @override
  State<AcademyLessonScreen> createState() => _AcademyLessonScreenState();
}

class _AcademyLessonScreenState extends State<AcademyLessonScreen> {
  Future<void> _practice() async {
    if (!widget.controller.openAcademyPractice(widget.lesson)) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder:
            (_) => GameScreen(
              controller: widget.controller,
              puzzle: widget.lesson.practicePuzzle,
              playMode: PuzzlePlayMode.academy,
            ),
      ),
    );
    if (mounted) setState(() {});
  }

  void _openNext(AcademyLesson lesson) {
    Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute(
        builder:
            (_) => AcademyLessonScreen(
              controller: widget.controller,
              lesson: lesson,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lesson;
    final lessons = widget.controller.academyLessons;
    final complete = widget.controller.isAcademyLessonComplete(lesson);
    final next = lesson.order < lessons.length ? lessons[lesson.order] : null;
    return Scaffold(
      appBar: AppBar(
        leading: const PixelBackButton(),
        title: Text('Academy · Lesson ${lesson.order}'),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          key: ValueKey('academy-lesson-detail-${lesson.order}'),
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    lesson.title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                if (complete)
                  PixelIcon(
                    PixelGlyph.check,
                    color: Theme.of(context).colorScheme.secondary,
                    semanticLabel: 'Lesson complete',
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              lesson.summary,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 18),
            PixelPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'The technique',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(lesson.explanation),
                  const SizedBox(height: 14),
                  for (var index = 0; index < lesson.steps.length; index++) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${index + 1}.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.secondary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(lesson.steps[index])),
                      ],
                    ),
                    if (index != lesson.steps.length - 1)
                      const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Board example',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            _AcademyExampleBoard(example: lesson.example),
            const SizedBox(height: 18),
            FilledButton.icon(
              key: const ValueKey('start-academy-practice'),
              onPressed: _practice,
              icon: PixelIcon(
                complete ? PixelGlyph.reset : PixelGlyph.crown,
                size: 24,
                excludeFromSemantics: true,
              ),
              label: Text(complete ? 'Replay practice' : 'Practice technique'),
            ),
            if (complete) ...[
              const SizedBox(height: 12),
              Text(
                next == null
                    ? 'Curriculum complete — every lesson remains open for replay.'
                    : 'Lesson mastered. The next technique is now unlocked.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (next != null) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  key: const ValueKey('continue-academy-lesson'),
                  onPressed: () => _openNext(next),
                  icon: const PixelIcon(
                    PixelGlyph.arrowRight,
                    size: 24,
                    excludeFromSemantics: true,
                  ),
                  label: Text('Continue to lesson ${next.order}'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _AcademyExampleBoard extends StatelessWidget {
  const _AcademyExampleBoard({required this.example});

  final AcademyExample example;

  static const _regionColors = [
    Color(0xff34456c),
    Color(0xff493c69),
    Color(0xff275369),
    Color(0xff58475d),
  ];

  @override
  Widget build(BuildContext context) => Semantics(
    label: example.caption,
    image: true,
    child: ExcludeSemantics(
      child: PixelPanel(
        borderColor: Theme.of(context).colorScheme.secondary,
        child: Column(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Column(
                    children: [
                      for (var row = 0; row < example.size; row++)
                        Expanded(
                          child: Row(
                            children: [
                              for (
                                var column = 0;
                                column < example.size;
                                column++
                              )
                                Expanded(
                                  child: _ExampleCell(
                                    example: example,
                                    cell: Cell(row, column),
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(example.caption, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              children: const [
                _ExampleLegend(color: RegaliaTheme.gold, label: 'deduction'),
                _ExampleLegend(color: Color(0xff73c7dc), label: 'source'),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _ExampleCell extends StatelessWidget {
  const _ExampleCell({required this.example, required this.cell});

  final AcademyExample example;
  final Cell cell;

  @override
  Widget build(BuildContext context) {
    final region = example.regionAt(cell);
    final isTarget = example.targets.contains(cell);
    final isSource = example.sources.contains(cell);
    final base =
        _AcademyExampleBoard._regionColors[region %
            _AcademyExampleBoard._regionColors.length];
    final background =
        isTarget
            ? Color.lerp(base, RegaliaTheme.gold, .58)!
            : isSource
            ? Color.lerp(base, const Color(0xff73c7dc), .45)!
            : base;
    final wall = Theme.of(context).colorScheme.surfaceContainerLowest;
    final seam = Theme.of(context).colorScheme.outlineVariant;
    final topWall =
        cell.row == 0 ||
        example.regionAt(Cell(cell.row - 1, cell.column)) != region;
    final leftWall =
        cell.column == 0 ||
        example.regionAt(Cell(cell.row, cell.column - 1)) != region;
    final bottomWall =
        cell.row == example.size - 1 ||
        example.regionAt(Cell(cell.row + 1, cell.column)) != region;
    final rightWall =
        cell.column == example.size - 1 ||
        example.regionAt(Cell(cell.row, cell.column + 1)) != region;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        border: Border(
          top: BorderSide(color: topWall ? wall : seam, width: topWall ? 3 : 1),
          left: BorderSide(
            color: leftWall ? wall : seam,
            width: leftWall ? 3 : 1,
          ),
          bottom: BorderSide(
            color: bottomWall ? wall : seam,
            width: bottomWall ? 3 : 1,
          ),
          right: BorderSide(
            color: rightWall ? wall : seam,
            width: rightWall ? 3 : 1,
          ),
        ),
      ),
      child: Center(
        child:
            example.crowns.contains(cell)
                ? const PixelIcon(
                  PixelGlyph.crown,
                  color: RegaliaTheme.ivory,
                  size: 32,
                  excludeFromSemantics: true,
                )
                : example.crosses.contains(cell)
                ? const Text(
                  '×',
                  style: TextStyle(
                    color: RegaliaTheme.ivory,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                )
                : isTarget
                ? const Text(
                  '?',
                  style: TextStyle(
                    color: RegaliaTheme.ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                )
                : null,
      ),
    );
  }
}

class _ExampleLegend extends StatelessWidget {
  const _ExampleLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 12, height: 12, color: color),
      const SizedBox(width: 5),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}
