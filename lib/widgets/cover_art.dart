import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 占位封面：用调色板画一张渐变 + 几个光斑，同一个 [seed] 总是画出同一张图。
/// 接入 API 后在这里换成网络图片，调色板可以留作加载占位。
class CoverArt extends StatelessWidget {
  const CoverArt({
    super.key,
    required this.palette,
    required this.seed,
    this.radius = 8,
    this.icon,
    this.shadow,
  });

  final List<Color> palette;
  final String seed;
  final double radius;
  final IconData? icon;
  final List<BoxShadow>? shadow;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(radius), boxShadow: shadow),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: CustomPaint(
            painter: _CoverPainter(palette, seed.hashCode),
            child: icon == null
                ? null
                : LayoutBuilder(
                    builder: (context, c) => Center(
                      child: Icon(
                        icon,
                        size: c.maxWidth * 0.36,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _CoverPainter extends CustomPainter {
  _CoverPainter(this.palette, this.seed);

  final List<Color> palette;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rnd = math.Random(seed);
    final angle = rnd.nextDouble() * math.pi * 2;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: palette,
          transform: GradientRotation(angle),
        ).createShader(rect),
    );

    // 几个柔和的光斑，让不同封面之间更容易区分。
    for (var i = 0; i < 3; i++) {
      final c = palette[(i + 1) % palette.length];
      final center = Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height);
      final r = size.shortestSide * (0.25 + rnd.nextDouble() * 0.35);
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..shader = RadialGradient(colors: [c.withValues(alpha: 0.7), c.withValues(alpha: 0)])
              .createShader(Rect.fromCircle(center: center, radius: r)),
      );
    }

    // 细线条纹理。
    final stroke = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.012;
    final ringCenter = Offset(size.width * (0.6 + rnd.nextDouble() * 0.3), size.height * 0.8);
    for (var i = 1; i <= 4; i++) {
      canvas.drawCircle(ringCenter, size.shortestSide * 0.12 * i, stroke);
    }
  }

  @override
  bool shouldRepaint(_CoverPainter old) => old.seed != seed || old.palette != palette;
}
