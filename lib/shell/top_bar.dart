import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../theme/app_theme.dart';
import '../widgets/cover_art.dart';
import '../widgets/hover_builder.dart';
import '../widgets/round_icon_button.dart';

class TopBar extends StatelessWidget {
  const TopBar({super.key, this.compact = false});

  /// 窄屏：去掉前进后退，用户信息只留头像。
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 16 : 24, 16, compact ? 16 : 24, 8),
      child: Row(
        children: [
          if (!compact) ...[
            RoundIconButton(
              icon: Icons.chevron_left_rounded,
              onPressed: () {},
              tooltip: '后退',
              filled: true,
              iconSize: 24,
            ),
            const SizedBox(width: 12),
            RoundIconButton(
              icon: Icons.chevron_right_rounded,
              onPressed: () {},
              tooltip: '前进',
              filled: true,
              iconSize: 24,
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: const _SearchField(),
              ),
            ),
          ),
          const SizedBox(width: 16),
          _UserChip(compact: compact),
          if (!compact) ...[
            const SizedBox(width: 12),
            RoundIconButton(
              icon: Icons.settings_rounded,
              onPressed: () {},
              tooltip: '设置',
              filled: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField();

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      borderSide: BorderSide.none,
    );
    return SizedBox(
      height: 40,
      child: TextField(
        style: const TextStyle(fontSize: 14),
        cursorColor: AppColors.accent,
        decoration: InputDecoration(
          hintText: '搜索音乐、歌手、歌词',
          hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          filled: true,
          fillColor: AppColors.surfaceHigh,
          contentPadding: EdgeInsets.zero,
          border: border,
          enabledBorder: border,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            borderSide: const BorderSide(color: AppColors.outline),
          ),
        ),
      ),
    );
  }
}

class _UserChip extends StatelessWidget {
  const _UserChip({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    const avatar = ClipOval(
      child: SizedBox.square(
        dimension: 32,
        child: CoverArt(palette: MockData.likedPalette, seed: 'avatar', radius: 0),
      ),
    );
    if (compact) return avatar;

    return HoverBuilder(
      onTap: () {},
      builder: (context, hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
        decoration: BoxDecoration(
          color: hovered ? AppColors.cardHover : AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            avatar,
            const SizedBox(width: 10),
            const Text(
              MockData.userName,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.7)),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: const Text(
                'VIP',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accent,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down_rounded, size: 20),
          ],
        ),
      ),
    );
  }
}
