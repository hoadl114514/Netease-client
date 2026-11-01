import 'package:flutter/material.dart';

import '../pages/home_page.dart';
import '../pages/placeholder_page.dart';
import 'destinations.dart';
import 'player_bar.dart';
import 'sidebar.dart';
import 'top_bar.dart';

/// 主框架。宽屏：侧边栏 + 顶栏 + 内容 + 底部播放条；
/// 窄屏（< [compactBreakpoint]）：顶栏 + 内容 + 迷你播放条 + 底部导航。
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  static const compactBreakpoint = 840.0;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  Destination _current = Destination.forYou;

  Widget _page() => switch (_current) {
    Destination.forYou => const HomePage(),
    final d => PlaceholderPage(destination: d),
  };

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < AppShell.compactBreakpoint;
    final content = AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: KeyedSubtree(key: ValueKey(_current), child: _page()),
    );

    if (compact) {
      final index = Destination.mobile.indexOf(_current);
      return Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const TopBar(compact: true),
              Expanded(child: content),
            ],
          ),
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PlayerBar(compact: true),
            NavigationBar(
              selectedIndex: index < 0 ? 0 : index,
              onDestinationSelected: (i) => setState(() => _current = Destination.mobile[i]),
              destinations: [
                for (final d in Destination.mobile)
                  NavigationDestination(icon: Icon(d.icon), label: d.label),
              ],
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Sidebar(selected: _current, onSelect: (d) => setState(() => _current = d)),
                Expanded(
                  child: Column(
                    children: [
                      const TopBar(),
                      Expanded(child: content),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const PlayerBar(),
        ],
      ),
    );
  }
}
