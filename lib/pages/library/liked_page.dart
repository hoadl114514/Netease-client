import 'package:flutter/material.dart';

import '../../state/account_controller.dart';
import '../login_page.dart';
import 'playlist_view.dart';

/// 底部「我喜欢」标签：登录后显示账号的「我喜欢的音乐」歌单。
class LikedPage extends StatelessWidget {
  const LikedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final account = AccountScope.of(context);
    if (!account.isLoggedIn) return const LoginPrompt(message: '登录后查看你喜欢的音乐');
    final liked = account.likedPlaylist;
    if (liked == null) return const Center(child: CircularProgressIndicator());
    return PlaylistView(playlist: liked);
  }
}
