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

class _SearchField extends StatefulWidget {
  const _SearchField();

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      borderSide: BorderSide.none,
    );
    return SizedBox(
      height: 40,
      child: TextField(
        controller: _input,
        textInputAction: TextInputAction.search,
        onSubmitted: (v) => SearchPage.open(context, v),
        style: const TextStyle(fontSize: 14),
        cursorColor: AppColors.accent,
        decoration: InputDecoration(
          hintText: '搜索音乐、歌手',
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
