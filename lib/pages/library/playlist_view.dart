import 'package:flutter/material.dart';

import '../../api/netease_api.dart';
import '../../app/app.dart';
import '../../data/format.dart';
import '../../data/models.dart';
import '../../state/player_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cover_art.dart';
import '../../widgets/song_tile.dart';

/// 歌单内容：头部信息 + 播放全部 + 歌曲列表。歌单页和「我喜欢」共用。
class PlaylistView extends StatefulWidget {
  const PlaylistView({super.key, required this.playlist});

  final Playlist playlist;

  @override
  State<PlaylistView> createState() => _PlaylistViewState();
}

class _PlaylistViewState extends State<PlaylistView> {
  late Future<List<Song>> _tracks = _fetch();

  Future<List<Song>> _fetch() async =>
      (await AppScope.of(context).api.playlistDetail(widget.playlist.id)).tracks;

  @override
  void didUpdateWidget(PlaylistView old) {
    super.didUpdateWidget(old);
    if (old.playlist.id != widget.playlist.id) _tracks = _fetch();
  }

  Future<void> _reload() async {
    setState(() => _tracks = _fetch());
    await _tracks.catchError((_) => <Song>[]);
  }

  void _play(List<Song> tracks, int i) =>
      PlayerScope.read(context).playQueue(tracks, start: i, title: widget.playlist.name);

  @override
  Widget build(BuildContext context) {
    final p = widget.playlist;
    return FutureBuilder<List<Song>>(
      future: _tracks,
      builder: (context, snap) {
        final tracks = snap.data ?? const <Song>[];
        return RefreshIndicator(
          onRefresh: _reload,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 112,
                        child: CoverArt(
                          palette: p.palette,
                          seed: p.id,
                          imageUrl: p.coverUrl,
                          radius: AppRadius.panel,
                          shadow: AppShadows.medium,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              [
                                ?p.creator,
                                '${p.trackCount} 首',
                                '播放 ${formatPlayCount(p.playCount)}',
                              ].join(' · '),
                              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: tracks.isEmpty ? null : () => _play(tracks, 0),
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: const Text('播放全部'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                foregroundColor: AppColors.onAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (snap.connectionState != ConnectionState.done)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (snap.hasError)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _ErrorState(error: snap.error!, onRetry: _reload),
                )
              else if (tracks.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text('歌单是空的', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                )
              else
                SliverList.builder(
                  itemCount: tracks.length,
                  itemBuilder: (context, i) =>
                      SongTile(song: tracks[i], index: i + 1, onTap: () => _play(tracks, i)),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],
          ),
        );
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final text = error is ApiException ? (error as ApiException).message : '$error';
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('加载失败：$text', style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}
