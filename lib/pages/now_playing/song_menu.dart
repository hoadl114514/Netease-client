import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../state/player_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cover_art.dart';

/// 播放页 / 歌词页右上角「更多」：歌曲操作 + 歌词偏移。
Future<void> showSongMenu(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  backgroundColor: AppColors.surfaceHigh,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => const _SongMenu(),
);

class _SongMenu extends StatelessWidget {
  const _SongMenu();

  static const _step = Duration(milliseconds: 500);

  @override
  Widget build(BuildContext context) {
    final player = PlayerScope.of(context);
    final song = player.song;
    final offset = player.lyricOffset.inMilliseconds / 1000;
    final active = player.activeLyricIndex;

    Widget item(IconData icon, String label, {VoidCallback? onTap}) => ListTile(
      leading: Icon(icon, color: AppColors.textPrimary),
      title: Text(label),
      onTap: onTap ?? () => Navigator.of(context).pop(),
    );

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: SizedBox(
              width: 48,
              child: CoverArt(palette: song.palette, seed: song.id, radius: 4),
            ),
            title: Text(song.title, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(song.artist),
          ),
          const Divider(),
          item(Icons.playlist_add_rounded, '收藏到歌单'),
          item(Icons.person_outline_rounded, '查看歌手'),
          item(Icons.album_outlined, '查看专辑'),
          item(Icons.bedtime_outlined, '定时关闭'),
          item(
            Icons.copy_rounded,
            '复制当前歌词',
            onTap: active < 0
                ? null
                : () {
                    final line = song.lyrics[active];
                    Clipboard.setData(
                      ClipboardData(text: [line.text, ?line.translation, ?line.romaji].join('\n')),
                    );
                    Navigator.of(context).pop();
                  },
          ),
          ListTile(
            leading: const Icon(Icons.av_timer_rounded, color: AppColors.textPrimary),
            title: const Text('歌词偏移'),
            subtitle: const Text('歌词和声音对不上时调整'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => player.adjustLyricOffset(-_step),
                  tooltip: '歌词延后 0.5s',
                  icon: const Icon(Icons.remove_rounded),
                ),
                GestureDetector(
                  onTap: player.resetLyricOffset,
                  child: SizedBox(
                    width: 48,
                    child: Text(
                      offset == 0 ? '0s' : '${offset > 0 ? '+' : ''}${offset.toStringAsFixed(1)}s',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => player.adjustLyricOffset(_step),
                  tooltip: '歌词提前 0.5s',
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
