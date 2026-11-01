import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../state/player_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cover_art.dart';
import '../../widgets/dev_badge.dart';
import '../../widgets/flow_background.dart';
import '../../widgets/like_button.dart';
import '../../widgets/round_icon_button.dart';
import 'lyrics_view.dart';
import 'player_controls.dart';
import 'song_menu.dart';

/// 从底部滑出的页面路由。
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

/// 打开播放页；[showLyrics] 为 true 时直接显示歌词。
Future<void> openNowPlaying(BuildContext context, {bool showLyrics = false}) =>
    Navigator.of(context).push(slideUpRoute(NowPlayingPage(initialLyrics: showLyrics)));

/// 全屏播放页：流光背景，中间在「封面」和「歌词」两种模式间切换，下方控制区两种模式共用。
/// 下滑收起。
class NowPlayingPage extends StatefulWidget {
  const NowPlayingPage({super.key, this.initialLyrics = false});

  final bool initialLyrics;

  @override
  State<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends State<NowPlayingPage> {
  late bool _lyrics = widget.initialLyrics;

  void _toggleLyrics() => setState(() => _lyrics = !_lyrics);

  @override
  Widget build(BuildContext context) {
    final player = PlayerScope.of(context);
    final song = player.current;
    if (song == null) return const Scaffold(backgroundColor: AppColors.background);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        // 歌词列表、进度条自己的拖动优先；这里只接空白处的快速下滑。
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) > 700) Navigator.of(context).maybePop();
        },
        child: FlowBackground(
          palette: player.palette,
          imageUrl: song.coverUrl,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Column(
                children: [
                  const _TopBar(),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, a) => FadeTransition(
                        opacity: a,
                        child: ScaleTransition(
                          scale: Tween(begin: 0.96, end: 1.0).animate(a),
                          child: child,
                        ),
                      ),
                      child: _lyrics
                          ? _LyricsPane(
                              key: const ValueKey('lyrics'),
                              song: song,
                              onTapHeader: _toggleLyrics,
                            )
                          : _CoverPane(
                              key: const ValueKey('cover'),
                              song: song,
                              onTapCover: _toggleLyrics,
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const SeekBar(),
                  const SizedBox(height: 4),
                  const _QualityPill(),
                  const SizedBox(height: 8),
                  const _Controls(),
                  const SizedBox(height: 12),
                  _BottomRow(lyrics: _lyrics, onToggleLyrics: _toggleLyrics),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 6),
        // 下拉提示条。
        Container(
          width: 36,
          height: 5,
          decoration: BoxDecoration(color: Colors.white38, borderRadius: BorderRadius.circular(3)),
        ),
        Row(
          children: [
            RoundIconButton(
              icon: Icons.keyboard_arrow_down_rounded,
              onPressed: Navigator.of(context).maybePop,
              tooltip: '收起',
              color: Colors.white70,
              iconSize: 28,
            ),
            Expanded(
              child: Text(
                PlayerScope.of(context).queueTitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: Colors.white70),
              ),
            ),
            RoundIconButton(
              icon: Icons.more_horiz_rounded,
              onPressed: () => showSongMenu(context),
              tooltip: '更多',
              color: Colors.white70,
              iconSize: 24,
            ),
          ],
        ),
      ],
    );
  }
}

/// 封面模式：大封面 + 歌名歌手。点封面切到歌词。
class _CoverPane extends StatelessWidget {
  const _CoverPane({super.key, required this.song, required this.onTapCover});

  final Song song;
  final VoidCallback onTapCover;

