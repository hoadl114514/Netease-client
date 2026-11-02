import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:netease_client/api/netease_api.dart';

NeteaseApi _api(Map<String, Object> routes, {List<http.Request>? seen}) => NeteaseApi(
  cookies: const {'MUSIC_U': 'u'},
  client: MockClient((r) async {
    seen?.add(r);
    final body = routes.entries
        .firstWhere(
          (e) => r.url.path.endsWith(e.key),
          orElse: () => const MapEntry('', {'code': 200}),
        )
        .value;
    return http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }),
);

Map<String, Object?> _user(int id, {int userType = 0}) => {
  'userId': id,
  'nickname': '用户$id',
  'avatarUrl': 'http://p1.music.126.net/$id.jpg',
  'userType': userType,
};

void main() {
  test('events parse text, pictures, shared song and forwarded events', () async {
    final api = _api({
      '/api/v1/event/get': {
        'code': 200,
        'more': true,
        'lasttime': 123,
        'events': [
          {
            'id': 1,
            'type': 18,
            'eventTime': 1700000000000,
            'user': _user(10, userType: 4),
            'json': jsonEncode({
              'msg': '好听',
              'song': {
                'id': 5,
                'name': '歌',
                'artists': [
                  {'id': 2, 'name': '歌手'},
                ],
                'album': {'id': 3, 'name': '专辑', 'picUrl': 'http://p1.music.126.net/c.jpg'},
              },
            }),
            'pics': [
              {'originUrl': 'http://p1.music.126.net/p.jpg'},
            ],
            'info': {
              'likedCount': 4,
              'liked': true,
              'commentCount': 2,
              'commentThread': {'id': 'A_EV_2_1_10'},
            },
          },
          {
            'id': 2,
            'type': 22,
            'eventTime': 1700000001000,
            'user': _user(11),
            'json': jsonEncode({
              'msg': '转发一下',
              'event': {
                'id': 1,
                'type': 13,
                'eventTime': 1700000000000,
                'user': _user(12),
                'json': jsonEncode({
                  'msg': '我的歌单',
                  'playlist': {'id': 9, 'name': '歌单', 'trackCount': 3},
                }),
              },
            }),
            'threadId': 'A_EV_2_2_11',
          },
          // 没有作者的脏数据跳过。
          {'id': 3, 'type': 35, 'json': '{}'},
        ],
      },
    });
    final page = await api.followFeed();
    expect(page.more, isTrue);
    expect(page.lasttime, 123);
    expect(page.events, hasLength(2));

    final first = page.events.first;
    expect(first.user.musician, isTrue);
    expect(first.user.avatarUrl, 'https://p1.music.126.net/10.jpg');
    expect(first.action, '分享单曲');
    expect(first.text, '好听');
    expect(first.pics.single, 'https://p1.music.126.net/p.jpg');
    expect(first.song!.title, '歌');
    expect(first.song!.coverUrl, 'https://p1.music.126.net/c.jpg');
    expect(first.threadId, 'A_EV_2_1_10');
    expect(first.liked, isTrue);
    expect(first.likedCount, 4);

    final fwd = page.events.last;
    expect(fwd.user.musician, isFalse);
    expect(fwd.action, '转发');
    expect(fwd.threadId, 'A_EV_2_2_11');
    expect(fwd.forwarded!.user.nickname, '用户12');
    expect(fwd.forwarded!.playlist!.name, '歌单');
  });

  test('user events page by lasttime', () async {
    final seen = <http.Request>[];
    final api = _api({
      '/api/event/get/7': {'code': 200, 'events': <Object>[], 'more': false, 'lasttime': 0},
    }, seen: seen);
    await api.userEvents(7, lasttime: 999);
    expect(seen.single.bodyFields['time'], '999');
  });

  test('follow and unfollow hit the follow / delfollow paths', () async {
    final seen = <http.Request>[];
    final api = _api({}, seen: seen);
    await api.setFollowed(42, true);
    await api.setFollowed(42, false);
    expect(seen.map((r) => r.url.path), ['/api/user/follow/42', '/api/user/delfollow/42']);
  });

  test('follow falls back to EAPI when the plain API is risk-controlled', () async {
    final seen = <http.Request>[];
    final api = NeteaseApi(
      cookies: const {'MUSIC_U': 'u'},
      client: MockClient((r) async {
        seen.add(r);
        final body = r.url.path.startsWith('/api/')
            ? {'code': -460, 'message': '网络环境存在风险'}
            : {'code': 200};
        return http.Response(jsonEncode(body), 200);
      }),
    );
    await api.setFollowed(42, true);
    expect(seen.map((r) => r.url.path), ['/api/user/follow/42', '/eapi/user/follow/42']);
  });

  test('follow does not retry when logged out', () async {
    final seen = <http.Request>[];
    final api = NeteaseApi(
      client: MockClient((r) async {
        seen.add(r);
        return http.Response(jsonEncode({'code': 301}), 200);
      }),
    );
    await expectLater(
      api.setFollowed(42, true),
      throwsA(isA<ApiException>().having((e) => e.needsLogin, 'needsLogin', isTrue)),
    );
    expect(seen, hasLength(1));
  });

  test('follows and fans lists', () async {
    final api = _api({
      '/api/user/getfollows/1': {
        'code': 200,
        'more': true,
        'follow': [
          {..._user(2), 'followed': true, 'signature': ' 签名 '},
        ],
      },
      '/eapi/user/getfolloweds/1': {
        'code': 200,
        'more': false,
        'followeds': [_user(3, userType: 2)],
      },
    });
    final follows = await api.userFollows(1);
    expect(follows.more, isTrue);
    expect(follows.users.single.followed, isTrue);
    expect(follows.users.single.signature, '签名');
    final fans = await api.userFolloweds(1);
    expect(fans.users.single.musician, isTrue);
  });

  test('conversations show a preview of the last message', () async {
    final api = _api({
      '/api/msg/private/users': {
        'code': 200,
        'more': false,
        'msgs': [
          {
            'fromUser': _user(5),
            'lastMsg': jsonEncode({'msg': '在吗'}),
            'lastMsgTime': 1700000000000,
            'newMsgCount': 2,
          },
          {
            'fromUser': _user(6),
            'lastMsg': jsonEncode({
              'msg': '',
              'song': {'id': 1, 'name': '某首歌'},
            }),
            'lastMsgTime': 1700000000000,
          },
        ],
      },
    });
    final page = await api.conversations();
    expect(page.items.first.preview, '在吗');
    expect(page.items.first.unread, 2);
    expect(page.items.last.preview, '[歌曲] 某首歌');
  });

  test('message history is sorted old to new and pages by time', () async {
    final seen = <http.Request>[];
    final api = _api({
      '/api/msg/private/history': {
        'code': 200,
        'more': true,
        'msgs': [
          {
            'id': 2,
            'time': 2000,
            'fromUser': _user(1),
            'msg': jsonEncode({'msg': '后'}),
          },
          {
            'id': 1,
            'time': 1000,
            'fromUser': _user(9),
            'msg': jsonEncode({
              'msg': '',
              'picInfo': {'picUrl': 'http://p1.music.126.net/i.jpg'},
            }),
          },
        ],
      },
    }, seen: seen);
    final h = await api.messageHistory(9, before: DateTime.fromMillisecondsSinceEpoch(5000));
    expect(seen.single.bodyFields['time'], '5000');
    expect(seen.single.bodyFields['userId'], '9');
    expect(h.more, isTrue);
    expect([for (final m in h.messages) m.id], [1, 2]);
    expect(h.messages.first.imageUrl, 'https://p1.music.126.net/i.jpg');
    expect(h.messages.last.text, '后');
    expect(h.messages.last.fromUserId, 1);
  });

  test('sending a message goes through EAPI', () async {
    final seen = <http.Request>[];
    final api = _api({}, seen: seen);
    await api.sendMessage(9, 'hi');
    expect(seen.single.url.path, '/eapi/msg/private/send');
  });

  test('liking an event uses its thread id', () async {
    final seen = <http.Request>[];
    final api = _api({}, seen: seen);
    await api.likeEvent('A_EV_2_1_10', true);
    await api.likeEvent('A_EV_2_1_10', false);
    expect(seen.map((r) => r.url.path), ['/api/resource/like', '/api/resource/unlike']);
    expect(seen.first.bodyFields['threadId'], 'A_EV_2_1_10');
  });
}
