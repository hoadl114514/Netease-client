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
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  const phone = Size(400, 860);

  testWidgets('home renders with bottom navigation', (tester) async {
    await pumpAt(tester, phone);
    expect(find.text('专属歌单'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('avatar opens drawer; drawer item navigates and closes it', (tester) async {
    await pumpAt(tester, phone);
    await tester.tap(find.byTooltip('个人中心'));
    await settle(tester);
    expect(find.text('查看个人资料'), findsOneWidget);
    expect(find.text('听歌排行'), findsOneWidget);

    await tester.tap(find.text('最近播放'));
    await settle(tester);
    expect(find.text('查看个人资料'), findsNothing);
    expect(find.text('施工中…'), findsOneWidget);
  });

  testWidgets('mini player opens now-playing pages and collapses back', (tester) async {
    await pumpAt(tester, phone);
    await tester.tap(find.text(MockData.current.title).last);
    await settle(tester);
    expect(find.byType(PageView), findsOneWidget);

    await tester.tap(find.byTooltip('收起'));
    await settle(tester);
    expect(find.byTooltip('收起'), findsNothing);
  });

  testWidgets('lyrics button opens lyrics page directly', (tester) async {
    await pumpAt(tester, phone);
    await tester.tap(find.byTooltip('歌词'));
    await settle(tester);
    expect(find.byTooltip('复制当前歌词'), findsOneWidget);
  });
}
