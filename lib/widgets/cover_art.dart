import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../api/netease_api.dart';

/// 封面。有 [imageUrl] 时加载网络图片，加载中或失败时显示用 [palette] 画的占位图；
/// 同一个 [seed] 总是画出同一张占位图。
class CoverArt extends StatelessWidget {
  const CoverArt({
    super.key,
    required this.palette,
    required this.seed,
    this.imageUrl,
    this.radius = 8,
    this.icon,
    this.shadow,
  });

  final List<Color> palette;
  final String seed;
  final String? imageUrl;
  final double radius;
  final IconData? icon;
  final List<BoxShadow>? shadow;

  @override
  Widget build(BuildContext context) {
    final placeholder = CustomPaint(
      painter: _CoverPainter(palette, _stableHash(seed)),
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
    );
    return AspectRatio(
      aspectRatio: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(radius), boxShadow: shadow),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: imageUrl == null
              ? placeholder
              : LayoutBuilder(
                  builder: (context, c) {
                    // 按实际显示尺寸向服务端要图，省流量也省解码内存。
                    final px = (c.maxWidth * MediaQuery.devicePixelRatioOf(context)).ceil().clamp(
                      64,
                      1024,
                    );
                    final bucket = [
                      128,
                      256,
                      512,
                      1024,
                    ].firstWhere((b) => b >= px, orElse: () => 1024);
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        placeholder,
                        Image.network(
                          sizedImage(imageUrl!, bucket),
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          frameBuilder: (_, child, frame, sync) => sync
                              ? child
                              : AnimatedOpacity(
                                  opacity: frame == null ? 0 : 1,
                                  duration: const Duration(milliseconds: 250),
                                  child: child,
                                ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }
}

int _stableHash(String s) {
  var h = 0;
  for (final c in s.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return h;
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
