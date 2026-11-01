import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

/// 播放页背景：从封面调色板取色，几团大光斑缓慢漂移，整体高斯模糊。
class AmbientBackground extends StatefulWidget {
  const AmbientBackground({super.key, required this.palette, this.child});

  final List<Color> palette;
  final Widget? child;

  @override
  State<AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<AmbientBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  )..repeat();

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 取色后压暗，保证白色文字可读。
    final colors = [for (final c in widget.palette) Color.lerp(c, const Color(0xFF1A1418), 0.45)!];
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF1A1418)),
        AnimatedBuilder(
          animation: _drift,
          builder: (context, _) => ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 90, sigmaY: 90, tileMode: TileMode.decal),
            child: CustomPaint(painter: _BlobPainter(colors, _drift.value)),
          ),
        ),
        ColoredBox(color: Colors.black.withValues(alpha: 0.22)),
        ?widget.child,
      ],
    );
  }
}

class _BlobPainter extends CustomPainter {
  _BlobPainter(this.colors, this.t);

  final List<Color> colors;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    const anchors = [Offset(0.15, 0.2), Offset(0.85, 0.15), Offset(0.75, 0.85), Offset(0.2, 0.8)];
    for (var i = 0; i < anchors.length; i++) {
      final phase = t * math.pi * 2 + i * 1.7;
      final a = anchors[i];
      final center = Offset(
        size.width * (a.dx + 0.08 * math.sin(phase)),
        size.height * (a.dy + 0.08 * math.cos(phase * 0.8)),
      );
      canvas.drawCircle(
        center,
        size.longestSide * 0.38,
        Paint()..color = colors[i % colors.length].withValues(alpha: 0.85),
      );
    }
  }

  @override
  bool shouldRepaint(_BlobPainter old) => old.t != t || old.colors != colors;
}
