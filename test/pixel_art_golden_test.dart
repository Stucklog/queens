@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/app/journey.dart';
import 'package:regalia/widgets/pixel_art.dart';

void main() {
  testWidgets('all eight chapter landscapes retain high-detail midnight art', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 840);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          key: const ValueKey('chapter-art-atlas'),
          child: ColoredBox(
            color: const Color(0xff171824),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  for (var row = 0; row < 4; row++)
                    Expanded(
                      child: Row(
                        children: [
                          for (var column = 0; column < 2; column++) ...[
                            if (column > 0) const SizedBox(width: 8),
                            Expanded(
                              child: _ChapterTile(
                                chapter: journeyChapters[row * 2 + column],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const ValueKey('chapter-art-atlas')),
      matchesGoldenFile('goldens/chapter_art_atlas_midnight.png'),
    );
  });
}

class _ChapterTile extends StatelessWidget {
  const _ChapterTile({required this.chapter});

  final JourneyChapter chapter;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0xffeee8d6), width: 2),
    ),
    child: ClipRect(
      child: PixelLandscape(
        chapter: chapter,
        brightness: Brightness.dark,
        sceneKind: PixelSceneKind.chapter,
        placement: PixelArtPlacement.story,
        frame: 3,
      ),
    ),
  );
}
