import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../library/track_list_view.dart';
import 'nav.dart';

/// 每日推荐歌曲（需要登录）。
class DailySongsPage extends StatelessWidget {
  const DailySongsPage({super.key});

  static Future<void> open(BuildContext context) => SubPage.push(context, const DailySongsPage());

  @override
  Widget build(BuildContext context) {
    final api = AppScope.of(context).api;
    final today = DateTime.now();
    return SubPage(
      title: '每日推荐',
      body: TrackListView(
        load: api.dailySongs,
        queueTitle: '每日推荐',
        header: (context, tracks, playAll) => CollectionHeader(
          title: '${today.month} 月 ${today.day} 日',
          seed: 'daily',
          icon: Icons.calendar_today_rounded,
          lines: const ['根据你的音乐口味生成，每天 6:00 更新'],
          onPlayAll: playAll,
        ),
      ),
    );
  }
}
