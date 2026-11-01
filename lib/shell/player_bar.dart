import 'package:flutter/material.dart';

import '../data/format.dart';
import '../pages/now_playing/now_playing_page.dart';
import '../state/player_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/cover_art.dart';
import '../widgets/hover_builder.dart';
import '../widgets/round_icon_button.dart';

/// 底部播放条。顶边是一条可拖动的细进度条。
class PlayerBar extends StatelessWidget {
  const PlayerBar({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final player = PlayerScope.of(context);
    final song = player.song;

    final info = HoverBuilder(
      onTap: () => openNowPlaying(context),
      builder: (context, hovered) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 52,
            child: Stack(
              children: [
                Hero(
                  tag: 'now-playing-cover',
                  child: CoverArt(palette: song.palette, seed: song.id, radius: 6),
                ),
                if (hovered)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  song.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final like = RoundIconButton(
      icon: player.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
      color: player.isLiked ? AppColors.accent : null,
      onPressed: player.toggleLike,
      tooltip: player.isLiked ? '取消喜欢' : '喜欢',
      size: 32,
    );

    final playButton = RoundIconButton(
      icon: player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
      onPressed: player.toggle,
      tooltip: player.isPlaying ? '暂停' : '播放',
      size: compact ? 40 : 48,
      iconSize: compact ? 24 : 28,
      filled: true,
      background: AppColors.accent,
      color: AppColors.onAccent,
    );

    return Container(
      color: AppColors.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _SeekLine(),
          SizedBox(
            height: compact ? 64 : 76,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 20),
              child: compact
                  ? Row(
                      children: [
                        Expanded(child: info),
                        like,
                        const SizedBox(width: 4),
                        playButton,
                        RoundIconButton(
                          icon: Icons.skip_next_rounded,
                          onPressed: player.next,
                          size: 40,
                          iconSize: 26,
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(child: info),
                              const SizedBox(width: 8),
                              like,
                              RoundIconButton(
                                icon: Icons.playlist_add_rounded,
                                onPressed: () {},
                                tooltip: '收藏到歌单',
                                size: 32,
                              ),
                            ],
                          ),
                        ),
                        RoundIconButton(
                          icon: Icons.skip_previous_rounded,
                          onPressed: player.previous,
                          tooltip: '上一首',
                          iconSize: 26,
                        ),
                        const SizedBox(width: 12),
                        playButton,
                        const SizedBox(width: 12),
                        RoundIconButton(
                          icon: Icons.skip_next_rounded,
                          onPressed: player.next,
                          tooltip: '下一首',
                          iconSize: 26,
                        ),
                        const Expanded(child: _RightControls()),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RightControls extends StatelessWidget {
  const _RightControls();

  @override
  Widget build(BuildContext context) {
    final player = PlayerScope.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          '${formatDuration(player.position)} / ${formatDuration(player.song.duration)}',
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: 12),
        Tooltip(
          message: '音质',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.outline),
              borderRadius: BorderRadius.circular(AppRadius.tag),
            ),
            child: const Text('无损', style: TextStyle(fontSize: 12)),
          ),
        ),
        const SizedBox(width: 4),
        RoundIconButton(
          icon: Icons.lyrics_outlined,
          onPressed: () => openNowPlaying(context, showLyrics: true),
          tooltip: '歌词',
        ),
        RoundIconButton(icon: Icons.queue_music_rounded, onPressed: () {}, tooltip: '播放列表'),
        RoundIconButton(
          icon: player.volume == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded,
          onPressed: () => player.setVolume(player.volume == 0 ? 0.7 : 0),
          tooltip: '音量',
        ),
        SizedBox(
          width: 96,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
            ),
            child: Slider(value: player.volume, onChanged: player.setVolume),
          ),
        ),
      ],
    );
  }
}

/// 播放条顶部的细进度线。悬停时加粗，点击或拖动跳转。
class _SeekLine extends StatefulWidget {
  const _SeekLine();

  @override
  State<_SeekLine> createState() => _SeekLineState();
}

class _SeekLineState extends State<_SeekLine> {
  bool _hovered = false;
  double? _dragFraction;

  @override
  Widget build(BuildContext context) {
    final player = PlayerScope.of(context);
    final fraction = _dragFraction ?? player.progress;

    return LayoutBuilder(
      builder: (context, c) {
        double toFraction(double dx) => (dx / c.maxWidth).clamp(0.0, 1.0);
        void commit(double f) => player.seek(player.song.duration * f);

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) => commit(toFraction(d.localPosition.dx)),
            onHorizontalDragUpdate: (d) =>
                setState(() => _dragFraction = toFraction(d.localPosition.dx)),
            onHorizontalDragEnd: (_) {
              if (_dragFraction case final f?) commit(f);
              setState(() => _dragFraction = null);
            },
            child: SizedBox(
              height: 8,
              child: Align(
                alignment: Alignment.topLeft,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  height: _hovered || _dragFraction != null ? 4 : 2,
                  color: Colors.white.withValues(alpha: 0.08),
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: fraction,
                    heightFactor: 1,
                    child: const ColoredBox(color: AppColors.accent),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
