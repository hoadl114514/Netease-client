import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../state/player_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/backdrop_color.dart';
import '../../widgets/cover_art.dart';
import '../../widgets/dev_badge.dart';
import '../../widgets/like_button.dart';
import '../../widgets/round_icon_button.dart';
import 'lyrics_page.dart';
import 'lyrics_view.dart';
import 'player_controls.dart';
import 'song_menu.dart';

/// 从底部滑出的页面路由，播放页和全屏歌词共用。
Route<void> slideUpRoute(Widget page) => PageRouteBuilder<void>(
  transitionDuration: const Duration(milliseconds: 380),
  reverseTransitionDuration: const Duration(milliseconds: 300),
  pageBuilder: (_, _, _) => page,
  transitionsBuilder: (context, animation, _, child) => SlideTransition(
    position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(
      CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    ),
    child: child,
  ),
);

/// 打开播放页；[showLyrics] 为 true 时直接打开全屏歌词。
Future<void> openNowPlaying(BuildContext context, {bool showLyrics = false}) =>
    Navigator.of(context)
        .push(slideUpRoute(showLyrics ? const LyricsPage() : const NowPlayingPage()));

/// 全屏播放页：第一屏是封面和控制，往下滑是歌词预览和歌手卡片。
class NowPlayingPage extends StatelessWidget {
  const NowPlayingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final player = PlayerScope.of(context);
    final song = player.current;
    if (song == null) return const Scaffold(backgroundColor: AppColors.background);
    final color = backdropColorFor(player.palette);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        decoration: backdropDecoration(color),
        child: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, c) => CustomScrollView(
              slivers: [
                // 第一屏正好占满视口，往下滑才露出卡片。
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: c.maxHeight,
                    child: _PlayerSection(song: song),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  sliver: SliverList.list(
                    children: [
                      _LyricsCard(color: color),
                      const SizedBox(height: 16),
                      _ArtistCard(song: song),
                      SizedBox(height: MediaQuery.paddingOf(context).bottom + 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerSection extends StatelessWidget {
  const _PlayerSection({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    final player = PlayerScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
      child: Column(
        children: [
          _TopBar(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Hero(
                  tag: 'now-playing-cover',
                  child: AnimatedScale(
                    // 暂停时封面略微缩小，给一点"停下来"的反馈。
                    scale: player.isPlaying ? 1 : 0.9,
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutBack,
                    child: CoverArt(
                      palette: song.palette,
                      seed: song.id,
                      imageUrl: song.coverUrl,
                      radius: AppRadius.card,
                      shadow: AppShadows.heavy,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        // 当前音质放在歌手名前面，做成小徽章，点开切换。
                        if (player.quality case final q?)
                          GestureDetector(
                            onTap: () => showQualitySheet(context),
                            child: _Badge(q.badge),
                          ),
                        if (player.trial != null) const _Badge('试听'),
                        Flexible(
                          child: Text(
                            song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 15, color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              LikeButton(songId: song.id, size: 44, iconSize: 28, color: Colors.white),
            ],
          ),
          const SizedBox(height: 16),
          const SeekBar(),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              RoundIconButton(
                icon: Icons.shuffle_rounded,
                onPressed: player.toggleShuffle,
                tooltip: player.shuffle ? '关闭随机播放' : '随机播放',
                color: player.shuffle ? AppColors.accent : Colors.white,
                size: 44,
                iconSize: 26,
              ),
              RoundIconButton(
                icon: Icons.skip_previous_rounded,
                onPressed: player.previous,
                tooltip: '上一首',
                color: Colors.white,
                size: 56,
                iconSize: 42,
              ),
              const PlayPauseButton(size: 68),
              RoundIconButton(
                icon: Icons.skip_next_rounded,
                onPressed: player.next,
                tooltip: '下一首',
                color: Colors.white,
                size: 56,
                iconSize: 42,
              ),
              RoundIconButton(
                icon: player.repeat == Repeat.one ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                onPressed: player.toggleRepeat,
                tooltip: player.repeat == Repeat.one ? '单曲循环' : '列表循环',
                color: AppColors.accent,
                size: 44,
                iconSize: 26,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              RoundIconButton(
                icon: Icons.speaker_group_outlined,
                onPressed: () => showNotReady('播放设备'),
                tooltip: '播放设备',
                color: Colors.white70,
                size: 40,
                iconSize: 22,
              ),
              const Spacer(),
              const _QualityButton(),
              const Spacer(),
              RoundIconButton(
                icon: Icons.ios_share_rounded,
                onPressed: () => showNotReady('分享'),
                tooltip: '分享',
                color: Colors.white70,
                size: 40,
                iconSize: 22,
              ),
              RoundIconButton(
                icon: Icons.queue_music_rounded,
                onPressed: () => showQueueSheet(context),
                tooltip: '播放列表',
                color: Colors.white70,
                size: 40,
                iconSize: 22,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        RoundIconButton(
          icon: Icons.keyboard_arrow_down_rounded,
          onPressed: Navigator.of(context).maybePop,
          tooltip: '收起',
          color: Colors.white,
          iconSize: 30,
        ),
        Expanded(
          child: Column(
            children: [
              const Text(
                '正在播放',
                style: TextStyle(fontSize: 11, letterSpacing: 1, color: Colors.white70),
              ),
              Text(
                PlayerScope.of(context).queueTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        RoundIconButton(
          icon: Icons.more_horiz_rounded,
          onPressed: () => showSongMenu(context),
          tooltip: '更多',
          color: Colors.white,
          iconSize: 26,
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(color: Colors.white70, borderRadius: BorderRadius.circular(2)),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.black),
      ),
    );
  }
}

/// 歌词预览：卡片里跟着播放滚动，点卡片进入全屏歌词。
class _LyricsCard extends StatelessWidget {
  const _LyricsCard({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    void open() => Navigator.of(context).push(slideUpRoute(const LyricsPage()));
    return Material(
      color: Color.lerp(color, Colors.white, 0.12),
      borderRadius: BorderRadius.circular(AppRadius.panel),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: open,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Text('歌词预览', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  RoundIconButton(
                    icon: Icons.open_in_full_rounded,
                    onPressed: open,
                    tooltip: '全屏歌词',
                    filled: true,
                    background: Colors.black26,
                    color: Colors.white,
                    size: 32,
                    iconSize: 16,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const SizedBox(
                height: 300,
                child: LyricsView(
                  fontSize: 20,
                  interactive: false,
                  anchor: 0.15,
                  padding: EdgeInsets.only(right: 8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArtistCard extends StatelessWidget {
  const _ArtistCard({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceHigh,
      borderRadius: BorderRadius.circular(AppRadius.panel),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 180,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 占位：接 API 后换成歌手图。
                FittedBox(
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox.square(
                    dimension: 200,
                    child: CoverArt(
                      palette: song.palette.reversed.toList(),
                      seed: song.artist,
                      imageUrl: song.coverUrl,
                      radius: 0,
                    ),
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x66000000), Color(0x00000000)],
                    ),
                  ),
                ),
                const Positioned(
                  left: 16,
                  top: 14,
                  child: Text('关于歌手', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.artist,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                          ),
                          if (song.album.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              '专辑：${song.album}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                            ),
                          ],
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () => showNotReady('关注歌手'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: AppColors.outline),
                        shape: const StadiumBorder(),
                      ),
                      child: const Text('关注'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Row(
                  children: [
                    DevBadge(),
                    SizedBox(width: 8),
                    Text(
                      '歌手简介、热门歌曲',
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
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

/// 当前音质，点开选择。只列出这首歌提供的档位。
class _QualityButton extends StatelessWidget {
  const _QualityButton();

  @override
  Widget build(BuildContext context) {
    final player = PlayerScope.of(context);
    final q = player.quality;
    return TextButton.icon(
      onPressed: player.qualities.isEmpty ? null : () => showQualitySheet(context),
      icon: const Icon(Icons.graphic_eq_rounded, size: 18),
      label: Text(q?.label ?? (player.isLoading ? '加载中' : '音质')),
      style: TextButton.styleFrom(foregroundColor: Colors.white70),
    );
  }
}