  @override
  Widget build(BuildContext context) {
    final playing = PlayerScope.of(context).isPlaying;
    return Column(
      children: [
        Expanded(
          child: Center(
            child: GestureDetector(
              onTap: onTapCover,
              child: Hero(
                tag: 'now-playing-cover',
                child: AnimatedScale(
                  // 暂停时封面缩小一点，播放时弹回。
                  scale: playing ? 1 : 0.86,
                  duration: const Duration(milliseconds: 500),
                  curve: playing ? Curves.easeOutBack : Curves.easeOutCubic,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: playing ? 0.45 : 0.25),
                          offset: Offset(0, playing ? 18 : 8),
                          blurRadius: playing ? 40 : 20,
                        ),
                      ],
                    ),
                    child: CoverArt(
                      palette: song.palette,
                      seed: song.id,
                      imageUrl: song.coverUrl,
                      radius: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _TitleRow(song: song, large: true),
      ],
    );
  }
}

/// 歌词模式：顶部小封面和歌名，下面是歌词。点顶部回到封面。
class _LyricsPane extends StatelessWidget {
  const _LyricsPane({super.key, required this.song, required this.onTapHeader});

  final Song song;
  final VoidCallback onTapHeader;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 4),
        GestureDetector(
          onTap: onTapHeader,
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              SizedBox.square(
                dimension: 52,
                child: CoverArt(
                  palette: song.palette,
                  seed: song.id,
                  imageUrl: song.coverUrl,
                  radius: 6,
                  shadow: AppShadows.medium,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: _TitleRow(song: song, large: false)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Expanded(
          child: ShaderMask(
            // 上下边缘淡出。
            shaderCallback: _fadeEdges,
            blendMode: BlendMode.dstIn,
            child: LyricsView(fontSize: 28, anchor: 0.25, blur: true),
          ),
        ),
      ],
    );
  }
}

Shader _fadeEdges(Rect r) => const LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
  stops: [0, 0.08, 0.88, 1],
).createShader(r);

class _TitleRow extends StatelessWidget {
  const _TitleRow({required this.song, required this.large});

  final Song song;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: large ? 22 : 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                song.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: large ? 16 : 14, color: Colors.white60),
              ),
            ],
          ),
        ),
        LikeButton(
          songId: song.id,
          size: large ? 44 : 40,
          iconSize: large ? 26 : 24,
          color: Colors.white,
        ),
      ],
    );
  }
}

/// 进度条下方居中的音质标签，点开选择。只列出这首歌提供的档位。
class _QualityPill extends StatelessWidget {
  const _QualityPill();

  @override
  Widget build(BuildContext context) {
    final player = PlayerScope.of(context);
    final q = player.quality;
    final label = [
      if (q != null) q.label else if (player.isLoading) '加载中' else '音质',
      if (player.trial != null) '试听',
    ].join(' · ');
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: player.qualities.isEmpty ? null : () => showQualitySheet(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: Colors.white70,
            ),
          ),
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls();

  @override
  Widget build(BuildContext context) {
    final player = PlayerScope.of(context);
    final one = player.repeat == Repeat.one;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        RoundIconButton(
          icon: Icons.shuffle_rounded,
          onPressed: player.toggleShuffle,
          tooltip: player.shuffle ? '关闭随机播放' : '随机播放',
          color: player.shuffle ? Colors.white : Colors.white38,
          size: 44,
          iconSize: 22,
        ),
        RoundIconButton(
          icon: Icons.fast_rewind_rounded,
          onPressed: player.previous,
          tooltip: '上一首',
          color: Colors.white,
          size: 60,
          iconSize: 40,
        ),
        const PlayPauseButton(size: 76),
        RoundIconButton(
          icon: Icons.fast_forward_rounded,
          onPressed: player.next,
          tooltip: '下一首',
          color: Colors.white,
          size: 60,
          iconSize: 40,
        ),
        RoundIconButton(
          icon: one ? Icons.repeat_one_rounded : Icons.repeat_rounded,
          onPressed: player.toggleRepeat,
          tooltip: one ? '单曲循环' : '列表循环',
          color: one ? Colors.white : Colors.white38,
          size: 44,
          iconSize: 22,
        ),
      ],
    );
  }
}

class _BottomRow extends StatelessWidget {
  const _BottomRow({required this.lyrics, required this.onToggleLyrics});

  final bool lyrics;
  final VoidCallback onToggleLyrics;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        RoundIconButton(
          icon: lyrics ? Icons.lyrics_rounded : Icons.lyrics_outlined,
          onPressed: onToggleLyrics,
          tooltip: lyrics ? '关闭歌词' : '歌词',
          filled: lyrics,
          background: Colors.white24,
          color: lyrics ? Colors.white : Colors.white60,
          size: 40,
          iconSize: 22,
        ),
        RoundIconButton(
          icon: Icons.speaker_group_outlined,
          onPressed: () => showNotReady('播放设备'),
          tooltip: '播放设备',
          color: Colors.white60,
          size: 40,
          iconSize: 22,
        ),
        RoundIconButton(
          icon: Icons.format_list_bulleted_rounded,
          onPressed: () => showQueueSheet(context),
          tooltip: '播放列表',
          color: Colors.white60,
          size: 40,
          iconSize: 22,
        ),
      ],
    );
  }
}
