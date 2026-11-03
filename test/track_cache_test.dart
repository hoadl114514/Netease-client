import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:netease_client/api/netease_api.dart';
import 'package:netease_client/data/models.dart';
import 'package:netease_client/data/track_cache.dart';

void main() {
  late List<String> serverIds;
  late List<List<String>> detailRequests;
  late NeteaseApi api;

  setUp(() {
    serverIds = ['1', '2', '3'];
    detailRequests = [];
    api = NeteaseApi(
      client: MockClient((r) async {
        final Object body;
        if (r.url.path == '/api/v6/playlist/detail') {
          body = {
            'code': 200,
            'playlist': {
              'id': 9,
              'name': '我喜欢的音乐',
              'trackIds': [
                for (final id in serverIds) {'id': int.parse(id)},
              ],
            },
          };
        } else if (r.url.path == '/api/v3/song/detail') {
          final ids = [
            for (final e in jsonDecode(r.bodyFields['c']!) as List) '${(e as Map)['id']}',
          ];
          detailRequests.add(ids);
          body = {
            'code': 200,
            'songs': [
              for (final id in ids)
                {
                  'id': int.parse(id),
                  'name': '歌$id',
                  'dt': 1000,
                  'ar': [
                    {'id': 7, 'name': '歌手'},
                  ],
                  'al': {'id': 3, 'name': '专辑', 'picUrl': 'http://p1.music.126.net/$id.jpg'},
                },
            ],
          };
        } else {
          body = {'code': 200};
        }
        return http.Response(
          jsonEncode(body),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
  });

  List<List<String>> ids(List<List<Song>> lists) => [
    for (final l in lists) [for (final s in l) s.id],
  ];

  test('song survives a JSON round trip', () {
    const s = Song(
      id: '1',
      title: '歌',
      artist: 'A / B',
      album: '专辑',
      duration: Duration(seconds: 200),
      coverUrl: 'https://p1/1.jpg',
      subtitle: '(TV)',
      albumId: '3',
      artists: [ArtistRef('7', 'A'), ArtistRef('8', 'B')],
    );
    final back = Song.fromJson(jsonDecode(jsonEncode(s.toJson())))!;
    expect(back.title, '歌');
    expect(back.duration, s.duration);
    expect(back.coverUrl, s.coverUrl);
    expect(back.subtitle, s.subtitle);
    expect(back.albumId, '3');
    expect([for (final a in back.artists) a.name], ['A', 'B']);
    expect(Song.fromJson({'id': 1}), isNull);
  });

  test('first load fetches everything and saves it', () async {
    final store = MemoryTrackStore();
    final emitted = await PlaylistTracks(api, store: store).watch('9').toList();
    expect(ids(emitted), [
      ['1', '2', '3'],
    ]);
    await pumpEventQueue();
    expect(store.data.keys, ['pl_9']);
  });

  test('later loads show the cache first and only fetch new songs', () async {
    final store = MemoryTrackStore();
    await PlaylistTracks(api, store: store).watch('9').drain<void>();
    await pumpEventQueue();
    detailRequests.clear();

    // 新增了 4、取消喜欢了 2，顺序也变了。
    serverIds = ['4', '3', '1'];
    final emitted = await PlaylistTracks(api, store: store).watch('9').toList();
    expect(ids(emitted), [
      ['1', '2', '3'],
      ['4', '3', '1'],
    ]);
    expect(detailRequests, [
      ['4'],
    ]);
    expect(emitted.last.first.title, '歌4');
  });

  test('nothing changed: the cache is shown once and no details are fetched', () async {
    final tracks = PlaylistTracks(api, store: MemoryTrackStore());
    await tracks.watch('9').drain<void>();
    detailRequests.clear();
    final emitted = await tracks.watch('9').toList();
    expect(ids(emitted), [
      ['1', '2', '3'],
    ]);
    expect(detailRequests, isEmpty);
  });

  test('force refetches every song; cache off stores nothing', () async {
    final store = MemoryTrackStore();
    final tracks = PlaylistTracks(api, store: store);
    await tracks.watch('9').drain<void>();
    detailRequests.clear();
    final forced = await tracks.watch('9', force: true).toList();
    expect(ids(forced), [
      ['1', '2', '3'],
    ]);
    expect(detailRequests, [
      ['1', '2', '3'],
    ]);

    final other = MemoryTrackStore();
    await PlaylistTracks(api, store: other).watch('9', cache: false).drain<void>();
    await pumpEventQueue();
    expect(other.data, isEmpty);
  });

  test('a broken cache file is ignored', () async {
    final store = MemoryTrackStore()..data['pl_9'] = '{oops';
    final emitted = await PlaylistTracks(api, store: store).watch('9').toList();
    expect(ids(emitted), [
      ['1', '2', '3'],
    ]);
  });
}
