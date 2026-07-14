import 'package:flutter/material.dart';

class CrownMark extends StatelessWidget {
  const CrownMark({super.key, this.color, this.size = 28});
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _CrownPainter(color ?? Theme.of(context).colorScheme.primary),
  );
}

class _CrownPainter extends CustomPainter {
  const _CrownPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path =
        Path()
          ..moveTo(size.width * .13, size.height * .34)
          ..lineTo(size.width * .34, size.height * .57)
          ..lineTo(size.width * .5, size.height * .22)
          ..lineTo(size.width * .66, size.height * .57)
          ..lineTo(size.width * .87, size.height * .34)
          ..lineTo(size.width * .78, size.height * .76)
          ..lineTo(size.width * .22, size.height * .76)
          ..close();
    canvas.drawPath(path, paint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * .2,
          size.height * .8,
          size.width * .6,
          size.height * .1,
        ),
        Radius.circular(size.width * .04),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_CrownPainter oldDelegate) => oldDelegate.color != color;
}
