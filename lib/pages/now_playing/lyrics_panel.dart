import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models.dart';
import '../../state/player_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cover_art.dart';
import '../../widgets/round_icon_button.dart';

/// 播放页的歌词：当前行逐字填色，下方附翻译和罗马音；
/// 当前行自动滚动到视口约 1/3 处，用户手动滚动后暂停跟随几秒。
class LyricsPanel extends StatefulWidget {
  const LyricsPanel({super.key, this.showHeader = true});

  /// 窄屏单独一页时在顶部显示歌曲信息。
  final bool showHeader;

  @override
  State<LyricsPanel> createState() => _LyricsPanelState();
}

class _LyricsPanelState extends State<LyricsPanel> {
  static const _followPause = Duration(seconds: 3);
  static const _anchor = 0.32;

  final _scroll = ScrollController();
  List<GlobalKey> _keys = const [];
  String? _songId;
  int _lastActive = -2;
  DateTime _userScrolledAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _syncKeys(Song song) {
    if (_songId == song.id) return;
    _songId = song.id;
    _keys = List.generate(song.lyrics.length, (_) => GlobalKey());
    _lastActive = -2;
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _follow(int active, {bool force = false}) {
    if (active == _lastActive && !force) return;
    _lastActive = active;
    if (active < 0) return;
    if (!force && DateTime.now().difference(_userScrolledAt) < _followPause) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _keys[active].currentContext;
      if (ctx == null || !mounted) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: _anchor,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final player = PlayerScope.of(context);
    final song = player.song;
    _syncKeys(song);
    final active = player.activeLyricIndex;
    _follow(active);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showHeader) _Header(song: song, player: player),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: song.lyrics.isEmpty
                    ? const Center(
                        child: Text(
                          '暂无歌词，请欣赏音乐 ~',
                          style: TextStyle(fontSize: 20, color: Colors.white54),
                        ),
                      )
                    : _lyricList(player, active),
              ),
              const SizedBox(width: 12),
              _Toolbar(
                player: player,
                onCopy: active < 0 ? null : () => _copy(song.lyrics[active]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _lyricList(PlayerController player, int active) {
    final lines = player.song.lyrics;
    return LayoutBuilder(
      builder: (context, c) {
        // 首尾留白，让第一行和最后一行也能滚到锚点位置。
        final topPad = c.maxHeight * _anchor;
        final fontSize = (c.maxWidth * 0.055).clamp(22.0, 40.0);
        return NotificationListener<UserScrollNotification>(
          onNotification: (_) {
            _userScrolledAt = DateTime.now();
            return false;
          },
          child: ShaderMask(
            // 上下边缘淡出。
            shaderCallback: (r) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
              stops: [0, 0.12, 0.85, 1],
            ).createShader(r),
            blendMode: BlendMode.dstIn,
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
              // 一首歌的歌词行数有限，直接全部建出来，保证 ensureVisible 总能找到目标行。
              child: SingleChildScrollView(
                controller: _scroll,
                padding: EdgeInsets.only(top: topPad, bottom: c.maxHeight * (1 - _anchor)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, line) in lines.indexed)
                      _LyricLineView(
                        key: _keys[i],
                        line: line,
                        distance: (i - active).abs(),
                        isActive: i == active,
                        position: player.lyricPosition,
                        fontSize: fontSize,
                        onTap: () {
                          player.seek(line.start - player.lyricOffset);
                          _userScrolledAt = DateTime.fromMillisecondsSinceEpoch(0);
                          _follow(i, force: true);
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _copy(LyricLine line) {
    final text = [line.text, ?line.translation, ?line.romaji].join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(const SnackBar(content: Text('已复制当前歌词'), duration: Duration(seconds: 1)));
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.song, required this.player});

  final Song song;
  final PlayerController player;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: CoverArt(palette: song.palette, seed: song.id, radius: AppRadius.card),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accentSoft,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  song.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, color: Colors.white70),
                ),
              ],
            ),
          ),
          RoundIconButton(
            icon: player.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: player.isLiked ? AppColors.accent : Colors.white70,
            onPressed: player.toggleLike,
            size: 44,
            iconSize: 26,
          ),
        ],
      ),
    );
  }
}

class _LyricLineView extends StatefulWidget {
  const _LyricLineView({
    super.key,
    required this.line,
    required this.distance,
    required this.isActive,
    required this.position,
    required this.fontSize,
    required this.onTap,
  });

  final LyricLine line;

  /// 与当前行的行数差，用来决定模糊和透明度。
  final int distance;
  final bool isActive;
  final Duration position;
  final double fontSize;
  final VoidCallback onTap;

  @override
  State<_LyricLineView> createState() => _LyricLineViewState();
}

