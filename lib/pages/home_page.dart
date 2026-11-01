import 'package:flutter/material.dart';

import '../data/format.dart';
import '../data/mock_data.dart';
import '../data/models.dart';
import '../state/player_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/cover_art.dart';
import '../widgets/hover_builder.dart';
import '../widgets/round_icon_button.dart';

/// 为我推荐。
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final hPad = width < 600 ? 16.0 : 24.0;

    return Scrollbar(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 0),
            sliver: SliverList.list(
              children: [
                const _Greeting(),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, c) {
                    const shortcuts = Column(
                      children: [
                        _ShortcutCard(
                          title: '每日推荐',
                          subtitle: '根据你的音乐口味 · 每日更新',
                          icon: Icons.calendar_today_rounded,
                          palette: MockData.dailyPalette,
                          seed: 'daily',
                        ),
                        SizedBox(height: 16),
                        _ShortcutCard(
                          title: '我喜欢的音乐',
                          subtitle: '发现你独特的音乐品味',
                          icon: Icons.favorite_rounded,
                          palette: MockData.likedPalette,
                          seed: 'liked',
                        ),
                      ],
                    );
                    if (c.maxWidth < 760) {
                      return Column(
                        children: [
                          shortcuts,
                          const SizedBox(height: 16),
                          _PersonalFmCard(width: c.maxWidth),
                        ],
                      );
                    }
                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Expanded(child: shortcuts),
                          const SizedBox(width: 20),
                          Expanded(child: _PersonalFmCard(width: (c.maxWidth - 20) / 2)),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),
                const _SectionTitle('专属歌单'),
                const SizedBox(height: 16),
              ],
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 32),
            sliver: SliverLayoutBuilder(
              builder: (context, c) {
                // 按宽度算列数和格子高度：封面正方形 + 间距 + 两行标题，避免固定宽高比导致溢出。
                const spacing = 16.0;
                const titleHeight = 10 + 14 * 1.4 * 2 + 4;
                final columns = ((c.crossAxisExtent + spacing) / (180 + spacing)).floor().clamp(
                  2,
                  6,
                );
                final cell = (c.crossAxisExtent - spacing * (columns - 1)) / columns;
                return SliverGrid.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: spacing,
                    crossAxisSpacing: spacing,
                    mainAxisExtent: cell + titleHeight,
                  ),
                  itemCount: MockData.recommended.length,
                  itemBuilder: (context, i) => _PlaylistCard(playlist: MockData.recommended[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${greetingFor(DateTime.now())}，${MockData.userName}',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 6),
        const Text('由此开启好心情 ~', style: TextStyle(color: AppColors.textSecondary)),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 22,
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
        const SizedBox(width: 10),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
      ],
    );
  }
}

/// 卡片底：圆角深色面板，悬停变亮。
class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.padding = const EdgeInsets.all(16), this.onTap});

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      onTap: onTap,
      builder: (context, hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: padding,
        decoration: BoxDecoration(
          color: hovered && onTap != null ? AppColors.cardHover : AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.panel),
          border: Border.all(color: AppColors.border),
        ),
        child: child,
      ),
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.palette,
    required this.seed,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> palette;
  final String seed;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      onTap: () {},
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: CoverArt(palette: palette, seed: seed, radius: AppRadius.card),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 20, color: AppColors.accent),
                    const SizedBox(width: 8),
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

class _PersonalFmCard extends StatelessWidget {
  const _PersonalFmCard({required this.width});

  /// 卡片可用宽度。由外层算好传进来，这样卡片本身仍支持 IntrinsicHeight。
  final double width;

  @override
  Widget build(BuildContext context) {
    // 窄时封面缩小、去掉"私人FM"标签，保证控制按钮放得下。
    final inner = width - 42;
    final cover = (inner * 0.4).clamp(96.0, 176.0);
    final showLabel = inner > 460;
    return _buildCard(context, cover, showLabel);
  }

  Widget _buildCard(BuildContext context, double cover, bool showLabel) {
    final player = PlayerScope.of(context);
    final song = player.song;

    Widget meta(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );

    return _Panel(
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        height: cover,
        child: Row(
          children: [
            SizedBox.square(
              dimension: cover,
              child: CoverArt(
                palette: song.palette,
                seed: song.id,
                radius: AppRadius.card,
                shadow: AppShadows.medium,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  meta(Icons.person_rounded, song.artist),
                  meta(Icons.album_rounded, song.album),
                  const Spacer(),
                  Row(
                    children: [
                      RoundIconButton(
                        icon: Icons.thumb_down_alt_rounded,
                        onPressed: player.next,
                        tooltip: '不喜欢',
                      ),
                      const SizedBox(width: 8),
                      RoundIconButton(
                        icon: player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        onPressed: player.toggle,
                        tooltip: player.isPlaying ? '暂停' : '播放',
                        size: 48,
                        iconSize: 28,
                        filled: true,
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: 8),
                      RoundIconButton(
                        icon: Icons.skip_next_rounded,
                        onPressed: player.next,
                        tooltip: '下一首',
                        iconSize: 24,
                      ),
                      if (showLabel) ...[
                        const Spacer(),
                        const Icon(Icons.radio_rounded, size: 16, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        const Text(
                          '私人FM',
                          style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  const _PlaylistCard({required this.playlist});

  final Playlist playlist;

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      onTap: () {},
      builder: (context, hovered) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSlide(
            offset: hovered ? const Offset(0, -0.02) : Offset.zero,
            duration: const Duration(milliseconds: 180),
            child: Stack(
              children: [
                CoverArt(
                  palette: playlist.palette,
                  seed: playlist.id,
                  radius: AppRadius.panel,
                  shadow: hovered ? AppShadows.heavy : null,
                ),
                // 右上角播放量，下面垫一层渐变保证可读。
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(8, 8, 10, 16),
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.panel)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x66000000), Color(0x00000000)],
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Icon(Icons.play_arrow_rounded, size: 14, color: Colors.white),
                        Text(
                          formatPlayCount(playlist.playCount),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: AnimatedOpacity(
                    opacity: hovered ? 1 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: RoundIconButton(
                      icon: Icons.play_arrow_rounded,
                      onPressed: hovered ? () {} : null,
                      size: 44,
                      iconSize: 26,
                      filled: true,
                      background: AppColors.accent,
                      color: AppColors.onAccent,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            playlist.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: hovered ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
