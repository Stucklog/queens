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
    final unit = size.width / 24;
    final ink = Color.lerp(color, Colors.black, .5)!;
    final shade = Color.lerp(color, Colors.black, .28)!;
    final highlight = Color.lerp(color, Colors.white, .42)!;
    final jewel = Color.lerp(color, Colors.white, .68)!;
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

    void polygon(List<Offset> points, Color fill) {
      final path = Path();
      final first = points.first;
      path.moveTo(
        (first.dx * unit).roundToDouble(),
        (first.dy * unit).roundToDouble(),
      );
      for (final point in points.skip(1)) {
        path.lineTo(
          (point.dx * unit).roundToDouble(),
          (point.dy * unit).roundToDouble(),
        );
      }
      path.close();
      canvas.drawPath(
        path,
        Paint()
          ..color = fill
          ..isAntiAlias = false,
      );
    }

    polygon(const [
      Offset(2, 17),
      Offset(2, 8),
      Offset(7, 12),
      Offset(9, 5),
      Offset(12, 12),
      Offset(15, 3),
      Offset(17, 12),
      Offset(22, 7),
      Offset(22, 17),
      Offset(21, 21),
      Offset(3, 21),
    ], ink);
    polygon(const [
      Offset(4, 16),
      Offset(4, 11),
      Offset(8, 14),
      Offset(9, 8),
      Offset(12, 14),
      Offset(15, 6),
      Offset(17, 14),
      Offset(20, 10),
      Offset(20, 16),
      Offset(19, 18),
      Offset(5, 18),
    ], color);
    polygon(const [
      Offset(4, 15),
      Offset(4, 11),
      Offset(8, 14),
      Offset(9, 8),
      Offset(10, 13),
      Offset(8, 16),
    ], highlight);
    polygon(const [
      Offset(15, 6),
      Offset(17, 14),
      Offset(20, 10),
      Offset(20, 16),
      Offset(17, 16),
    ], shade);
    pixel(3, 15, 19, 6, ink);
    pixel(5, 16, 15, 3, color);
    pixel(6, 16, 9, 1, highlight);
    pixel(5, 19, 15, 2, shade);
    pixel(7, 17, 2, 2, jewel);
    pixel(11, 17, 2, 2, shade);
    pixel(15, 17, 2, 2, jewel);
  }

  @override
  bool shouldRepaint(_CrownPainter oldDelegate) => oldDelegate.color != color;
}
