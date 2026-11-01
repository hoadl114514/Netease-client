import 'package:flutter/material.dart';

import '../../data/format.dart';
import '../../state/player_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cover_art.dart';
import '../../widgets/round_icon_button.dart';

/// 播放页左半：大封面、歌曲信息、进度、控制。
class SongInfoPanel extends StatelessWidget {
  const SongInfoPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final player = PlayerScope.of(context);
    final song = player.song;

    Widget meta(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.white60),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, color: Colors.white70),
            ),
          ),
        ],
      ),
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Hero(
                    tag: 'now-playing-cover',
                    child: AnimatedScale(
                      // 暂停时封面略微缩小，给一点"停下来"的反馈。
                      scale: player.isPlaying ? 1 : 0.92,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutBack,
                      child: CoverArt(
                        palette: song.palette,
                        seed: song.id,
                        radius: AppRadius.cover,
                        shadow: AppShadows.heavy,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accentSoft,
                    ),
                  ),
                ),
                RoundIconButton(
                  icon: player.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: player.isLiked ? AppColors.accent : Colors.white70,
                  onPressed: player.toggleLike,
                  tooltip: player.isLiked ? '取消喜欢' : '喜欢',
                  size: 44,
                  iconSize: 26,
                ),
                RoundIconButton(
                  icon: Icons.create_new_folder_rounded,
                  color: Colors.white70,
                  onPressed: () {},
                  tooltip: '收藏到歌单',
                  size: 44,
                  iconSize: 26,
                ),
              ],
            ),
            if (song.tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 6, children: [for (final t in song.tags) _TagPill(t)]),
            ],
            const SizedBox(height: 6),
            meta(Icons.person_rounded, song.artist),
            meta(Icons.album_rounded, song.album),
            const SizedBox(height: 24),
            const _ProgressRow(),
            const SizedBox(height: 16),
            const _Controls(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white38),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Text(label, style: const TextStyle(fontSize: 13, color: Colors.white70)),
    );
  }
}

class _ProgressRow extends StatefulWidget {
  const _ProgressRow();

  @override
  State<_ProgressRow> createState() => _ProgressRowState();
}

class _ProgressRowState extends State<_ProgressRow> {
  /// 拖动中的值；拖动时不跟随播放进度，松手再跳转。
  double? _dragging;

  @override
  Widget build(BuildContext context) {
    final player = PlayerScope.of(context);
    final total = player.song.duration;
    final value = _dragging ?? player.progress;
    const timeStyle = TextStyle(
      fontSize: 13,
      color: Colors.white60,
      fontFeatures: [FontFeature.tabularFigures()],
    );

    return Row(
      children: [
        SizedBox(width: 44, child: Text(formatDuration(total * value), style: timeStyle)),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.accentSoft,
              inactiveTrackColor: Colors.white24,
              thumbColor: AppColors.accentSoft,
            ),
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
        SizedBox(
          width: 44,
          child: Text(formatDuration(total), style: timeStyle, textAlign: TextAlign.right),
        ),
      ],
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls();

  @override
  Widget build(BuildContext context) {
    final player = PlayerScope.of(context);
    // 窄屏时整体等比缩小，而不是溢出。
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RoundIconButton(
            icon: Icons.repeat_rounded,
            onPressed: () {},
            tooltip: '列表循环',
            color: Colors.white54,
            size: 44,
            iconSize: 22,
          ),
          const SizedBox(width: 20),
          RoundIconButton(
            icon: Icons.skip_previous_rounded,
            onPressed: player.previous,
            tooltip: '上一首',
            color: AppColors.accentSoft,
            size: 56,
            iconSize: 36,
          ),
          const SizedBox(width: 20),
          RoundIconButton(
            icon: player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            onPressed: player.toggle,
            tooltip: player.isPlaying ? '暂停' : '播放',
            filled: true,
            background: Colors.white.withValues(alpha: 0.16),
            color: AppColors.accentSoft,
            size: 76,
            iconSize: 40,
          ),
          const SizedBox(width: 20),
          RoundIconButton(
            icon: Icons.skip_next_rounded,
            onPressed: player.next,
            tooltip: '下一首',
            color: AppColors.accentSoft,
            size: 56,
            iconSize: 36,
          ),
          const SizedBox(width: 20),
          RoundIconButton(
            icon: Icons.shuffle_rounded,
            onPressed: () {},
            tooltip: '随机播放',
            color: Colors.white54,
            size: 44,
            iconSize: 22,
          ),
        ],
      ),
    );
  }
}
