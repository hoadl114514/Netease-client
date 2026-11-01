import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../state/account_controller.dart';
import '../library/track_list_view.dart';
import '../login_page.dart';

/// 最近播放（账号的云端记录，最多 300 首）。
class RecentPage extends StatelessWidget {
  const RecentPage({super.key});

  @override
  Widget build(BuildContext context) {
    final account = AccountScope.of(context);
    if (!account.isLoggedIn) return const LoginPrompt(message: '登录后查看最近播放');
    final api = AppScope.of(context).api;
    return TrackListView(
      reloadKey: account.profile!.userId,
      load: api.recentSongs,
      queueTitle: '最近播放',
      emptyText: '还没有播放记录',
      header: (context, tracks, playAll) => CollectionHeader(
        title: '最近播放',
        seed: 'recent',
        icon: Icons.history_rounded,
        lines: [if (tracks.isNotEmpty) '${tracks.length} 首'],
        onPlayAll: playAll,
      ),
    );
  }
}
