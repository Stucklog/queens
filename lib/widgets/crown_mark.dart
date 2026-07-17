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

  static const designSize = 32.0;

  void scaleCanvas(Canvas canvas, Size size) {
    canvas.scale(size.width / designSize, size.height / designSize);
  }

  Paint fill(Color color) =>
      Paint()
        ..color = color
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;

  Paint stroke(Color color, double width) =>
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true;

  Path polygon(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  Path diamond(double centerX, double centerY, double width, double height) =>
      polygon([
        Offset(centerX, centerY - height / 2),
        Offset(centerX + width / 2, centerY),
        Offset(centerX, centerY + height / 2),
        Offset(centerX - width / 2, centerY),
      ]);
}

class _RegaliaBrandPainter extends _CrownPainter {
  const _RegaliaBrandPainter(this.brightness);

  final Brightness brightness;

  @override
  void paint(Canvas canvas, Size size) {
    scaleCanvas(canvas, size);
    const ink = Color(0xff2b1b24);
    const goldDeep = Color(0xff7a4318);
    const goldShadow = Color(0xffb86f20);
    const gold = Color(0xffe0a52f);
    const goldLight = Color(0xffffdc69);
    const dawn = Color(0xfffff3bc);
    const sapphireDeep = Color(0xff193f8c);
    const sapphire = Color(0xff3972d2);
    const sapphireLight = Color(0xffb9d4ff);

    final silhouette = polygon(const [
      Offset(3, 26.5),
      Offset(2.5, 12),
      Offset(7.5, 17),
      Offset(10, 6.5),
      Offset(13.5, 17.5),
      Offset(16, 2.5),
      Offset(18.5, 17.5),
      Offset(22, 6.5),
      Offset(24.5, 17),
      Offset(29.5, 12),
      Offset(29, 26.5),
    ]);
    canvas.drawPath(silhouette, fill(ink));

    final face = polygon(const [
      Offset(4.7, 24),
      Offset(4.4, 14.9),
      Offset(8.5, 19),
      Offset(10.2, 9.7),
      Offset(14.2, 20),
      Offset(16, 6),
      Offset(17.8, 20),
      Offset(21.8, 9.7),
      Offset(23.5, 19),
      Offset(27.6, 14.9),
      Offset(27.3, 24),
    ]);
    canvas.drawPath(face, fill(gold));

    final innerShadow = polygon(const [
      Offset(6.2, 23),
      Offset(6, 18.2),
      Offset(9.1, 21.1),
      Offset(10.4, 13.2),
      Offset(14.8, 22),
      Offset(16, 10.3),
      Offset(17.2, 22),
      Offset(21.6, 13.2),
      Offset(22.9, 21.1),
      Offset(26, 18.2),
      Offset(25.8, 23),
    ]);
    canvas.drawPath(innerShadow, fill(goldShadow));

    final innerLight = polygon(const [
      Offset(7.4, 21.9),
      Offset(9.3, 22.8),
      Offset(10.6, 17.2),
      Offset(14.4, 23),
      Offset(16, 13),
      Offset(17.6, 23),
      Offset(21.4, 17.2),
      Offset(22.7, 22.8),
      Offset(24.6, 21.9),
      Offset(25, 23.5),
      Offset(7, 23.5),
    ]);
    canvas.drawPath(innerLight, fill(goldLight));

    canvas.drawPath(diamond(16, 12.6, 4.8, 8.6), fill(sapphireDeep));
    canvas.drawPath(diamond(16, 12.2, 3.2, 6.4), fill(dawn));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(15.6, 9.8, .8, 4.8),
        const Radius.circular(.4),
      ),
      fill(Colors.white),
    );
    canvas.drawCircle(const Offset(16, 11.7), .55, fill(Colors.white));

    final band = RRect.fromRectAndRadius(
      const Rect.fromLTWH(3, 21.2, 26, 8),
      const Radius.circular(2.2),
    );
    canvas.drawRRect(band, fill(ink));
    final bandFace = RRect.fromRectAndRadius(
      const Rect.fromLTWH(4.4, 22.2, 23.2, 5.5),
      const Radius.circular(1.2),
    );
    canvas.drawRRect(bandFace, fill(gold));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(5.2, 22.8, 21.6, 1.1),
        const Radius.circular(.5),
      ),
      fill(goldLight),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(5.2, 26.1, 21.6, 1),
        const Radius.circular(.5),
      ),
      fill(goldDeep),
    );

    if (size.width >= 38) {
      for (final jewel in const [
        (centerX: 9.3, direction: -1.0),
        (centerX: 22.7, direction: 1.0),
      ]) {
        final centerX = jewel.centerX;
        canvas.drawPath(diamond(centerX, 25, 3.1, 3.8), fill(sapphireDeep));
        canvas.drawPath(diamond(centerX, 24.8, 1.8, 2.4), fill(sapphire));
        canvas.drawCircle(
          Offset(centerX + jewel.direction * .35, 24.2),
          .3,
          fill(sapphireLight),
        );
      }
      canvas.drawPath(diamond(16, 25, 4.4, 4.8), fill(goldDeep));
      canvas.drawPath(diamond(16, 24.8, 2.8, 3.2), fill(dawn));
      canvas.drawCircle(const Offset(16, 24.4), .45, fill(Colors.white));
    } else {
      canvas.drawPath(diamond(16, 24.8, 3.2, 3.6), fill(dawn));
    }

    canvas.drawPath(silhouette, stroke(ink, .65));
    if (brightness == Brightness.dark) {
      canvas.drawPath(silhouette, stroke(dawn.withValues(alpha: .24), .25));
    }
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
    scaleCanvas(canvas, size);
    final ink = Color.lerp(color, Colors.black, .55)!;
    final shade = Color.lerp(color, Colors.black, .24)!;
    final highlight = Color.lerp(color, Colors.white, .5)!;

    final silhouette = polygon(const [
      Offset(3.5, 26.5),
      Offset(3.2, 12),
      Offset(8.4, 17.5),
      Offset(11, 7),
      Offset(14.2, 17.8),
      Offset(16, 3.5),
      Offset(17.8, 17.8),
      Offset(21, 7),
      Offset(23.6, 17.5),
      Offset(28.8, 12),
      Offset(28.5, 26.5),
    ]);
    canvas.drawPath(silhouette, fill(ink));

    final face = polygon(const [
      Offset(5.2, 23.5),
      Offset(5, 15.8),
      Offset(9.3, 20.3),
      Offset(11.1, 10.8),
      Offset(15, 21),
      Offset(16, 8),
      Offset(17, 21),
      Offset(20.9, 10.8),
      Offset(22.7, 20.3),
      Offset(27, 15.8),
      Offset(26.8, 23.5),
    ]);
    canvas.drawPath(face, fill(color));

    final band = RRect.fromRectAndRadius(
      const Rect.fromLTWH(3.5, 21.5, 25, 7.2),
      const Radius.circular(1.8),
    );
    canvas.drawRRect(band, fill(ink));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(5, 22.5, 22, 4.5),
        const Radius.circular(.9),
      ),
      fill(color),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(6.2, 23.1, 19.6, .9),
        const Radius.circular(.45),
      ),
      fill(highlight),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(6.2, 26, 19.6, .8),
        const Radius.circular(.4),
      ),
      fill(shade),
    );
    canvas.drawPath(diamond(16, 24.8, 3, 3.4), fill(highlight));
    canvas.drawPath(silhouette, stroke(ink, .65));
  }

  @override
  bool shouldRepaint(_CrownTokenPainter oldDelegate) =>
      oldDelegate.color != color;
}
