import 'package:flutter/painting.dart';

/// 从封面调色板挑一个"主色"做播放页背景，再压到较暗的亮度，保证白色文字始终可读。
///
/// 调色板按占比排序，优先用第一个色；如果它接近黑白灰（不够鲜艳），改用最鲜艳的那个。
Color backdropColorFor(List<Color> palette) {
  assert(palette.isNotEmpty);
  final colors = palette.map(HSLColor.fromColor).toList();
  final pick = _vividness(colors.first) >= _minVividness
      ? colors.first
      : colors.reduce((a, b) => _vividness(b) > _vividness(a) ? b : a);
  return pick.withSaturation(pick.saturation.clamp(0.0, 0.6)).withLightness(0.32).toColor();
}

const _minVividness = 0.15;

/// 饱和度高、亮度适中的颜色得分更高；接近黑白灰的颜色得分低。
double _vividness(HSLColor c) => c.saturation * (1 - (c.lightness - 0.5).abs() * 2);
