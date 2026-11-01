import 'package:flutter/material.dart';

import '../api/netease_api.dart';
import '../app/app.dart';
import '../data/models.dart';
import '../shell/player_bar.dart';
import '../state/player_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/cover_art.dart';
import '../widgets/song_tile.dart';
import 'library/playlist_page.dart';
import 'music/artist_page.dart';
import 'music/nav.dart';

/// 搜索：单曲 / 歌单 / 歌手 / 专辑四个标签，各自滚到底自动加载下一页。
class SearchPage extends StatefulWidget {
  const SearchPage({super.key, required this.keyword});

  final String keyword;

  static Future<void> open(BuildContext context, String keyword) {
    final k = keyword.trim();
    if (k.isEmpty) return Future.value();
    return Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => SearchPage(keyword: k)));
  }

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final _input = TextEditingController(text: widget.keyword);
  late String _keyword = widget.keyword;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _search(String keyword) {
    final k = keyword.trim();
    if (k.isEmpty || k == _keyword) return;
    setState(() => _keyword = k);
  }

  @override
  Widget build(BuildContext context) {
    final api = AppScope.of(context).api;
    final k = _keyword;
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: TextField(
            controller: _input,
            autofocus: false,
            textInputAction: TextInputAction.search,
            onSubmitted: _search,
            decoration: const InputDecoration(hintText: '搜索音乐、歌手', border: InputBorder.none),
          ),
          actions: [
            IconButton(
              onPressed: () => _search(_input.text),
              tooltip: '搜索',
              icon: const Icon(Icons.search_rounded),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: '单曲'),
              Tab(text: '歌单'),
              Tab(text: '歌手'),
              Tab(text: '专辑'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _PagedResults<Song>(
              key: ValueKey('song:$k'),
              noun: '歌曲',
              fetch: (offset) async {
                final r = await api.searchSongs(k, limit: _pageSize, offset: offset);
                return (items: r.songs, total: r.total);
              },
              itemBuilder: (context, items, i) => SongTile(
                song: items[i],
                onTap: () =>
                    PlayerScope.read(context).playQueue(List.of(items), start: i, title: '搜索：$k'),
              ),
            ),
            _PagedResults<Playlist>(
              key: ValueKey('playlist:$k'),
              noun: '歌单',
              fetch: (offset) => api.searchPlaylists(k, limit: _pageSize, offset: offset),
              itemBuilder: (context, items, i) => _PlaylistTile(playlist: items[i]),
            ),
            _PagedResults<Artist>(
              key: ValueKey('artist:$k'),
              noun: '歌手',
              fetch: (offset) => api.searchArtists(k, limit: _pageSize, offset: offset),
              itemBuilder: (context, items, i) => _ArtistTile(artist: items[i]),
            ),
            _PagedResults<Album>(
              key: ValueKey('album:$k'),
              noun: '专辑',
              fetch: (offset) => api.searchAlbums(k, limit: _pageSize, offset: offset),
              itemBuilder: (context, items, i) => AlbumTile(album: items[i]),
            ),
          ],
        ),
        bottomNavigationBar: const SafeArea(top: false, child: PlayerBar()),
      ),
    );
  }
}

const _pageSize = 30;

/// 分页结果列表：首次进入加载第一页，滚到底加载下一页。
class _PagedResults<T> extends StatefulWidget {
  const _PagedResults({
    super.key,
    required this.noun,
    required this.fetch,
    required this.itemBuilder,
  });

  final String noun;
  final Future<({List<T> items, int total})> Function(int offset) fetch;
  final Widget Function(BuildContext context, List<T> items, int index) itemBuilder;

  @override
  State<_PagedResults<T>> createState() => _PagedResultsState<T>();
}

class _PagedResultsState<T> extends State<_PagedResults<T>> with AutomaticKeepAliveClientMixin {
  final List<T> _items = [];
  int _total = 0;
  bool _loading = false;
  bool _started = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  bool get _hasMore => !_started || _items.length < _total;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final r = await widget.fetch(_items.length);
      if (!mounted) return;
      setState(() {
        _started = true;
        _items.addAll(r.items);
        // 服务端偶尔少给一页，以实际拿到的为准，避免无限加载。
        _total = r.items.isEmpty ? _items.length : r.total;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.extentAfter < 400 && _hasMore && !_loading && _error == null) _loadMore();
        return false;
      },
      child: ListView.builder(
        itemCount: _items.length + 1,
        itemBuilder: (context, i) {
          if (i < _items.length) return widget.itemBuilder(context, _items, i);
          return _Footer(
            loading: _loading,
            error: _error,
            empty: _started && _items.isEmpty,
            done: !_hasMore,
            noun: widget.noun,
            onRetry: _loadMore,
          );
        },
      ),
    );
  }
}

class _PlaylistTile extends StatelessWidget {
  const _PlaylistTile({required this.playlist});

  final Playlist playlist;

  @override
  Widget build(BuildContext context) {
    final p = playlist;
    return ListTile(
      leading: SizedBox(
        width: 52,
        child: CoverArt(palette: p.palette, seed: p.id, imageUrl: p.coverUrl, radius: 6),
      ),
      title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        ['${p.trackCount} 首', ?p.creator].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppColors.textSecondary),
      ),
      onTap: () => SubPage.push(context, PlaylistPage(playlist: p)),
    );
  }
}

class _ArtistTile extends StatelessWidget {
  const _ArtistTile({required this.artist});

  final Artist artist;

  @override
  Widget build(BuildContext context) {
    final a = artist;
    return ListTile(
      leading: SizedBox(
        width: 52,
        child: CoverArt(
          palette: fallbackPalette(a.id),
          seed: a.id,
          imageUrl: a.avatarUrl,
          radius: 26,
          icon: Icons.person_rounded,
        ),
      ),
      title: Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '单曲 ${a.songCount} · 专辑 ${a.albumCount}',
        style: const TextStyle(color: AppColors.textSecondary),
      ),
      onTap: () => openArtist(context, ArtistRef(a.id, a.name)),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.loading,
    required this.error,
    required this.empty,
    required this.done,
    required this.noun,
    required this.onRetry,
  });

  final bool loading;
  final String? error;
  final bool empty;
  final bool done;
  final String noun;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(color: AppColors.textMuted);
    final Widget child;
    if (loading) {
      child = const SizedBox.square(
        dimension: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (error != null) {
      child = TextButton(onPressed: onRetry, child: Text('$error，点击重试'));
    } else if (empty) {
      child = Text('没有找到相关$noun', style: style);
    } else if (done) {
      child = const Text('没有更多了', style: style);
    } else {
      child = const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(child: child),
    );
  }
}
