import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netease_client/app/app.dart';
import 'package:netease_client/data/mock_data.dart';

void main() {
  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const NeteaseClientApp(autoplay: false));
    await tester.pump();
  }

  // 播放页背景是无限循环动画，不能用 pumpAndSettle。
  Future<void> settleRoute(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('desktop: home renders, lyrics opens split now-playing, collapses back', (
    tester,
  ) async {
    await pumpAt(tester, const Size(1600, 1000));
    expect(find.text('专属歌单'), findsOneWidget);
    expect(find.text('为我推荐'), findsOneWidget);

    await tester.tap(find.byTooltip('歌词'));
    await settleRoute(tester);
    // 宽屏分栏：歌词工具栏和封面信息同时可见。
    expect(find.byTooltip('复制当前歌词'), findsOneWidget);
    expect(find.byTooltip('随机播放'), findsOneWidget);

    await tester.tap(find.byTooltip('收起'));
    await settleRoute(tester);
    expect(find.byTooltip('收起'), findsNothing);
  });

  testWidgets('compact: bottom navigation, tapping mini player opens now-playing', (tester) async {
    await pumpAt(tester, const Size(400, 860));
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(find.text(MockData.current.title).last);
    await settleRoute(tester);
    expect(find.byTooltip('收起'), findsOneWidget);
    expect(find.byType(PageView), findsOneWidget);
  });
}
