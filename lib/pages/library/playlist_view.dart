import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../data/format.dart';
import '../../data/models.dart';
import '../../state/account_controller.dart';
import '../comments/comments_page.dart';
import '../../theme/app_theme.dart';
import '../../widgets/playlist_card.dart';
import 'track_list_view.dart';

/// 歌单内容：头部信息 + 播放全部 + 歌曲列表。歌单页和「我喜欢」共用。
/// 别人的歌单在头部多一个「收藏」按钮。
class PlaylistView extends StatelessWidget {
  const PlaylistView({super.key, required this.playlist});

  final Playlist playlist;

  @override
  Widget build(BuildContext context) {
    final p = playlist;
    final api = AppScope.of(context).api;
    return TrackListView(
      reloadKey: p.id,
      load: () async => (await api.playlistDetail(p.id)).tracks,
      queueTitle: p.name,
      sourceId: p.id,
      emptyText: '歌单是空的',
      header: (context, tracks, playAll) => CollectionHeader(
        title: p.name,
        seed: p.id,
        // 歌单没有封面时用第一首歌的封面。
        coverUrl: p.coverUrl ?? tracks.where((t) => t.coverUrl != null).firstOrNull?.coverUrl,
        fallbackCover: playlistCoverFallback(context, p),
        palette: p.palette,
        lines: [
          [?p.creator, '${p.trackCount} 首', '播放 ${formatPlayCount(p.playCount)}'].join(' · '),
          ?p.description,
        ],
        onPlayAll: playAll,
        actions: [
          _SubscribeButton(playlist: p),
          IconButton(
            tooltip: '评论',
            onPressed: () => CommentsPage.open(
              context,
              target: CommentTarget.playlist,
              id: p.id,
              title: p.name,
              subtitle: p.creator,
              coverUrl: p.coverUrl ?? tracks.where((t) => t.coverUrl != null).firstOrNull?.coverUrl,
            ),
            icon: const Icon(Icons.mode_comment_outlined),
          ),
        ],
      ),
    );
  }
}

class _SubscribeButton extends StatefulWidget {
  const _SubscribeButton({required this.playlist});

  final Playlist playlist;

  @override
  State<_SubscribeButton> createState() => _SubscribeButtonState();
}

class _SubscribeButtonState extends State<_SubscribeButton> {
  bool _busy = false;

  Future<void> _toggle(AccountController account, bool subscribed) async {
    setState(() => _busy = true);
    try {
      await account.setSubscribed(widget.playlist, !subscribed);
      AppScope.toast(subscribed ? '已取消收藏' : '已收藏歌单');
    } catch (e) {
      AppScope.toast('操作失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = AccountScope.of(context);
    final p = widget.playlist;
    // 自己的歌单、「我喜欢」和未登录时不显示。
    if (!account.isLoggedIn || p.isLikedList || account.isOwn(p)) {
      return const SizedBox.shrink();
    }
    final subscribed = account.isSubscribed(p.id);
    return OutlinedButton.icon(
      onPressed: _busy ? null : () => _toggle(account, subscribed),
      icon: Icon(subscribed ? Icons.check_rounded : Icons.add_rounded, size: 18),
      label: Text(subscribed ? '已收藏' : '收藏'),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: AppColors.outline),
      ),
    );
  }
}