class _LyricLineViewState extends State<_LyricLineView> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.isActive;
    final line = widget.line;
    final fs = widget.fontSize;
    // 离当前行越远越模糊；悬停时清晰，方便点选。
    final blur = active || _hovered ? 0.0 : (widget.distance * 0.7).clamp(0.0, 3.0);
    final dimAlpha = active ? 0.28 : 0.32;

    final mainText = active
        ? Wrap(
            children: [
              for (final w in line.words)
                _KaraokeWord(
                  text: w.text,
                  progress: w.progressAt(widget.position),
                  style: TextStyle(fontSize: fs, fontWeight: FontWeight.w800, height: 1.3),
                  dimAlpha: dimAlpha,
                ),
            ],
          )
        : Text(
            line.text,
            style: TextStyle(
              fontSize: fs,
              fontWeight: FontWeight.w800,
              height: 1.3,
              color: Colors.white.withValues(alpha: dimAlpha),
            ),
          );

    final subAlpha = active ? 0.85 : 0.32;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        mainText,
        if (line.translation != null) ...[
          const SizedBox(height: 8),
          Text(
            line.translation!,
            style: TextStyle(
              fontSize: fs * 0.55,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: subAlpha),
            ),
          ),
        ],
        if (line.romaji != null) ...[
          const SizedBox(height: 4),
          Text(
            line.romaji!,
            style: TextStyle(
              fontSize: fs * 0.45,
              letterSpacing: 0.5,
              color: Colors.white.withValues(alpha: subAlpha * 0.75),
            ),
          ),
        ],
      ],
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(
              alpha: active
                  ? 0.12
                  : _hovered
                  ? 0.06
                  : 0,
            ),
            borderRadius: BorderRadius.circular(AppRadius.panel),
          ),
          child: AnimatedScale(
            scale: active ? 1 : 0.96,
            alignment: Alignment.centerLeft,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            child: blur == 0
                ? body
                : ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                    child: body,
                  ),
          ),
        ),
      ),
    );
  }
}

/// 单个字的逐字填色：底层暗色文字，上层亮色文字按 [progress] 从左往右显现。
class _KaraokeWord extends StatelessWidget {
  const _KaraokeWord({
    required this.text,
    required this.progress,
    required this.style,
    required this.dimAlpha,
  });

  final String text;
  final double progress;
  final TextStyle style;
  final double dimAlpha;

  @override
  Widget build(BuildContext context) {
    final dim = Text(
      text,
      style: style.copyWith(color: Colors.white.withValues(alpha: dimAlpha)),
    );
    final lit = Text(text, style: style.copyWith(color: AppColors.accentSoft));
    if (progress <= 0) return dim;
    if (progress >= 1) return lit;
    return Stack(
      children: [
        dim,
        ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (r) => LinearGradient(
            colors: const [Colors.white, Colors.white, Colors.transparent, Colors.transparent],
            // 边缘留一点羽化，填色过渡更柔和。
            stops: [0, (progress - 0.06).clamp(0.0, 1.0), (progress + 0.06).clamp(0.0, 1.0), 1],
          ).createShader(r),
          child: lit,
        ),
      ],
    );
  }
}

/// 歌词右侧的竖排工具：复制、歌词偏移、设置。
class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.player, required this.onCopy});

  final PlayerController player;
  final VoidCallback? onCopy;

  static const _step = Duration(milliseconds: 500);

  @override
  Widget build(BuildContext context) {
    final offset = player.lyricOffset.inMilliseconds / 1000;
    final label = offset == 0 ? '0s' : '${offset > 0 ? '+' : ''}${offset.toStringAsFixed(1)}s';
    const divider = SizedBox(width: 40, child: Divider(color: Colors.white24, height: 20));

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        RoundIconButton(
          icon: Icons.copy_rounded,
          onPressed: onCopy,
          tooltip: '复制当前歌词',
          color: Colors.white60,
          size: 44,
          iconSize: 22,
        ),
        divider,
        RoundIconButton(
          icon: Icons.fast_rewind_rounded,
          onPressed: () => player.adjustLyricOffset(-_step),
          tooltip: '歌词延后 0.5s',
          color: Colors.white60,
          size: 44,
          iconSize: 22,
        ),
        const SizedBox(height: 4),
        Tooltip(
          message: '点击重置偏移',
          child: GestureDetector(
            onTap: player.resetLyricOffset,
            child: Container(
              width: 48,
              padding: const EdgeInsets.symmetric(vertical: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
            ),
          ),
        ),
        const SizedBox(height: 4),
        RoundIconButton(
          icon: Icons.fast_forward_rounded,
          onPressed: () => player.adjustLyricOffset(_step),
          tooltip: '歌词提前 0.5s',
          color: Colors.white60,
          size: 44,
          iconSize: 22,
        ),
        divider,
        RoundIconButton(
          icon: Icons.tune_rounded,
          onPressed: () {},
          tooltip: '歌词设置',
          color: Colors.white60,
          size: 44,
          iconSize: 22,
        ),
      ],
    );
  }
}
