import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../theme/app_theme.dart';
import 'destinations.dart';
import 'user_avatar.dart';

/// 左侧抽屉：个人资料卡、菜单、状态快捷入口、私信。
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, required this.onSelect});

  final ValueChanged<Destination> onSelect;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    void pick(Destination d) {
      Navigator.of(context).pop();
      onSelect(d);
    }

    return Drawer(
      width: (width * 0.9).clamp(280.0, 400.0),
      backgroundColor: AppColors.surfaceHigh,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
          children: [
            const _AccountCard(),
            const SizedBox(height: 8),
            for (final d in Destination.drawer) _MenuItem(destination: d, onTap: () => pick(d)),
            const SizedBox(height: 12),
            const _StatusRow(),
            const SizedBox(height: 28),
            const _Messages(),
          ],
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardHover,
      borderRadius: BorderRadius.circular(AppRadius.panel),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () {},
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  UserAvatar(size: 60),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          MockData.userName,
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '查看个人资料',
                          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.borderStrong),
          InkWell(
            onTap: () {},
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceHigh,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add_rounded, size: 20),
                  ),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('添加账号', style: TextStyle(fontSize: 16)),
                        Text(
                          '登录其他网易云账号',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.destination, required this.onTap});

  final Destination destination;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: SizedBox(
        height: 60,
        child: Row(
          children: [
            const SizedBox(width: 8),
            Icon(destination.icon, size: 28, color: AppColors.textPrimary),
            const SizedBox(width: 18),
            Text(destination.label, style: const TextStyle(fontSize: 17)),
          ],
        ),
      ),
    );
  }
}

/// 两个圆形快捷入口：听歌状态开关、添加好友。
class _StatusRow extends StatefulWidget {
  const _StatusRow();

  @override
  State<_StatusRow> createState() => _StatusRowState();
}

class _StatusRowState extends State<_StatusRow> {
  bool _sharing = true;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RoundEntry(
          onTap: () => setState(() => _sharing = !_sharing),
          circle: const UserAvatar(size: 60),
          label: '听歌状态',
          caption: _sharing ? '公开' : '隐藏',
          captionColor: _sharing ? AppColors.accent : AppColors.textMuted,
        ),
        const SizedBox(width: 16),
        _RoundEntry(
          onTap: () {},
          circle: Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(color: AppColors.cardHover, shape: BoxShape.circle),
            child: const Icon(Icons.add_rounded, size: 30, color: AppColors.textPrimary),
          ),
          label: '添加好友',
        ),
      ],
    );
  }
}

class _RoundEntry extends StatelessWidget {
  const _RoundEntry({
    required this.onTap,
    required this.circle,
    required this.label,
    this.caption,
    this.captionColor,
  });

  final VoidCallback onTap;
  final Widget circle;
  final String label;
  final String? caption;
  final Color? captionColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.panel),
      child: SizedBox(
        width: 84,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              circle,
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontSize: 15)),
              if (caption != null)
                Text(caption!, style: TextStyle(fontSize: 15, color: captionColor)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Messages extends StatelessWidget {
  const _Messages();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('私信', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const Icon(Icons.chevron_right_rounded, size: 28, color: AppColors.textPrimary),
              const Spacer(),
              IconButton(
                onPressed: () {},
                tooltip: '写私信',
                icon: const Icon(Icons.edit_square, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '还没有私信，和好友分享你的心头好吧。',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () {},
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    color: AppColors.cardHover,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit_square, color: AppColors.textSecondary),
                ),
                const SizedBox(width: 16),
                const Text('新私信', style: TextStyle(fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
