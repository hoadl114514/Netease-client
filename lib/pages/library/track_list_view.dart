import 'package:flutter/material.dart';

import '../../api/netease_api.dart';
import '../../data/models.dart';
import '../../state/player_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cover_art.dart';
import '../../widgets/image_viewer.dart';
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
    this.sourceId,
    this.emptyText = '这里还没有歌曲',
    this.trailingFor,
    this.searchable = true,
  });

  final Future<List<Song>> Function() load;

  /// 播放时的队列标题。
  final String queueTitle;

  /// 来源歌单 / 专辑 id，上报最近播放时带上。
  final String? sourceId;

  /// [playAll] 在歌曲加载完之前为 null。
  final Widget Function(BuildContext context, List<Song> tracks, VoidCallback? playAll) header;

  /// 变化时重新加载。
  final Object? reloadKey;
  final String emptyText;

  /// 每行右侧的附加信息（如听歌排行的播放次数）。
  final String? Function(int index)? trailingFor;

  /// 在头部下面显示「搜索列表内歌曲」的输入框。
  final bool searchable;

  @override
  State<TrackListView> createState() => _TrackListViewState();
}

class _TrackListViewState extends State<TrackListView> {
  late Future<List<Song>> _tracks = widget.load();
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

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
      PlayerScope.read(context)
          .playQueue(tracks, start: i, title: widget.queueTitle, sourceId: widget.sourceId);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Song>>(
      future: _tracks,
      builder: (context, snap) {
        final tracks = snap.data ?? const <Song>[];
        final loaded = snap.connectionState == ConnectionState.done && !snap.hasError;
        // 搜索时只显示匹配的行，序号和点播放仍按完整列表。
        final shown = _query.isEmpty
            ? null
            : [
                for (var i = 0; i < tracks.length; i++)
                  if (songMatches(tracks[i], _query)) i,
              ];
        return RefreshIndicator(
          onRefresh: _reload,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverToBoxAdapter(
                child: widget.header(
                  context,
                  tracks,
                  tracks.isEmpty ? null : () => _play(tracks, 0),
                ),
              ),
              if (widget.searchable && loaded && tracks.isNotEmpty)
                SliverToBoxAdapter(
                  child: ListSearchField(
                    controller: _search,
                    hint: '搜索列表内 ${tracks.length} 首歌曲',
                    matched: shown?.length,
                    onChanged: (v) => setState(() => _query = v.trim()),
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
              else if (shown != null && shown.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text('没有匹配的歌曲', style: TextStyle(color: AppColors.textSecondary)),
                    ),
                  ),
                )
              else
                SliverList.builder(
                  itemCount: shown?.length ?? tracks.length,
                  itemBuilder: (context, n) {
                    final i = shown?[n] ?? n;
                    return SongTile(
                      song: tracks[i],
                      index: i + 1,
                      trailing: widget.trailingFor?.call(i),
                      onTap: () => _play(tracks, i),
                    );
                  },
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],
          ),
        );
      },
    );
  }
}

/// 列表上方的搜索框。[matched] 不为 null 时在右侧显示匹配数和清空按钮。
class ListSearchField extends StatelessWidget {
  const ListSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.matched,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final int? matched;

  @override
  Widget build(BuildContext context) {
    final m = matched;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: AppColors.surfaceHigh,
          hintText: hint,
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          suffixIcon: m == null
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$m 个结果',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                    IconButton(
                      tooltip: '清空',
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        controller.clear();
                        onChanged('');
                      },
                    ),
                  ],
                ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }
}

/// [query] 按空格分成几个词，每个词都要出现在歌名、别名、歌手或专辑里（不区分大小写）。
bool songMatches(Song song, String query) {
  final text = [song.title, ?song.subtitle, song.artist, song.album].join('\n').toLowerCase();
  return query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).every(text.contains);
}

/// 列表页头部：封面、标题、几行说明、「播放全部」和附加按钮。
class CollectionHeader extends StatelessWidget {
  const CollectionHeader({
    super.key,
    required this.title,
    required this.seed,
    this.coverUrl,
    this.fallbackCover,
    this.palette,
    this.icon,
    this.lines = const [],
    this.onPlayAll,
    this.actions = const [],
    this.circular = false,
    this.link,
  });

  final String title;
  final String seed;
  final String? coverUrl;

  /// 封面没有或加载失败时的备用图。
  final Future<String?> Function()? fallbackCover;
  final List<Color>? palette;

  /// 没有封面图时的占位图标。
  final IconData? icon;
  final List<String> lines;
  final VoidCallback? onPlayAll;
  final List<Widget> actions;

  /// 圆形头像（歌手页）。
  final bool circular;

  /// 标题下面一行可以点的文字，例如歌单创建者（点了进用户主页）。
  final ({String text, VoidCallback onTap})? link;

  @override
  Widget build(BuildContext context) {
    final cover = SizedBox(
      width: 112,
      child: ViewableImage(
        url: coverUrl,
        title: title,
        child: CoverArt(
          palette: palette ?? fallbackPalette(seed),
          seed: seed,
          imageUrl: coverUrl,
          fallbackImage: fallbackCover,
          icon: icon,
          radius: circular ? 56 : AppRadius.panel,
          shadow: AppShadows.medium,
        ),
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
                if (link case final l?) ...[
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: l.onTap,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            l.text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ],
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
