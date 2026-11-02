import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:netease_client/app/app.dart';
import 'package:netease_client/data/models.dart';
import 'package:netease_client/pages/social/follow_page.dart';
import 'package:netease_client/pages/social/messages_page.dart';
import 'package:netease_client/state/account_controller.dart';
import 'package:netease_client/state/player_controller.dart';

import 'support/fakes.dart';

http.Response _json(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, Object?> _event(int id, int userId, String text, {int userType = 0}) => {
  'id': id,
  'type': 35,
  'eventTime': 1700000000000 + id,
  'user': {'userId': userId, 'nickname': '用户$userId', 'userType': userType},
  'json': jsonEncode({'msg': text}),
  'info': {'threadId': 'A_EV_2_${id}_$userId'},
};

/// 已登录（uid 1）的假接口。[sent] 记录发出去的私信。
MockClient _client({List<http.Request>? sent}) => MockClient((r) async {
  final path = r.url.path;
  if (path == '/api/nuser/account/get') {
    return _json({
      'code': 200,
      'profile': {'userId': 1, 'nickname': '我'},
    });
  }
  if (path == '/api/user/getfollows/1') {
    return _json({
      'code': 200,
      'more': false,
      'follow': [
        {'userId': 2, 'nickname': '好友甲', 'followed': true},
      ],
    });
  }
  if (path == '/api/v1/event/get') {
    return _json({
      'code': 200,
      'more': false,
      'lasttime': 0,
      'events': [_event(1, 2, '朋友的动态'), _event(2, 3, '音乐人的动态', userType: 4)],
    });
  }
  if (path == '/api/msg/private/history') {
    return _json({
      'code': 200,
      'more': false,
      'msgs': [
        {
          'id': 7,
          'time': 1700000000000,
          'fromUser': {'userId': 2, 'nickname': '好友甲'},
          'msg': jsonEncode({'msg': '在吗'}),
        },
      ],
    });
  }
  if (path == '/eapi/msg/private/send') {
    sent?.add(r);
    return _json({'code': 200});
  }
  return _json({'code': 200});
});

Future<void> _pump(WidgetTester tester, MockClient client, Widget page) async {
  tester.view.physicalSize = const Size(400, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final f = await fakeServices(client: client);
  await f.services.account.loginWithCookies({'MUSIC_U': 'x'});
  await tester.pumpWidget(
    AppScope(
      services: f.services,
      child: AccountScope(
        controller: f.services.account,
        child: PlayerScope(
          controller: f.services.player,
          child: MaterialApp(home: Scaffold(body: page)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('follow tab shows followed friends and their feed, filtered by kind', (tester) async {
    await _pump(tester, _client(), const FollowPage());
    expect(find.text('好友甲'), findsOneWidget);
    expect(find.text('全部好友'), findsOneWidget);
    expect(find.text('我的关注'), findsOneWidget);
    expect(find.text('朋友的动态'), findsOneWidget);
    expect(find.text('音乐人的动态'), findsOneWidget);

    await tester.tap(find.text('音乐人'));
    await tester.pumpAndSettle();
    expect(find.text('朋友的动态'), findsNothing);
    expect(find.text('音乐人的动态'), findsOneWidget);

    await tester.tap(find.text('朋友'));
    await tester.pumpAndSettle();
    expect(find.text('朋友的动态'), findsOneWidget);
    expect(find.text('音乐人的动态'), findsNothing);
  });

  testWidgets('chat shows history and appends a sent message', (tester) async {
    final sent = <http.Request>[];
    await _pump(
      tester,
      _client(sent: sent),
      const ChatPage(user: SocialUser(userId: 2, nickname: '好友甲')),
    );
    expect(find.text('在吗'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '在的');
    await tester.tap(find.byTooltip('发送'));
    await tester.pumpAndSettle();
    expect(sent, hasLength(1));
    expect(find.text('在的'), findsOneWidget);
  });
}
