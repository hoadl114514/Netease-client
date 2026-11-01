import 'package:flutter/material.dart';

import '../pages/search_page.dart';
import '../theme/app_theme.dart';
import 'user_avatar.dart';

/// 顶栏：左侧头像（点开抽屉）+ 搜索框。
class TopBar extends StatelessWidget {
  const TopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Tooltip(
            message: '个人中心',
            child: GestureDetector(
              onTap: () => Scaffold.of(context).openDrawer(),
              child: const UserAvatar(size: 36),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(child: _SearchField()),
        ],
      ),
    );
  }
}

/// 顶栏上的搜索入口：点击进入搜索页（输入时有联想）。
class _SearchField extends StatelessWidget {
  const _SearchField();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '搜索',
      child: Material(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => SearchPage.start(context),
          child: const SizedBox(
            height: 40,
            child: Row(
              children: [
                SizedBox(width: 12),
                Icon(Icons.search_rounded, size: 20),
                SizedBox(width: 8),
                Text('搜索音乐、歌手', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
