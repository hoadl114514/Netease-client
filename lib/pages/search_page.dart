import 'package:flutter/material.dart';

import '../api/netease_api.dart';
import '../app/app.dart';
import '../data/models.dart';
import '../shell/player_bar.dart';
import '../state/player_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/song_tile.dart';

/// 单曲搜索，滚到底自动加载下一页。
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
  static const _pageSize = 30;

  late final _input = TextEditingController(text: widget.keyword);
  late String _keyword = widget.keyword;
  final List<Song> _songs = [];
  int _total = 0;
  bool _loading = false;
  String? _error;

  /// 防止旧关键词的结果在新搜索之后才回来。
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  bool get _hasMore => _songs.length < _total;

  void _search(String keyword) {
    final k = keyword.trim();
    if (k.isEmpty) return;
    setState(() {
      _keyword = k;
      _songs.clear();
      _total = 0;
      _error = null;
      _loading = false;
      _generation++;
    });
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading) return;
    final gen = _generation;
    setState(() => _loading = true);
    try {
      final r = await AppScope.of(context).api
          .searchSongs(_keyword, limit: _pageSize, offset: _songs.length);
      if (!mounted || gen != _generation) return;
      setState(() {
        _songs.addAll(r.songs);
        // 服务端偶尔少给一页，以实际拿到的为准，避免无限加载。
        _total = r.songs.isEmpty ? _songs.length : r.total;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted && gen == _generation) setState(() => _error = e.message);
    } finally {
      if (mounted && gen == _generation) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.extentAfter < 400 && _hasMore && !_loading && _error == null) _loadMore();
          return false;
        },
        child: ListView.builder(
          itemCount: _songs.length + 1,
          itemBuilder: (context, i) {
            if (i < _songs.length) {
              return SongTile(
                song: _songs[i],
                onTap: () =>
                    PlayerScope.read(context)
                        .playQueue(List.of(_songs), start: i, title: '搜索：$_keyword'),
              );
            }
            return _Footer(
              loading: _loading,
              error: _error,
              empty: _songs.isEmpty,
              done: !_hasMore,
              onRetry: _loadMore,
            );
          },
        ),
      ),
      bottomNavigationBar: const SafeArea(top: false, child: PlayerBar()),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.loading,
    required this.error,
    required this.empty,
    required this.done,
    required this.onRetry,
  });

  final bool loading;
  final String? error;
  final bool empty;
  final bool done;
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
      child = const Text('没有找到相关歌曲', style: style);
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
