import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../api/netease_api.dart';

/// 从封面图里取几个主色，按像素占比从高到低。结果按地址缓存。
abstract final class CoverPalette {
  static final _cache = <String, Future<List<Color>?>>{};

  static Future<List<Color>?> of(String url) => _cache.putIfAbsent(
    url,
    () => _extract(NetworkImage(sizedImage(url, 48))).catchError((_) => null),
  );

  static Future<List<Color>?> _extract(ImageProvider provider) async {
    final completer = Completer<ui.Image>();
    final stream = provider.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        completer.complete(info.image.clone());
        stream.removeListener(listener);
      },
      onError: (e, s) {
        completer.completeError(e, s);
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    final image = await completer.future.timeout(const Duration(seconds: 10));
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return data == null ? null : dominantColors(data.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  }

  /// 把 RGBA 像素按每通道 4 bit 分桶，取占比最高、彼此差异够大的最多 [count] 个颜色。
  static List<Color> dominantColors(List<int> rgba, {int count = 3}) {
    final buckets = <int, ({int n, int r, int g, int b})>{};
    for (var i = 0; i + 3 < rgba.length; i += 4) {
      if (rgba[i + 3] < 128) continue;
      final r = rgba[i], g = rgba[i + 1], b = rgba[i + 2];
      final key = (r >> 4) << 8 | (g >> 4) << 4 | (b >> 4);
      final o = buckets[key];
      buckets[key] = o == null
          ? (n: 1, r: r, g: g, b: b)
          : (n: o.n + 1, r: o.r + r, g: o.g + g, b: o.b + b);
    }
    final sorted = buckets.values.toList()..sort((a, b) => b.n - a.n);
    final out = <Color>[];
    for (final s in sorted) {
      final c = Color.fromARGB(255, s.r ~/ s.n, s.g ~/ s.n, s.b ~/ s.n);
      if (out.every((o) => _distance(o, c) > 48)) out.add(c);
      if (out.length == count) break;
    }
    return out;
  }

  static double _distance(Color a, Color b) {
    final dr = (a.r - b.r) * 255, dg = (a.g - b.g) * 255, db = (a.b - b.b) * 255;
    return dr.abs() + dg.abs() + db.abs();
  }
}
