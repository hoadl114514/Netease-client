import 'package:flutter/material.dart';

import '../../api/netease_api.dart';
import '../../data/models.dart';
import '../../state/player_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cover_art.dart';
import '../../widgets/song_tile.dart';

/// 歌曲列表页的通用骨架：头部 + 下拉刷新 + 加载 / 失败 / 空状态 + 歌曲列表。
/// 歌单、专辑、每日推荐、最近播放共用。
class TrackListView extends StatefulWidget {
  const TrackListView({
    super.key,
    required this.load,
    required this.queueTitle,
    required this.header,
    this.reloadKey,
    this.emptyText = '这里还没有歌曲',
    this.trailingFor,
  });

  final Future<List<Song>> Function() load;

  /// 播放时的队列标题。
  final String queueTitle;

  /// [playAll] 在歌曲加载完之前为 null。
  final Widget Function(BuildContext context, List<Song> tracks, VoidCallback? playAll) header;

  /// 变化时重新加载。
  final Object? reloadKey;
  final String emptyText;

  /// 每行右侧的附加信息（如听歌排行的播放次数）。
  final String? Function(int index)? trailingFor;

  @override
  State<TrackListView> createState() => _TrackListViewState();
}

class _TrackListViewState extends State<TrackListView> {
  late Future<List<Song>> _tracks = widget.load();

  @override
  void didUpdateWidget(TrackListView old) {
    super.didUpdateWidget(old);
    if (old.reloadKey != widget.reloadKey) _tracks = widget.load();
  }

  Future<void> _reload() async {
    setState(() => _tracks = widget.load());
    await _tracks.catchError((_) => <Song>[]);
  }

  void _play(List<Song> tracks, int i) =>
      PlayerScope.read(context).playQueue(tracks, start: i, title: widget.queueTitle);

  @override
  Widget build(BuildContext context) {
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
                child: widget.header(
                  context,
                  tracks,
                  tracks.isEmpty ? null : () => _play(tracks, 0),
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
                  child: ErrorState(error: snap.error!, onRetry: _reload),
                )
              else if (tracks.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      widget.emptyText,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                )
              else
                SliverList.builder(
                  itemCount: tracks.length,
                  itemBuilder: (context, i) => SongTile(
                    song: tracks[i],
                    index: i + 1,
                    trailing: widget.trailingFor?.call(i),
                    onTap: () => _play(tracks, i),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],
          ),
        );
      },
    );
  }
}

/// 列表页头部：封面、标题、几行说明、「播放全部」和附加按钮。
class CollectionHeader extends StatelessWidget {
  const CollectionHeader({
    super.key,
    required this.title,
    required this.seed,
    this.coverUrl,
    this.palette,
    this.icon,
    this.lines = const [],
    this.onPlayAll,
    this.actions = const [],
    this.circular = false,
  });

  final String title;
  final String seed;
  final String? coverUrl;
  final List<Color>? palette;

  /// 没有封面图时的占位图标。
  final IconData? icon;
  final List<String> lines;
  final VoidCallback? onPlayAll;
  final List<Widget> actions;

  /// 圆形头像（歌手页）。
  final bool circular;

  @override
  Widget build(BuildContext context) {
    final cover = SizedBox(
      width: 112,
      child: CoverArt(
        palette: palette ?? fallbackPalette(seed),
        seed: seed,
        imageUrl: coverUrl,
        icon: icon,
        radius: circular ? 56 : AppRadius.panel,
        shadow: AppShadows.medium,
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          cover,
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                for (final l in lines) ...[
                  const SizedBox(height: 4),
                  Text(
                    l,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: onPlayAll,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('播放全部'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.onAccent,
                      ),
                    ),
                    ...actions,
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final text = error is ApiException ? (error as ApiException).message : '$error';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '加载失败：$text',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}
