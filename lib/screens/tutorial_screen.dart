import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../app/branding.dart';
import '../widgets/crown_mark.dart';
import '../widgets/pixel_ui.dart';

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key, required this.controller});
  final AppController controller;

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  late final PageController _pages;
  int _page = 0;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _pages = PageController();
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
            child: TextButton(onPressed: _finish, child: const Text('Skip')),
          ),
          Expanded(
            child: PageView(
              controller: _pages,
              onPageChanged: (value) => setState(() => _page = value),
              children: [_intro(context), _rules(context)],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Row(
              children: [
                for (var index = 0; index < 2; index++)
                  Container(
                    width: index == _page ? 24 : 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color:
                          index == _page
                              ? Theme.of(context).colorScheme.secondary
                              : Theme.of(context).colorScheme.outlineVariant,
                      border: Border.all(
                        color:
                            Theme.of(
                              context,
                            ).colorScheme.surfaceContainerLowest,
                        width: 2,
                      ),
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      if (_page == 1) {
                        _finish();
                      } else {
                        _pages.jumpToPage(_page + 1);
                      }
                    },
                    child: Text(_page == 1 ? 'Continue to story' : 'Next'),
                  ),
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
          child: Center(
            child: PixelPanel(
              borderColor: Theme.of(context).colorScheme.secondary,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                  'Four rules to remember',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                const _TutorialRule(
                  icon: PixelGlyph.row,
                  text: 'Exactly one crown in every row',
                ),
                const _TutorialRule(
                  icon: PixelGlyph.column,
                  text: 'Exactly one crown in every column',
                ),
                const _TutorialRule(
                  icon: PixelGlyph.region,
                  text: 'Exactly one crown in every patterned region',
                ),
                const _TutorialRule(
                  icon: PixelGlyph.spacing,
                  text: 'Crowns may not touch, including diagonally',
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    await widget.controller.finishTutorial();
    if (!mounted) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop(true);
  }
}

class _TutorialRule extends StatelessWidget {
  const _TutorialRule({required this.icon, required this.text});
  final PixelGlyph icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12, right: 4),
    child: PixelPanel(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          PixelIcon(
            icon,
            color: Theme.of(context).colorScheme.secondary,
            size: 24,
            excludeFromSemantics: true,
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(text)),
        ],
      ),
    ),
  );
}
