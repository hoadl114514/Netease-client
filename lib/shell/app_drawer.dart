import 'package:flutter/material.dart';

import '../pages/login_page.dart';
import '../state/account_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/dev_badge.dart';
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
    final account = AccountScope.of(context);
    final profile = account.profile;
    void login() {
      Navigator.of(context).pop();
      LoginPage.open(context);
    }

    return Material(
      color: AppColors.cardHover,
      borderRadius: BorderRadius.circular(AppRadius.panel),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: profile == null ? login : () => showNotReady('个人主页'),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const UserAvatar(size: 60),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile?.nickname ?? '未登录',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          profile == null ? '点击登录' : '查看个人资料',
                          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
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
            onTap: login,
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
                        Text('切换账号', style: TextStyle(fontSize: 16)),
                        Text(
                          '登录另一个账号',
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
            if (!destination.ready) ...[const SizedBox(width: 10), const DevBadge()],
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
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RoundEntry(
          onTap: () => showNotReady('听歌状态'),
          circle: const UserAvatar(size: 60),
          label: '听歌状态',
          caption: '待开发',
          captionColor: AppColors.textMuted,
        ),
        const SizedBox(width: 16),
        _RoundEntry(
          onTap: () => showNotReady('添加好友'),
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
              const SizedBox(width: 8),
              const DevBadge(),
              const Spacer(),
              IconButton(
                onPressed: () => showNotReady('私信'),
                tooltip: '写私信',
                icon: const Icon(Icons.edit_square, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('私信功能还在开发中。', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          InkWell(
            onTap: () => showNotReady('私信'),
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
