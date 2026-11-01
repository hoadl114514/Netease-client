import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../api/netease_api.dart';
import 'backdrop_color.dart';

/// 播放页的"流光"背景：几层放大、慢速反向旋转、提高饱和度的封面叠在一起再大半径模糊，
/// 得到缓慢流动的色块；上面压一层暗色保证白字可读。
///
/// 为了省电：封面只取 96px 的小图；动画按约 20fps 更新而不是每帧；
/// 系统开启「减少动画」或页面不可见（TickerMode 关闭）时静止。
class FlowBackground extends StatefulWidget {
  const FlowBackground({super.key, required this.palette, this.imageUrl, required this.child});

  final List<Color> palette;
  final String? imageUrl;
  final Widget child;

  @override
  State<FlowBackground> createState() => _FlowBackgroundState();
}

class _FlowBackgroundState extends State<FlowBackground> with SingleTickerProviderStateMixin {
  static const _frame = Duration(milliseconds: 50);

  /// 动画时间（秒），只按 [_frame] 粒度推进。
  final _t = ValueNotifier<double>(0);
  late final _ticker = createTicker(_onTick);
  Duration _lastFrame = Duration.zero;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.disableAnimationsOf(context);
    if (still && _ticker.isActive) _ticker.stop();
    if (!still && !_ticker.isActive) unawaited(_ticker.start());
  }

  void _onTick(Duration elapsed) {
    if (elapsed - _lastFrame < _frame) return;
    _lastFrame = elapsed;
    _t.value = elapsed.inMicroseconds / 1e6;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = backdropColorFor(widget.palette);
    final url = widget.imageUrl;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: Color.lerp(base, Colors.black, 0.35)!),
        RepaintBoundary(
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 60, sigmaY: 60, tileMode: TileMode.decal),
            child: ValueListenableBuilder<double>(
              valueListenable: _t,
              builder: (context, t, _) => AnimatedSwitcher(
                duration: const Duration(milliseconds: 800),
                child: KeyedSubtree(
                  key: ValueKey(url ?? widget.palette),
                  child: url == null ? _blobs(t) : _covers(url, t),
                ),
              ),
            ),
          ),
        ),
        // 中间偏下更暗：控制区和歌词更清楚。
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x40000000), Color(0x66000000), Color(0x99000000)],
            ),
          ),
        ),
        widget.child,
      ],
    );
  }

  /// 三份封面：周期 70 / 90 / 120 秒，方向交替，位置错开。
  Widget _covers(String url, double t) {
    final image = Image.network(
      sizedImage(url, 96),
      fit: BoxFit.cover,
      filterQuality: FilterQuality.low,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => _blobs(t),
    );
    const layers = [
      (period: 70.0, dir: 1.0, scale: 1.9, dx: -0.35, dy: -0.30),
      (period: 90.0, dir: -1.0, scale: 1.6, dx: 0.40, dy: 0.10),
      (period: 120.0, dir: 1.0, scale: 2.2, dx: -0.10, dy: 0.45),
    ];
    return ColorFiltered(
      colorFilter: _saturate(1.7),
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (final l in layers)
            Align(
              alignment: Alignment(l.dx, l.dy),
              child: FractionallySizedBox(
                widthFactor: 1,
                heightFactor: 0.6,
                child: Transform.rotate(
                  angle: l.dir * 2 * math.pi * t / l.period,
                  child: Transform.scale(scale: l.scale, child: image),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 没有封面时：调色板颜色的几个圆形色块绕圈移动。
  Widget _blobs(double t) {
    final colors = widget.palette;
    return CustomPaint(painter: _BlobPainter(colors, t));
  }

  static ColorFilter _saturate(double s) {
    const r = 0.2126, g = 0.7152, b = 0.0722;
    final i = 1 - s;
    return ColorFilter.matrix([
      i * r + s, i * g, i * b, 0, 0, //
      i * r, i * g + s, i * b, 0, 0,
      i * r, i * g, i * b + s, 0, 0,
      0, 0, 0, 1, 0,
    ]);
  }
}

class _BlobPainter extends CustomPainter {
  _BlobPainter(this.colors, this.t);

  final List<Color> colors;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < colors.length; i++) {
      final a = 2 * math.pi * (t / (60 + 20 * i) + i / colors.length);
      final c = Offset(
        size.width * (0.5 + 0.3 * math.cos(a)),
        size.height * (0.4 + 0.25 * math.sin(a)),
      );
      canvas.drawCircle(c, size.shortestSide * 0.55, Paint()..color = colors[i]);
    }
  }

  @override
  bool shouldRepaint(_BlobPainter old) => old.t != t || old.colors != colors;
}
