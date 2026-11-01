import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../state/player_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/round_icon_button.dart';
import 'lyrics_panel.dart';
import 'song_info_panel.dart';

/// 从底部滑出全屏播放页。
Future<void> openNowPlaying(BuildContext context, {bool showLyrics = false}) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, _, _) => NowPlayingPage(showLyrics: showLyrics),
      transitionsBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(curved),
          child: child,
        );
      },
    ),
  );
}

/// 全屏播放页。宽屏左右分栏（封面信息 | 歌词），窄屏左右滑动切换两页。
class NowPlayingPage extends StatefulWidget {
  const NowPlayingPage({super.key, this.showLyrics = false});

  final bool showLyrics;

  /// 宽于这个值时封面和歌词并排显示。
  static const splitBreakpoint = 1000.0;

  @override
  State<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends State<NowPlayingPage> {
  late final PageController _pages = PageController(initialPage: widget.showLyrics ? 1 : 0);
  late int _page = widget.showLyrics ? 1 : 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = PlayerScope.of(context);
    final close = Navigator.of(context).maybePop;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): close,
        const SingleActivator(LogicalKeyboardKey.space): player.toggle,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: AmbientBackground(
            palette: player.song.palette,
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, c) {
                  final split = c.maxWidth >= NowPlayingPage.splitBreakpoint;
                  return Stack(
                    children: [
                      Positioned.fill(child: split ? _split() : _paged()),
                      Positioned(
                        top: 12,
                        right: 16,
                        child: RoundIconButton(
                          icon: Icons.keyboard_arrow_down_rounded,
                          onPressed: close,
                          tooltip: '收起',
                          iconSize: 30,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _split() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(48, 56, 32, 32),
      child: Row(
        children: [
          Expanded(child: SongInfoPanel()),
          SizedBox(width: 56),
          Expanded(child: LyricsPanel(showHeader: false)),
        ],
      ),
    );
  }

  Widget _paged() {
    return Column(
      children: [
        Expanded(
          child: PageView(
            controller: _pages,
            onPageChanged: (i) => setState(() => _page = i),
            children: const [
              Padding(padding: EdgeInsets.fromLTRB(28, 56, 28, 8), child: SongInfoPanel()),
              Padding(padding: EdgeInsets.fromLTRB(20, 56, 20, 8), child: LyricsPanel()),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 16, top: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 2; i++)
                GestureDetector(
                  onTap: () => _pages.animateToPage(
                    i,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _page == i ? 22 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: _page == i ? AppColors.accentSoft : Colors.white38,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
