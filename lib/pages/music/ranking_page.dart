import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../data/models.dart';
import '../../state/account_controller.dart';
import '../library/track_list_view.dart';
import '../login_page.dart';

/// 听歌排行：最近一周 / 所有时间。
class RankingPage extends StatelessWidget {
  const RankingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final account = AccountScope.of(context);
    if (!account.isLoggedIn) return const LoginPrompt(message: '登录后查看听歌排行');
    final uid = account.profile!.userId;
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: '最近一周'),
              Tab(text: '所有时间'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _RankList(userId: uid, weekly: true),
                _RankList(userId: uid, weekly: false),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RankList extends StatefulWidget {
  const _RankList({required this.userId, required this.weekly});

  final int userId;
  final bool weekly;

  @override
  State<_RankList> createState() => _RankListState();
}

class _RankListState extends State<_RankList> with AutomaticKeepAliveClientMixin {
  List<int> _counts = const [];

  @override
  bool get wantKeepAlive => true;

  Future<List<Song>> _load() async {
    final r = await AppScope.of(context).api.playRecord(widget.userId, weekly: widget.weekly);
    _counts = [for (final e in r) e.playCount];
    return [for (final e in r) e.song];
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final label = widget.weekly ? '最近一周' : '所有时间';
    return TrackListView(
      reloadKey: widget.userId,
      load: _load,
      queueTitle: '听歌排行 · $label',
      emptyText: '暂无记录（账号可能关闭了听歌排行）',
      trailingFor: (i) => i < _counts.length ? '${_counts[i]} 次' : null,
      header: (context, tracks, playAll) => CollectionHeader(
        title: '听歌排行',
        seed: 'ranking',
        icon: Icons.show_chart_rounded,
        lines: [label, if (tracks.isNotEmpty) '前 ${tracks.length} 首'],
        onPlayAll: playAll,
      ),
    );
  }
}
