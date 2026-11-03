import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../api/netease_api.dart';
import 'retry_image.dart';

/// 封面。有 [imageUrl] 时加载网络图片，加载中或失败时显示用 [palette] 画的占位图；
/// 同一个 [seed] 总是画出同一张占位图。
///
/// 加载失败时依次重试：原图地址（不带裁剪参数）→ [fallbackImage] 给的备用图（例如歌单第一首歌的封面）。
/// [imageUrl] 为 null 时直接用备用图。
class CoverArt extends StatefulWidget {
  const CoverArt({
    super.key,
    required this.palette,
    required this.seed,
    this.imageUrl,
    this.fallbackImage,
    this.radius = 8,
    this.icon,
    this.shadow,
  });

  final List<Color> palette;
  final String seed;
  final String? imageUrl;

  /// 主图没有或加载失败时取备用图地址；同一个 [imageUrl] 只调用一次。
  final Future<String?> Function()? fallbackImage;
  final double radius;
  final IconData? icon;
  final List<BoxShadow>? shadow;

  @override
  State<CoverArt> createState() => _CoverArtState();
}

class _CoverArtState extends State<CoverArt> {
  /// 当前在试的图片地址和是否带裁剪参数。
  String? _url;
  bool _sized = true;
  bool _usingFallback = false;
  bool _fallbackRequested = false;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void didUpdateWidget(CoverArt old) {
    super.didUpdateWidget(old);
    if (old.imageUrl != widget.imageUrl) _reset();
  }

  void _reset() {
    _url = widget.imageUrl;
    _sized = true;
    _usingFallback = false;
    _fallbackRequested = false;
    if (_url == null) _requestFallback();
  }

  Future<void> _requestFallback() async {
    final fetch = widget.fallbackImage;
    if (fetch == null || _fallbackRequested) return;
    _fallbackRequested = true;
    final forUrl = widget.imageUrl;
    String? url;
    try {
      url = await fetch();
    } catch (_) {
      url = null;
    }
    if (!mounted || forUrl != widget.imageUrl || url == null || url == widget.imageUrl) return;
    setState(() {
      _url = url;
      _sized = true;
      _usingFallback = true;
    });
  }

  /// 当前地址加载失败：先去掉裁剪参数再试一次，还不行就换备用图。
  void _onError(String failed, bool sized) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || failed != _url || sized != _sized) return;
      if (_sized) {
        setState(() => _sized = false);
      } else if (!_usingFallback) {
        setState(() => _url = null);
        _requestFallback();
      } else {
        setState(() => _url = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final placeholder = CustomPaint(
      painter: _CoverPainter(widget.palette, _stableHash(widget.seed)),
      child: widget.icon == null
          ? null
          : LayoutBuilder(
              builder: (context, c) => Center(
                child: Icon(
                  widget.icon,
                  size: c.maxWidth * 0.36,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ),
    );
    final url = _url;
    final sized = _sized;
    return AspectRatio(
      aspectRatio: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          boxShadow: widget.shadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.radius),
          child: url == null
              ? placeholder
              : LayoutBuilder(
                  builder: (context, c) {
                    // 按实际显示尺寸向服务端要图，省流量也省解码内存。
                    final width = c.maxWidth.isFinite ? c.maxWidth : 300.0;
                    final px = (width * MediaQuery.devicePixelRatioOf(context)).ceil().clamp(
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
                        Image(
                          // 原图可能很大，解码时按显示尺寸缩小。
                          image: retryImage(
                            sized ? sizedImage(url, bucket) : url,
                            cacheWidth: sized ? null : px,
                          ),
                          key: ValueKey('$url|$sized'),
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          errorBuilder: (_, _, _) {
                            _onError(url, sized);
                            return const SizedBox.shrink();
                          },
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
