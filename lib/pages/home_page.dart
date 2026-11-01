import 'package:flutter/material.dart';

import '../data/format.dart';
import '../data/models.dart';
import '../shell/destinations.dart';
import '../state/account_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/cover_art.dart';
import '../widgets/dev_badge.dart';
import '../widgets/hover_builder.dart';
import '../widgets/round_icon_button.dart';
import 'library/playlist_page.dart';
import 'login_page.dart';

const _dailyPalette = [Color(0xFF3B2A4D), Color(0xFFB0605A), Color(0xFFE8B66B)];
const _likedPalette = [Color(0xFFE85A9A), Color(0xFF6A4BC4), Color(0xFF1F1A3A)];
const _fmPalette = [Color(0xFF1B1036), Color(0xFFE0367F), Color(0xFF29D3F0)];

/// 首页。推荐类功能（每日推荐、私人 FM、推荐歌单）待开发，先放我的歌单。
class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.onNavigate});

  final ValueChanged<Destination> onNavigate;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final hPad = width < 600 ? 16.0 : 24.0;
    final account = AccountScope.of(context);
    final playlists = account.playlists;

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
                    final shortcuts = Column(
                      children: [
                        _ShortcutCard(
                          title: '每日推荐',
                          subtitle: '根据你的音乐口味 · 每日更新',
                          icon: Icons.calendar_today_rounded,
                          palette: _dailyPalette,
                          seed: 'daily',
                          ready: false,
                          onTap: () => showNotReady('每日推荐'),
                        ),
                        const SizedBox(height: 16),
                        _ShortcutCard(
                          title: '我喜欢的音乐',
                          subtitle: account.isLoggedIn
                              ? '${account.likedPlaylist?.trackCount ?? 0} 首'
                              : '登录后查看',
                          icon: Icons.favorite_rounded,
                          palette: _likedPalette,
                          seed: 'liked',
                          onTap: () => onNavigate(Destination.liked),
                        ),
                      ],
                    );
                    if (c.maxWidth < 760) {
                      return Column(
                        children: [shortcuts, const SizedBox(height: 16), const _PersonalFmCard()],
                      );
                    }
                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: shortcuts),
                          const SizedBox(width: 20),
                          const Expanded(child: _PersonalFmCard()),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),
                const _SectionTitle('我的歌单'),
                const SizedBox(height: 16),
                if (!account.isLoggedIn)
                  const SizedBox(height: 220, child: LoginPrompt(message: '登录后查看你的歌单'))
                else if (playlists.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text('还没有歌单', style: TextStyle(color: AppColors.textSecondary)),
                    ),
                  ),
              ],
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 0),
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
                  itemCount: playlists.length,
                  itemBuilder: (context, i) => _PlaylistCard(playlist: playlists[i]),
                );
              },
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(hPad, 32, hPad, 32),
            sliver: const SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle('推荐歌单', ready: false),
                  SizedBox(height: 8),
                  Text('个性化推荐还在开发中', style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
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
        Text(switch (AccountScope.of(context).profile) {
          final p? => '${greetingFor(DateTime.now())}，${p.nickname}',
          null => greetingFor(DateTime.now()),
        }, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        const Text('由此开启好心情 ~', style: TextStyle(color: AppColors.textSecondary)),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.ready = true});

  final String title;
  final bool ready;

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
        if (!ready) ...[const SizedBox(width: 10), const DevBadge()],
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
    required this.onTap,
    this.ready = true,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> palette;
  final String seed;
  final VoidCallback onTap;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      onTap: onTap,
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
                    if (!ready) ...[const SizedBox(width: 8), const DevBadge()],
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
  const _PersonalFmCard();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.all(20),
      onTap: () => showNotReady('私人 FM'),
      child: Row(
        children: [
          const SizedBox(
            width: 96,
            child: CoverArt(
              palette: _fmPalette,
              seed: 'fm',
              radius: AppRadius.card,
              icon: Icons.radio_rounded,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('私人 FM', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(width: 10),
                    const DevBadge(),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  '根据你的口味连续播放',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  const _PlaylistCard({required this.playlist});

  final Playlist playlist;

  @override
  Widget build(BuildContext context) {
    void open() =>
        Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => PlaylistPage(playlist: playlist)));
    return HoverBuilder(
      onTap: open,
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
                  imageUrl: playlist.coverUrl,
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
                      onPressed: hovered ? open : null,
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
