import 'package:flutter/material.dart';

import '../pages/now_playing/now_playing_page.dart';
import '../state/player_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/cover_art.dart';
import '../widgets/like_button.dart';
import '../widgets/round_icon_button.dart';

/// 底部迷你播放条。顶边是一条可点按、拖动的细进度条，点歌曲信息进入播放页。
/// 队列为空时不显示。
class PlayerBar extends StatelessWidget {
  const PlayerBar({super.key});

  @override
  Widget build(BuildContext context) {
    final player = PlayerScope.of(context);
    final song = player.current;
    if (song == null) return const SizedBox.shrink();

    return Material(
      color: AppColors.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _SeekLine(),
          SizedBox(
            height: 64,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => openNowPlaying(context),
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 48,
                            child: Hero(
                              tag: 'now-playing-cover',
                              child: CoverArt(
                                palette: song.palette,
                                seed: song.id,
                                imageUrl: song.coverUrl,
                                radius: 6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
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
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  LikeButton(songId: song.id),
                  const SizedBox(width: 4),
                  RoundIconButton(
                    icon: player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    onPressed: player.toggle,
                    tooltip: player.isPlaying ? '暂停' : '播放',
                    size: 40,
                    iconSize: 24,
                    filled: true,
                    background: AppColors.accent,
                    color: AppColors.onAccent,
                  ),
                  RoundIconButton(
                    icon: Icons.lyrics_outlined,
                    onPressed: () => openNowPlaying(context, showLyrics: true),
                    tooltip: '歌词',
                    size: 40,
                    iconSize: 22,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 播放条顶部的细进度线。按住时加粗，点按或拖动跳转。
class _SeekLine extends StatefulWidget {
  const _SeekLine();

  @override
  State<_SeekLine> createState() => _SeekLineState();
}

class _SeekLineState extends State<_SeekLine> {
  double? _dragFraction;

  @override
  Widget build(BuildContext context) {
    final player = PlayerScope.of(context);
    final fraction = _dragFraction ?? player.progress;

    return LayoutBuilder(
      builder: (context, c) {
        double toFraction(double dx) => (dx / c.maxWidth).clamp(0.0, 1.0);
        void commit(double f) => player.seek(player.duration * f);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) => commit(toFraction(d.localPosition.dx)),
          onHorizontalDragStart: (d) =>
              setState(() => _dragFraction = toFraction(d.localPosition.dx)),
          onHorizontalDragUpdate: (d) =>
              setState(() => _dragFraction = toFraction(d.localPosition.dx)),
          onHorizontalDragEnd: (_) {
            if (_dragFraction case final f?) commit(f);
            setState(() => _dragFraction = null);
          },
          // 触控热区 12px，可见线条 2px（拖动时 4px）。
          child: SizedBox(
            height: 12,
            child: Align(
              alignment: Alignment.topLeft,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                height: _dragFraction != null ? 4 : 2,
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
        );
      },
    );
  }
}
