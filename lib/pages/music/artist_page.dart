import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../data/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cover_art.dart';
import '../library/track_list_view.dart';
import 'nav.dart';

/// 歌手页：两个标签，热门歌曲和专辑。
class ArtistPage extends StatelessWidget {
  const ArtistPage({super.key, required this.artist});

  final ArtistRef artist;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: SubPage(
        title: artist.name,
        body: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: '热门歌曲'),
                Tab(text: '专辑'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _HotSongs(artist: artist),
                  _Albums(artist: artist),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HotSongs extends StatefulWidget {
  const _HotSongs({required this.artist});

  final ArtistRef artist;

  @override
  State<_HotSongs> createState() => _HotSongsState();
}

class _HotSongsState extends State<_HotSongs> with AutomaticKeepAliveClientMixin {
  Artist? _info;

  @override
  bool get wantKeepAlive => true;

  Future<List<Song>> _load() async {
    final r = await AppScope.of(context).api.artistDetail(widget.artist.id);
    if (mounted) setState(() => _info = r.artist);
    return r.hotSongs;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final a = _info;
    return TrackListView(
      load: _load,
      queueTitle: '${widget.artist.name} 热门歌曲',
      header: (context, tracks, playAll) => CollectionHeader(
        title: a?.name ?? widget.artist.name,
        seed: widget.artist.id,
        coverUrl: a?.avatarUrl,
        icon: Icons.person_rounded,
        circular: true,
        lines: [if (a != null) '单曲 ${a.songCount} · 专辑 ${a.albumCount}', ?a?.description],
        onPlayAll: playAll,
      ),
    );
  }
}

class _Albums extends StatefulWidget {
  const _Albums({required this.artist});

  final ArtistRef artist;

  @override
  State<_Albums> createState() => _AlbumsState();
}

class _AlbumsState extends State<_Albums> with AutomaticKeepAliveClientMixin {
  static const _pageSize = 30;

  final List<Album> _albums = [];
  bool _more = true;
  bool _loading = false;
  Object? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_more) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await AppScope.of(context).api
          .artistAlbums(widget.artist.id, limit: _pageSize, offset: _albums.length);
      if (!mounted) return;
      setState(() {
        _albums.addAll(r.albums);
        _more = r.more && r.albums.isNotEmpty;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_albums.isEmpty && _error != null) {
      return ErrorState(error: _error!, onRetry: _loadMore);
    }
    if (_albums.isEmpty && _loading) return const Center(child: CircularProgressIndicator());
    if (_albums.isEmpty) {
      return const Center(
        child: Text('没有专辑', style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.extentAfter < 400) _loadMore();
        return false;
      },
      child: ListView.builder(
        itemCount: _albums.length + (_more ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == _albums.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return AlbumTile(album: _albums[i]);
        },
      ),
    );
  }
}

/// 专辑列表的一行。
class AlbumTile extends StatelessWidget {
  const AlbumTile({super.key, required this.album});

  final Album album;

  @override
  Widget build(BuildContext context) {
    final a = album;
    return ListTile(
      leading: SizedBox(
        width: 52,
        child: CoverArt(
          palette: fallbackPalette(a.id),
          seed: a.id,
          imageUrl: a.coverUrl,
          radius: 6,
        ),
      ),
      title: Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          if (a.artist.isNotEmpty) a.artist,
          if (a.publishTime case final t?) '${t.year}',
          if (a.size > 0) '${a.size} 首',
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppColors.textSecondary),
      ),
      onTap: () => openAlbum(context, a.id, name: a.name),
    );
  }
}
