import 'package:flutter/material.dart';

import '../../state/player_controller.dart';
import '../../widgets/backdrop_color.dart';
import '../../widgets/round_icon_button.dart';
import 'lyrics_view.dart';
import 'player_controls.dart';
import 'song_menu.dart';

/// 全屏歌词：封面主色做底，大字号歌词，底部保留进度和播放键。
class LyricsPage extends StatelessWidget {
  const LyricsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final player = PlayerScope.of(context);
    final song = player.current;
    if (song == null) return const Scaffold();
    final color = backdropColorFor(player.palette);

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        color: color,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Row(
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
                          Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                          ),
                          Text(
                            song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, color: Colors.white70),
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
                ),
              ),
              const Expanded(
                child: ShaderMask(
                  // 上下边缘淡出。
                  shaderCallback: _fadeEdges,
                  blendMode: BlendMode.dstIn,
                  child: LyricsView(fontSize: 26, padding: EdgeInsets.symmetric(horizontal: 24)),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 8, 24, 12),
                child: Row(
                  children: [
                    Expanded(child: SeekBar()),
                    SizedBox(width: 20),
                    PlayPauseButton(size: 52),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Shader _fadeEdges(Rect r) => const LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
  stops: [0, 0.06, 0.9, 1],
).createShader(r);
