import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:netease_client/app/app.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('comment count shows on the cover page right away, also after switching songs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final client = MockClient((r) async {
      if (r.url.path.endsWith('/v2/resource/comments')) {
        final thread = r.bodyFields['threadId']!;
        final total = thread.endsWith('_1') ? 11 : 22;
        return http.Response(
          jsonEncode({
            'code': 200,
            'data': {'totalCount': total, 'hasMore': false, 'cursor': '0', 'comments': []},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{"code":200}', 200);
    });
    final f = await fakeServices(client: client);
    await tester.pumpWidget(NeteaseClientApp(services: f.services));
    await f.services.player.playQueue([song('1'), song('2')], title: '测试');
    await f.services.player.pause();
    await tester.pump();

    Future<void> settle([int steps = 10]) async {
      for (var i = 0; i < steps; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await tester.tap(find.text('歌曲1').last);
    await settle();
    expect(find.text('11'), findsOneWidget);

    await f.services.player.next();
    await f.services.player.pause();
    await settle();
    expect(find.text('22'), findsOneWidget);
  });
}
