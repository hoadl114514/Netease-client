import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:netease_client/api/netease_api.dart';

/// 返回 [routes] 里路径匹配的响应，并记录请求。
NeteaseApi apiWith(
  Map<String, Object> routes, {
  List<http.Request>? seen,
  Map<String, String> cookies = const {},
}) => NeteaseApi(
  cookies: cookies,
  client: MockClient((r) async {
    seen?.add(r);
    final body = routes.entries.firstWhere((e) => r.url.path.endsWith(e.key)).value;
    return http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }),
);

Map<String, Object> rawSong(int id, {int artistId = 7, int albumId = 9}) => {
  'id': id,
  'name': '歌$id',
  'ar': [
    {'id': artistId, 'name': '歌手'},
  ],
  'al': {'id': albumId, 'name': '专辑', 'picUrl': 'http://p1.music.126.net/a.jpg'},
  'dt': 1000,
};

void main() {
  test('songs carry artist and album ids for navigation', () async {
    final api = apiWith({
      '/recommend/songs': {
        'code': 200,
        'data': {
          'dailySongs': [rawSong(1)],
        },
      },
    });
    final s = (await api.dailySongs()).single;
    expect(s.artists.single.id, '7');
    expect(s.artists.single.name, '歌手');
    expect(s.albumId, '9');
    expect(s.coverUrl, 'https://p1.music.126.net/a.jpg');
  });

  test('personal FM reads the old song format (artists / album)', () async {
    final api = apiWith({
      '/radio/get': {
        'code': 200,
        'data': [
          {
            'id': 3,
            'name': 'FM',
            'artists': [
              {'id': 1, 'name': 'A'},
            ],
            'album': {'id': 2, 'name': 'B', 'picUrl': 'https://x/y.jpg'},
            'duration': 2000,
          },
        ],
      },
    });
    final s = (await api.personalFm()).single;
    expect(s.artist, 'A');
    expect(s.albumId, '2');
    expect(s.duration, const Duration(seconds: 2));
  });

  test('recommendPlaylists uses daily resources when logged in, personalized otherwise', () async {
    final seen = <http.Request>[];
    final routes = <String, Object>{
      '/recommend/resource': {
        'code': 200,
        'recommend': [
          {'id': 1, 'name': '私人雷达', 'picUrl': 'http://p/x.jpg', 'playcount': 5, 'trackCount': 3},
        ],
      },
      '/personalized/playlist': {
        'code': 200,
        'result': [
          {'id': 2, 'name': '通用', 'picUrl': 'http://p/y.jpg', 'playCount': 8},
        ],
      },
    };
    final logged = apiWith(routes, seen: seen, cookies: {'MUSIC_U': 'x'});
    final p = (await logged.recommendPlaylists()).single;
    expect(p.name, '私人雷达');
    expect(p.playCount, 5);
    expect(p.coverUrl, 'https://p/x.jpg');

    final anon = apiWith(routes, seen: seen);
    expect((await anon.recommendPlaylists()).single.name, '通用');
    expect(seen.last.url.path, endsWith('/personalized/playlist'));
  });

  test('toplists expose the update frequency', () async {
    final api = apiWith({
      '/toplist': {
        'code': 200,
        'list': [
          {'id': 19723756, 'name': '飙升榜', 'updateFrequency': '每天更新', 'coverImgUrl': 'http://c'},
        ],
      },
    });
    final t = (await api.toplists()).single;
    expect(t.name, '飙升榜');
    expect(t.description, '每天更新');
  });

  test('playRecord picks week or all data with play counts', () async {
    final seen = <http.Request>[];
    final api = apiWith({
      '/play/record': {
        'code': 200,
        'weekData': [
          {'playCount': 37, 'song': rawSong(1)},
        ],
        'allData': [
          {'playCount': 159, 'song': rawSong(2)},
        ],
      },
    }, seen: seen);
    final week = await api.playRecord(42);
    expect(week.single.playCount, 37);
    expect(seen.last.bodyFields['type'], '1');
    final all = await api.playRecord(42, weekly: false);
    expect(all.single.song.id, '2');
    expect(seen.last.bodyFields['type'], '0');
  });

  test('recentSongs unwraps data.list[].data', () async {
    final api = apiWith({
      '/song/list': {
        'code': 200,
        'data': {
          'list': [
            {'resourceId': '1', 'data': rawSong(1)},
          ],
        },
      },
    });
    expect((await api.recentSongs()).single.title, '歌1');
  });

  test('artistDetail and album parse info, album songs get the album cover', () async {
    final api = apiWith({
      '/artist/6452': {
        'code': 200,
        'artist': {
          'id': 6452,
          'name': '周杰伦',
          'img1v1Url': 'http://a.jpg',
          'briefDesc': '简介',
          'musicSize': 589,
          'albumSize': 47,
        },
        'hotSongs': [rawSong(1)],
      },
      '/album/18903': {
        'code': 200,
        'album': {
          'id': 18903,
          'name': '七里香',
          'picUrl': 'http://cover.jpg',
          'publishTime': 1091462400000,
          'size': 10,
          'artists': [
            {'id': 6452, 'name': '周杰伦'},
          ],
        },
        'songs': [
          {
            'id': 5,
            'name': '我的地盘',
            'ar': [
              {'id': 6452, 'name': '周杰伦'},
            ],
            'al': {'id': 18903, 'name': '七里香'},
            'dt': 1,
          },
        ],
      },
    });
    final a = await api.artistDetail('6452');
    expect(a.artist.avatarUrl, 'https://a.jpg');
    expect(a.artist.songCount, 589);
    expect(a.hotSongs, hasLength(1));

    final al = await api.album('18903');
    expect(al.album.artist, '周杰伦');
    expect(al.album.publishTime!.year, 2004);
    expect(al.songs.single.coverUrl, 'https://cover.jpg');
    expect(al.songs.single.albumId, '18903');
  });

  test('addToPlaylist sends op, pid and numeric track ids; errors surface', () async {
    final seen = <http.Request>[];
    final ok = apiWith({
      '/manipulate/tracks': {'code': 200},
    }, seen: seen);
    await ok.addToPlaylist('100', ['1', '2']);
    expect(seen.last.bodyFields, containsPair('op', 'add'));
    expect(seen.last.bodyFields, containsPair('pid', '100'));
    expect(seen.last.bodyFields, containsPair('trackIds', '[1,2]'));

    final blocked = apiWith({
      '/manipulate/tracks': {'code': -462, 'message': '检测到您的网络环境存在风险，请稍后再试'},
    });
    await expectLater(
      blocked.addToPlaylist('100', ['1']),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', -462)),
    );
  });

  test('search by type reads the matching result list and count', () async {
    final api = apiWith({
      '/cloudsearch/pc': {
        'code': 200,
        'result': {
          'artistCount': 84,
          'artists': [
            {'id': 6452, 'name': '周杰伦', 'picUrl': 'http://p.jpg'},
          ],
        },
      },
    });
    final r = await api.searchArtists('周杰伦');
    expect(r.total, 84);
    expect(r.items.single.avatarUrl, 'https://p.jpg');
  });
}
