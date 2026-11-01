import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:netease_client/app/app.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('typing shows predictions; submitting shows result tabs', (tester) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final client = MockClient((r) async {
      final path = r.url.path;
      final Object body = path.endsWith('/suggest/keyword')
          ? {
              'code': 200,
              'result': {
                'allMatch': [
                  {'keyword': '晴天'},
                  {'keyword': '晴天娃娃'},
                ],
              },
            }
          : path.endsWith('/hotsearchlist/get')
          ? {
              'code': 200,
              'data': [
                {'searchWord': '热搜一'},
              ],
            }
          : {'code': 200};
      return http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});
    });
    final f = await fakeServices(client: client);
    await tester.pumpWidget(NeteaseClientApp(services: f.services));
    await tester.pump();

    await tester.tap(find.text('搜索音乐、歌手'));
    await tester.pumpAndSettle();
    expect(find.text('热搜一'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '晴');
    await tester.pump(const Duration(milliseconds: 300)); // 防抖。
    await tester.pumpAndSettle();
    expect(find.text('晴天娃娃'), findsOneWidget);
    expect(find.text('单曲'), findsNothing);

    await tester.tap(find.text('晴天娃娃'));
    await tester.pumpAndSettle();
    expect(find.text('单曲'), findsOneWidget);
    expect(find.text('专辑'), findsOneWidget);
    expect(find.widgetWithText(TextField, '晴天娃娃'), findsOneWidget);
  });
}
