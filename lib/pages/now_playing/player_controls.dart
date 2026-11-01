import 'package:flutter/material.dart';

import '../../data/format.dart';
import '../../state/player_controller.dart';
import '../../widgets/round_icon_button.dart';

/// 白色细进度条，时间显示在下方两端。拖动时不跟随播放进度，松手再跳转。
class SeekBar extends StatefulWidget {
  const SeekBar({super.key});

  @override
  State<SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<SeekBar> {
  double? _dragging;

  @override
  Widget build(BuildContext context) {
    final player = PlayerScope.of(context);
    final total = player.duration;
    final value = _dragging ?? player.progress;
    const timeStyle = TextStyle(
      fontSize: 12,
      color: Colors.white70,
      fontFeatures: [FontFeature.tabularFigures()],
    );

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white24,
            thumbColor: Colors.white,
            overlayColor: Colors.white12,
            thumbShape: RoundSliderThumbShape(enabledThumbRadius: _dragging == null ? 6 : 8),
            // 让轨道和下面的时间左右对齐。
            padding: EdgeInsets.zero,
          ),
          child: SizedBox(
            height: 24,
            child: Slider(
              value: value,
              onChanged: (v) => setState(() => _dragging = v),
              onChangeEnd: (v) {
                player.seek(total * v);
                setState(() => _dragging = null);
              },
            ),
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(formatDuration(total * value), style: timeStyle),
            Text('-${formatDuration(total * (1 - value))}', style: timeStyle),
          ],
        ),
      ],
    );
  }
}

/// 白底黑图标的大播放键。
class PlayPauseButton extends StatelessWidget {
  const PlayPauseButton({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    final player = PlayerScope.of(context);
    return RoundIconButton(
      icon: player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
      onPressed: player.toggle,
      tooltip: player.isPlaying ? '暂停' : '播放',
      filled: true,
      background: Colors.white,
      color: Colors.black,
      size: size,
      iconSize: size * 0.55,
    );
  }
}

/// 播放页的底色渐变：顶部是封面主色，向下逐渐压暗。
BoxDecoration backdropDecoration(Color color) => BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [color, Color.lerp(color, Colors.black, 0.55)!],
  ),
);
