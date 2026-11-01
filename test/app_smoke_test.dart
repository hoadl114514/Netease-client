import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netease_client/app/app.dart';
import 'package:netease_client/data/models.dart';
import 'package:netease_client/pages/now_playing/now_playing_page.dart';

import 'support/fakes.dart';

void main() {
  final queue = [song('1'), song('2')];

  Future<FakeBackend> pumpApp(WidgetTester tester, {bool withQueue = true}) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final f = await fakeServices();
    f.backend.qualityMap['1'] = [AudioQuality.standard, AudioQuality.exhigh, AudioQuality.lossless];
    f.backend.lyricsMap[('1', LyricSource.netease)] = karaoke();
    await tester.pumpWidget(NeteaseClientApp(services: f.services));
    if (withQueue) {
      await f.services.player.playQueue(queue, title: '测试歌单');
      await f.services.player.pause();
    }
    await tester.pump();
    return f.backend;
  }

  // 播放页背景动画和进度计时器不会停，不能用 pumpAndSettle。
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('home shows login prompts and pending features when logged out', (tester) async {
    await pumpApp(tester, withQueue: false);
    expect(find.text('我的歌单'), findsOneWidget);
    expect(find.text('登录后查看你的歌单'), findsOneWidget);
    expect(find.text('待开发'), findsWidgets);
    expect(find.byType(NavigationBar), findsOneWidget);
    // 没有在放的歌时不显示迷你播放条。
    expect(find.byTooltip('歌词'), findsNothing);
  });

  testWidgets('avatar opens drawer; unfinished pages say 待开发', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('个人中心'));
    await settle(tester);
    expect(find.text('未登录'), findsOneWidget);
    expect(find.text('听歌排行'), findsOneWidget);

    await tester.tap(find.text('最近播放'));
    await settle(tester);
    expect(find.text('未登录'), findsNothing);
    expect(find.text('最近播放'), findsOneWidget);
  });

  testWidgets('settings tab exposes quality, lyric source and cookie login', (tester) async {
    await pumpApp(tester, withQueue: false);
    await tester.tap(find.byTooltip('个人中心'));
    await settle(tester);
    await tester.tap(find.text('设置'));
    await settle(tester);
    expect(find.text('默认音质'), findsOneWidget);
    expect(find.text('默认歌词来源'), findsOneWidget);
    await tester.tap(find.text('Cookie 登录'));
    await settle(tester);
    expect(find.text('验证并登录'), findsOneWidget);
  });

  testWidgets('now playing: quality sheet lists only offered qualities', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('歌曲1').last);
    await settle(tester);
    expect(find.byType(NowPlayingPage), findsOneWidget);
    expect(find.text('测试歌单'), findsOneWidget);

    await tester.tap(find.text('极高')); // 默认 exhigh。
    await settle(tester);
    expect(find.text('无损'), findsOneWidget);
    expect(find.text('标准'), findsOneWidget);
    expect(find.text('Hi-Res'), findsNothing);
    expect(find.text('超清母带'), findsNothing);

    await tester.tap(find.text('无损'));
    await settle(tester);
    expect(find.text('无损'), findsOneWidget); // 进度条下方的音质标签。
  });

  testWidgets('lyrics page shows lyrics; menu switches source and offset', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('歌词'));
    await settle(tester);
    expect(find.byType(NowPlayingPage), findsOneWidget);
    expect(find.text('第0行翻译'), findsOneWidget);

    // 播放页里切回封面再切回歌词。
    await tester.tap(find.byTooltip('关闭歌词'));
    await settle(tester);
    expect(find.text('第0行翻译'), findsNothing);
    await tester.tap(find.byTooltip('歌词'));
    await settle(tester);
    expect(find.text('第0行翻译'), findsOneWidget);

    await tester.tap(find.byTooltip('更多'));
    await settle(tester);
    expect(find.text('歌词来源'), findsOneWidget);
    expect(find.textContaining('网易云 · 逐字 · 翻译'), findsOneWidget);
    await tester.tap(find.byTooltip('歌词提前 0.5s'));
    await tester.pump();
    expect(find.text('+0.5s'), findsOneWidget);

    // QQ 没有歌词：保留原歌词并提示。
    await tester.tap(find.text('QQ 音乐').last);
    await settle(tester);
    expect(find.text('QQ 音乐没有这首歌的歌词'), findsOneWidget);
  });
}
