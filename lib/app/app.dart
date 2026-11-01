import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../shell/app_shell.dart';
import '../state/player_controller.dart';
import '../theme/app_theme.dart';
import 'app_info.dart';

class NeteaseClientApp extends StatefulWidget {
  const NeteaseClientApp({super.key, this.autoplay = true});

  /// 预览时自动开始"播放"，方便直接看到进度和歌词滚动。测试里关掉。
  final bool autoplay;

  @override
  State<NeteaseClientApp> createState() => _NeteaseClientAppState();
}

class _NeteaseClientAppState extends State<NeteaseClientApp> {
  // 从第一句歌词前一点开始，打开歌词页就能看到逐字效果。
  late final PlayerController _player = PlayerController(
    queue: MockData.queue,
    initialPosition: const Duration(seconds: 10),
  );

  @override
  void initState() {
    super.initState();
    if (widget.autoplay) _player.play();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PlayerScope(
      controller: _player,
      child: MaterialApp(
        title: AppInfo.name,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        home: const AppShell(),
      ),
    );
  }
}
