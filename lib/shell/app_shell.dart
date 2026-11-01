import 'package:flutter/material.dart';

import '../pages/home_page.dart';
import '../pages/placeholder_page.dart';
import 'app_drawer.dart';
import 'destinations.dart';
import 'player_bar.dart';
import 'top_bar.dart';

/// 主框架（手机端）：顶栏 + 内容 + 迷你播放条 + 底部导航，点头像从左侧滑出抽屉。
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  Destination _current = Destination.forYou;

  /// 最近一次所在的底部标签。从抽屉进入的页面不属于任何标签，此时保持原高亮。
  int _tab = 0;

  Widget _page() => switch (_current) {
    Destination.forYou => const HomePage(),
    final d => PlaceholderPage(destination: d),
  };

  void _go(Destination d) => setState(() {
    _current = d;
    final i = Destination.tabs.indexOf(d);
    if (i >= 0) _tab = i;
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(onSelect: _go),
      // 抽屉打开时主界面压暗，和参考图一致。
      drawerScrimColor: Colors.black54,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const TopBar(),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: KeyedSubtree(key: ValueKey(_current), child: _page()),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PlayerBar(),
          NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => _go(Destination.tabs[i]),
            destinations: [
              for (final d in Destination.tabs)
                NavigationDestination(icon: Icon(d.icon), label: d.shortLabel),
            ],
          ),
        ],
      ),
    );
  }
}
