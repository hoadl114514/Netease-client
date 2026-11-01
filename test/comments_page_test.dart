import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:netease_client/app/app.dart';
import 'package:netease_client/data/models.dart';
import 'package:netease_client/pages/comments/comments_page.dart';

import 'support/fakes.dart';

Map<String, Object?> rawComment(int id, {int replies = 0, String content = '评论'}) => {
  'commentId': id,
  'content': content,
  'time': DateTime(2026, 3, 8).millisecondsSinceEpoch,
  'likedCount': id * 1000,
  'replyCount': replies,
  'user': {'userId': id, 'nickname': '用户$id'},
  'ipLocation': {'location': '广东'},
};

void main() {
  testWidgets('comments list, sort tabs and floor replies', (tester) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final sorts = <String>[];
    final client = MockClient((r) async {
      final path = r.url.path;
      Object body = {'code': 200};
      if (path.endsWith('/v2/resource/comments')) {
        sorts.add(r.bodyFields['sortType']!);
        final hot = r.bodyFields['sortType'] == '2';
        body = {
          'code': 200,
          'data': {
            'totalCount': 12345,
            'hasMore': false,
            'cursor': '0',
            'comments': [
              rawComment(1, replies: 2, content: hot ? '热门评论' * 30 : '最新评论'),
              rawComment(2),
            ],
          },
        };
      } else if (path.endsWith('/comment/floor/get')) {
        body = {
          'code': 200,
          'data': {
            'totalCount': 2,
            'hasMore': false,
            'time': 1,
            'comments': [
              {
                ...rawComment(3, content: '楼中楼回复'),
                'beReplied': [
                  {
                    'beRepliedCommentId': 1,
                    'content': '热门评论',
                    'user': {'nickname': '用户1'},
                  },
                ],
              },
              {
                ...rawComment(4, content: '回复楼中楼'),
                'beReplied': [
                  {
                    'beRepliedCommentId': 3,
                    'content': '楼中楼回复',
                    'user': {'nickname': '用户3'},
                  },
                ],
              },
            ],
          },
        };
      }
      return http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});
    });
    final f = await fakeServices(client: client);
    await tester.pumpWidget(NeteaseClientApp(services: f.services));
    await tester.pump();
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) =>
            const CommentsPage(target: CommentTarget.song, id: '1', title: '晴天', subtitle: '周杰伦'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('评论（1.2万）'), findsOneWidget);
    expect(find.text('晴天'), findsOneWidget);
    expect(find.textContaining('热门评论'), findsOneWidget);
    expect(find.text('2 条回复 >'), findsOneWidget);
    expect(find.textContaining(' · 广东'), findsNWidgets(2));
    expect(sorts, ['2']);

    await tester.tap(find.text('最新'));
    await tester.pumpAndSettle();
    expect(find.text('最新评论'), findsOneWidget);
    expect(sorts, ['2', '3']);

    await tester.tap(find.text('热门'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2 条回复 >'));
    await tester.pumpAndSettle();
    expect(find.text('回复（2）'), findsOneWidget);
    // 直接回复楼主的不显示「回复 @」，回复楼里别人的才显示。
    expect(find.text('楼中楼回复'), findsOneWidget);
    expect(find.textContaining('回复 @用户3：'), findsOneWidget);
    expect(find.text('回复 @用户1'), findsOneWidget); // 输入框默认回复楼主。

    // 长按评论：复制 / 回复（未登录看不到删除）。
    await tester.longPress(find.text('楼中楼回复'));
    await tester.pumpAndSettle();
    expect(find.text('复制评论'), findsOneWidget);
    expect(find.text('删除'), findsNothing);
  });
}
