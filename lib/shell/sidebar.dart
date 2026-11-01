import 'package:flutter/material.dart';

import '../app/app_info.dart';
import '../data/mock_data.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/cover_art.dart';
import '../widgets/hover_builder.dart';
import 'destinations.dart';

class Sidebar extends StatefulWidget {
  const Sidebar({super.key, required this.selected, required this.onSelect});

  final Destination selected;
  final ValueChanged<Destination> onSelect;

  static const width = 240.0;

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  bool _createdExpanded = true;
  bool _collectedExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: Sidebar.width,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Logo(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
              children: [
                for (final d in Destination.primary) _navItem(d),
                const _Divider(),
                for (final d in Destination.library) _navItem(d),
                const _Divider(),
                _SectionHeader(
                  title: '创建的歌单',
                  expanded: _createdExpanded,
                  onToggle: () => setState(() => _createdExpanded = !_createdExpanded),
                  showActions: true,
                ),
                if (_createdExpanded)
                  for (final p in MockData.created) _PlaylistItem(playlist: p),
                _SectionHeader(
                  title: '收藏的歌单',
                  expanded: _collectedExpanded,
                  onToggle: () => setState(() => _collectedExpanded = !_collectedExpanded),
                ),
                if (_collectedExpanded)
                  for (final p in MockData.recommended.take(4)) _PlaylistItem(playlist: p),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(Destination d) =>
      _NavItem(destination: d, selected: widget.selected == d, onTap: () => widget.onSelect(d));
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
            child: const Icon(Icons.music_note_rounded, color: AppColors.onAccent, size: 20),
          ),
          const SizedBox(width: 12),
          const Flexible(
            child: Text(
              AppInfo.name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.destination, required this.selected, required this.onTap});

  final Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      onTap: onTap,
      builder: (context, hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 44,
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.cardHover
              : hovered
              ? AppColors.surfaceHigh
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Row(
          children: [
            // 选中项左侧的粉色指示条。
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 3,
              height: selected ? 18 : 0,
              margin: const EdgeInsets.only(right: 11),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            Icon(
              destination.icon,
              size: 20,
              color: selected ? AppColors.accent : AppColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                destination.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  color: selected || hovered ? AppColors.textPrimary : AppColors.textSecondary,
                ),
              ),
            ),
            if (destination == Destination.liked)
              Tooltip(
                message: '心动模式',
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: const Icon(Icons.monitor_heart_outlined, size: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) =>
      const Padding(padding: EdgeInsets.symmetric(vertical: 10, horizontal: 8), child: Divider());
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.expanded,
    required this.onToggle,
    this.showActions = false,
  });

  final String title;
  final bool expanded;
  final VoidCallback onToggle;
  final bool showActions;

  @override
  Widget build(BuildContext context) {
    Widget pill(IconData icon, String tip) => Tooltip(
      message: tip,
      child: Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Icon(icon, size: 14),
      ),
    );

    return HoverBuilder(
      onTap: onToggle,
      builder: (context, hovered) => Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 6, 6),
        child: Row(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                color: hovered ? AppColors.textSecondary : AppColors.textMuted,
              ),
            ),
            if (showActions) ...[pill(Icons.sort_rounded, '排序'), pill(Icons.add_rounded, '新建歌单')],
            const Spacer(),
            AnimatedRotation(
              turns: expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaylistItem extends StatelessWidget {
  const _PlaylistItem({required this.playlist});

  final Playlist playlist;

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      onTap: () {},
      builder: (context, hovered) => Container(
        height: 52,
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: hovered ? AppColors.surfaceHigh : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 38,
              child: CoverArt(palette: playlist.palette, seed: playlist.id, radius: 6),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playlist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14),
                  ),
                  Text(
                    '${playlist.trackCount} 首',
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
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
