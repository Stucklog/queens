import 'package:flutter/material.dart';

class CrownMark extends StatelessWidget {
  const CrownMark({super.key, this.color, this.size = 28});
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: _CrownPainter(color ?? Theme.of(context).colorScheme.primary),
    ),
  );
}

class _CrownPainter extends CustomPainter {
  const _CrownPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / 16;
    final shade = Color.lerp(color, Colors.black, .3)!;
    final highlight = Color.lerp(color, Colors.white, .32)!;
    void pixel(int x, int y, int width, int height, Color fill) {
      canvas.drawRect(
        Rect.fromLTWH(
          (x * unit).roundToDouble(),
          (y * unit).roundToDouble(),
          (width * unit).roundToDouble(),
          (height * unit).roundToDouble(),
        ),
        Paint()
          ..color = fill
          ..isAntiAlias = false,
      );
    }

    pixel(2, 5, 4, 7, shade);
    pixel(7, 2, 4, 10, shade);
    pixel(12, 5, 3, 7, shade);
    pixel(3, 5, 3, 6, color);
    pixel(8, 2, 3, 9, color);
    pixel(12, 5, 3, 6, color);
    pixel(3, 9, 12, 4, color);
    pixel(5, 9, 7, 1, highlight);
    pixel(4, 14, 10, 2, shade);
    pixel(5, 14, 8, 1, color);
  }

  @override
  bool shouldRepaint(_CrownPainter oldDelegate) => oldDelegate.color != color;
}
