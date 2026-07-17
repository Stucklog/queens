import 'package:flutter/material.dart';

enum CrownMarkStyle { brand, token }

class CrownMark extends StatelessWidget {
  const CrownMark({
    super.key,
    this.color,
    this.size = 28,
    CrownMarkStyle? style,
  }) : style =
           style ??
           (color == null ? CrownMarkStyle.brand : CrownMarkStyle.token);

  final Color? color;
  final double size;
  final CrownMarkStyle style;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter:
          style == CrownMarkStyle.brand
              ? _RegaliaBrandPainter(Theme.of(context).brightness)
              : _CrownTokenPainter(
                color ?? Theme.of(context).colorScheme.primary,
              ),
    ),
  );
}

abstract class _CrownPainter extends CustomPainter {
  const _CrownPainter();

  static const designSize = 16.0;

  static const _halfPattern = <String>[
    '       K',
    '      KI',
    '   KK KG',
    '   KI KG',
    'KK KG KG',
    'KI KG KG',
    'KLGNLGNG',
    ' KGGGGGG',
    '  KLGGGG',
    '  KDDDDD',
    ' KKKKKKK',
    'KKLGGGGG',
    'KGGSSGGS',
    'KLGHBGLB',
    ' KDDDDDD',
    '  KKKKKK',
  ];

  void paintPixels(
    Canvas canvas,
    Size size,
    Color Function(String value) colorFor,
  ) {
    if (size.isEmpty) return;
    final paint =
        Paint()
          ..style = PaintingStyle.fill
          ..isAntiAlias = false;
    for (var y = 0; y < _halfPattern.length; y++) {
      final row = _halfPattern[y];
      final top = (y * size.height / designSize).roundToDouble();
      final bottom = ((y + 1) * size.height / designSize).roundToDouble();
      for (var x = 0; x < row.length; x++) {
        final value = row[x];
        if (value == ' ') continue;
        final left = (x * size.width / designSize).roundToDouble();
        final right = ((x + 1) * size.width / designSize).roundToDouble();
        paint.color = colorFor(value);
        canvas.drawRect(Rect.fromLTRB(left, top, right, bottom), paint);
        canvas.drawRect(
          Rect.fromLTRB(size.width - right, top, size.width - left, bottom),
          paint,
        );
      }
    }
  }
}

class _RegaliaBrandPainter extends _CrownPainter {
  const _RegaliaBrandPainter(this.brightness);

  final Brightness brightness;

  @override
  void paint(Canvas canvas, Size size) {
    const midnightInk = Color(0xff080d20);
    const navy = Color(0xff253052);
    const goldDeep = Color(0xff8b531b);
    const gold = Color(0xffd6a53b);
    const goldLight = Color(0xffffd35a);
    const ivory = Color(0xfffff3dc);
    const sapphireDeep = Color(0xff153f84);
    const sapphire = Color(0xff3b78d1);
    const sapphireLight = Color(0xffb9d7ff);
    paintPixels(
      canvas,
      size,
      (value) => switch (value) {
        'K' =>
          brightness == Brightness.dark ? midnightInk : const Color(0xff151126),
        'N' => navy,
        'D' => goldDeep,
        'G' => gold,
        'L' => goldLight,
        'I' => ivory,
        'S' => sapphireDeep,
        'B' => sapphire,
        'H' => sapphireLight,
        _ => Colors.transparent,
      },
    );
  }

  @override
  bool shouldRepaint(_RegaliaBrandPainter oldDelegate) =>
      oldDelegate.brightness != brightness;
}

class _CrownTokenPainter extends _CrownPainter {
  const _CrownTokenPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final ink = Color.lerp(color, Colors.black, .72)!;
    final edge = Color.lerp(color, Colors.black, .52)!;
    final shade = Color.lerp(color, Colors.black, .3)!;
    final highlight = Color.lerp(color, Colors.white, .28)!;
    final bright = Color.lerp(color, Colors.white, .62)!;
    final jewelShade = Color.lerp(color, Colors.black, .48)!;
    final jewel = Color.lerp(color, Colors.white, .08)!;
    final jewelLight = Color.lerp(color, Colors.white, .48)!;
    paintPixels(
      canvas,
      size,
      (value) => switch (value) {
        'K' => ink,
        'N' => edge,
        'D' => shade,
        'G' => color,
        'L' => highlight,
        'I' => bright,
        'S' => jewelShade,
        'B' => jewel,
        'H' => jewelLight,
        _ => Colors.transparent,
      },
    );
  }

  @override
  bool shouldRepaint(_CrownTokenPainter oldDelegate) =>
      oldDelegate.color != color;
}
