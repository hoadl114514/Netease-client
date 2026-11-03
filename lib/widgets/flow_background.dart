import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../api/netease_api.dart';
import 'backdrop_color.dart';
import 'retry_image.dart';

/// 播放页的"流光"背景：几份封面色块缓慢反向旋转、叠在一起，上面压一层暗色保证白字可读。
///
/// 性能：模糊和提饱和度只在换封面时做一次，离屏画到一张 256px 的贴图里（四周羽化成透明）。
/// 之后每帧只是把这张贴图旋转缩放后画三次，GPU 上就是三次贴图采样，不再有实时的
/// 全屏高斯模糊或 saveLayer。动画约 30fps；系统开启「减少动画」时静止。
class FlowBackground extends StatefulWidget {
  const FlowBackground({super.key, required this.palette, this.imageUrl, required this.child});

  final List<Color> palette;
  final String? imageUrl;
  final Widget child;

  @override
  State<FlowBackground> createState() => _FlowBackgroundState();
}

class _FlowBackgroundState extends State<FlowBackground> with SingleTickerProviderStateMixin {
  static const _frame = Duration(milliseconds: 33);
  static const _textureSize = 256;

  /// 动画时间（秒）。
  final _t = ValueNotifier<double>(0);
  late final _ticker = createTicker(_onTick);
  Duration _lastFrame = Duration.zero;

  /// 预处理好的贴图；换封面期间保留上一张，新的好了再淡入。
  ui.Image? _texture;
  ui.Image? _previous;
  final _fade = ValueNotifier<double>(1);
  String? _loadedUrl;
  List<Color>? _bakedPalette;
  int _generation = 0;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(FlowBackground old) {
    super.didUpdateWidget(old);
    if (old.imageUrl != widget.imageUrl || !listEquals(old.palette, widget.palette)) _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.disableAnimationsOf(context);
    if (still && _ticker.isActive) _ticker.stop();
    if (!still && !_ticker.isActive) unawaited(_ticker.start());
  }

  void _onTick(Duration elapsed) {
    if (elapsed - _lastFrame < _frame) return;
    final dt = (elapsed - _lastFrame).inMicroseconds / 1e6;
    _lastFrame = elapsed;
    _t.value = elapsed.inMicroseconds / 1e6;
    // 新贴图约 0.8 秒淡入。
    if (_fade.value < 1) _fade.value = math.min(1, _fade.value + dt / 0.8);
  }

  void _load() {
    final url = widget.imageUrl;
    if (url == null) {
      // 调色板每次可能是新列表，内容没变就不重做。
      if (_loadedUrl == null && listEquals(_bakedPalette, widget.palette)) return;
      _loadedUrl = null;
      _bakedPalette = widget.palette;
      _unlisten();
      unawaited(_bake(null));
      return;
    }
    if (url == _loadedUrl) return;
    _loadedUrl = url;
    _unlisten();
    final stream = RetryNetworkImage(sizedImage(url, 96)).resolve(ImageConfiguration.empty);
    final listener = ImageStreamListener(
      (info, _) {
        if (_loadedUrl == url) unawaited(_bake(info.image.clone()));
        info.dispose();
      },
      onError: (_, _) {
        if (_loadedUrl == url) unawaited(_bake(null));
      },
    );
    stream.addListener(listener);
    _stream = stream;
    _listener = listener;
  }

  void _unlisten() {
    if (_listener != null) _stream?.removeListener(_listener!);
    _stream = null;
    _listener = null;
  }

  /// 把封面（没有封面时用调色板色块）模糊、提饱和度、四周羽化，画成一张小贴图。只在换图时跑一次。
  Future<void> _bake(ui.Image? cover) async {
    final gen = ++_generation;
    const size = _textureSize;
    const inset = size * 0.18;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()
      ..filterQuality = FilterQuality.medium
      ..colorFilter = _saturate(1.7)
      ..imageFilter = ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18, tileMode: TileMode.decal);
    const dst = Rect.fromLTRB(inset, inset, size - inset, size - inset);
    canvas.saveLayer(const Rect.fromLTWH(0, 0, size + 0.0, size + 0.0), paint);
    if (cover != null) {
      canvas.drawImageRect(
        cover,
        Rect.fromLTWH(0, 0, cover.width.toDouble(), cover.height.toDouble()),
        dst,
        Paint()..filterQuality = FilterQuality.medium,
      );
    } else {
      final colors = widget.palette;
      for (var i = 0; i < colors.length; i++) {
        final a = 2 * math.pi * i / colors.length;
        canvas.drawCircle(
          dst.center + Offset(math.cos(a), math.sin(a)) * dst.width * 0.22,
          dst.width * 0.32,
          Paint()..color = colors[i],
        );
      }
    }
    canvas.restore();
    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    picture.dispose();
    cover?.dispose();
    // 已经卸载，或者期间又换了图（快速切歌）：丢掉这张。
    if (!mounted || gen != _generation) {
      image.dispose();
      return;
    }
    setState(() {
      _previous?.dispose();
      _previous = _texture;
      _texture = image;
      _fade.value = _previous == null ? 1 : 0;
    });
  }

  @override
  void dispose() {
    _unlisten();
    _ticker.dispose();
    _t.dispose();
    _fade.dispose();
    _texture?.dispose();
    _previous?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = backdropColorFor(widget.palette);
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 800),
          color: Color.lerp(base, Colors.black, 0.35),
        ),
        RepaintBoundary(
          child: CustomPaint(
            painter: _FlowPainter(texture: _texture, previous: _previous, time: _t, fade: _fade),
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

/// 每帧把贴图旋转缩放后画三份。贴图已经模糊过，双线性采样放大也不会出锯齿。
class _FlowPainter extends CustomPainter {
  _FlowPainter({
    required this.texture,
    required this.previous,
    required this.time,
    required this.fade,
  }) : super(repaint: Listenable.merge([time, fade]));

  final ui.Image? texture;
  final ui.Image? previous;
  final ValueListenable<double> time;
  final ValueListenable<double> fade;

  /// 周期（秒）、方向、相对屏幕长边的尺寸、中心位置（相对宽高）。
  static const _layers = [
    (period: 120.0, dir: 1.0, scale: 1.25, cx: 0.5, cy: 0.5),
    (period: 70.0, dir: -1.0, scale: 0.9, cx: 0.15, cy: 0.2),
    (period: 90.0, dir: 1.0, scale: 0.85, cx: 0.85, cy: 0.75),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final f = fade.value;
    if (previous != null && f < 1) _draw(canvas, size, previous!, 1);
    if (texture != null) _draw(canvas, size, texture!, f);
  }

  void _draw(Canvas canvas, Size size, ui.Image image, double opacity) {
    final t = time.value;
    final src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final paint = Paint()
      ..filterQuality = FilterQuality.low
      ..color = Color.fromRGBO(0, 0, 0, opacity);
    final side = size.longestSide;
    for (final l in _layers) {
      final d = side * l.scale;
      canvas
        ..save()
        ..translate(size.width * l.cx, size.height * l.cy)
        ..rotate(l.dir * 2 * math.pi * t / l.period);
      canvas.drawImageRect(
        image,
        src,
        Rect.fromCenter(center: Offset.zero, width: d, height: d),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_FlowPainter old) => old.texture != texture || old.previous != previous;
}
