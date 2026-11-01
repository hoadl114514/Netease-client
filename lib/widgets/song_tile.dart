import 'package:flutter/material.dart';

import '../data/format.dart';
import '../data/models.dart';
import '../state/player_controller.dart';
import '../theme/app_theme.dart';
import 'cover_art.dart';

/// 歌曲列表的一行。正在播放的那首标题高亮。
class SongTile extends StatelessWidget {
  const SongTile({super.key, required this.song, required this.onTap, this.index, this.trailing});

  final Song song;
  final VoidCallback onTap;

  /// 序号（从 1 开始）。为 null 时不显示。
  final int? index;

  /// 替代右侧时长显示的文字（如播放次数）。
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final playing = PlayerScope.of(context).current?.id == song.id;
    final titleColor = playing ? AppColors.accent : AppColors.textPrimary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            if (index != null)
              SizedBox(
                width: 32,
                child: Text(
                  '$index',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ),
            SizedBox(
              width: 44,
              child: CoverArt(
                palette: song.palette,
                seed: song.id,
                imageUrl: song.coverUrl,
                radius: 4,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      text: song.title,
                      children: [
                        if (song.subtitle case final s?)
                          TextSpan(
                            text: '  $s',
                            style: const TextStyle(color: AppColors.textMuted),
                          ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, color: titleColor),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [song.artist, if (song.album.isNotEmpty) song.album].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              trailing ?? formatDuration(song.duration),
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
