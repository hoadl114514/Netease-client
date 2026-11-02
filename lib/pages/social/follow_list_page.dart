import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../data/models.dart';
import '../../state/account_controller.dart';
import '../music/nav.dart';
import 'paged_list.dart';
import 'social_widgets.dart';

/// 关注 / 粉丝列表（两个标签）。从用户主页头部的关注数、粉丝数进来。
class FollowListPage extends StatelessWidget {
  const FollowListPage({super.key, required this.userId, required this.name, this.fans = false});

  final int userId;
  final String name;

  /// true 时先显示「粉丝」标签。
  final bool fans;

  static Future<void> open(BuildContext context, int userId, String name, {bool fans = false}) =>
      SubPage.push(context, FollowListPage(userId: userId, name: name, fans: fans));

  @override
  Widget build(BuildContext context) {
    final api = AppScope.of(context).api;
    final self = AccountScope.of(context).profile?.userId == userId;
    const limit = 30;
    return DefaultTabController(
      length: 2,
      initialIndex: fans ? 1 : 0,
      child: SubPage(
        title: name,
        body: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: '关注'),
                Tab(text: '粉丝'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  PagedListView<SocialUser>(
                    empty: self ? '还没有关注任何人' : 'TA 还没有关注任何人',
                    loginHint: '登录后查看关注列表',
                    load: (cursor) async {
                      final offset = cursor as int? ?? 0;
                      final page = await api.userFollows(userId, offset: offset, limit: limit);
                      return (
                        // 自己的关注列表里每个人当然都已关注。
                        items: [for (final u in page.users) self ? u.copyWith(followed: true) : u],
                        more: page.more,
                        next: offset + page.users.length,
                      );
                    },
                    itemBuilder: (context, u, _) => SocialUserTile(user: u),
                  ),
                  PagedListView<SocialUser>(
                    empty: self ? '还没有粉丝' : 'TA 还没有粉丝',
                    loginHint: '登录后查看粉丝列表',
                    load: (cursor) async {
                      final offset = cursor as int? ?? 0;
                      final page = await api.userFolloweds(userId, offset: offset, limit: limit);
                      return (items: page.users, more: page.more, next: offset + page.users.length);
                    },
                    itemBuilder: (context, u, _) => SocialUserTile(user: u),
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
