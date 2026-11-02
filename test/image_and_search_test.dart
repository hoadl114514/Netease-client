import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:netease_client/api/netease_api.dart';
import 'package:netease_client/app/app.dart';
import 'package:netease_client/data/models.dart';
import 'package:netease_client/pages/library/track_list_view.dart';
import 'package:netease_client/state/player_controller.dart';
import 'package:netease_client/widgets/image_viewer.dart';

import 'support/fakes.dart';

http.Response _json(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, Object> _song(int id, {int artistId = 7, String name = '歌'}) => {
  'id': id,
  'name': '$name$id',
  'ar': [
    {'id': artistId, 'name': '歌手$artistId'},
  ],
  'al': {'id': 9, 'name': '专辑', 'picUrl': 'http://p1.music.126.net/x/$id.jpg'},
  'dt': 1000,
};

Song _s(String id, String title, {String artist = '某人', String album = '', String? subtitle}) =>
    Song(
      id: id,
      title: title,
      artist: artist,
      album: album,
      duration: Duration.zero,
      subtitle: subtitle,
    );

void main() {
  group('images', () {
    test('imageUrlFromId matches NetEase encrypt_id', () {
      expect(
        imageUrlFromId(109951169694193626),
        'https://p1.music.126.net/0sSZmnxHnBzBejx9k9GxWA==/109951169694193626.jpg',
      );
      expect(imageUrlFromId(0), isNull);
      expect(imageUrlFromId(null), isNull);
    });

    test('originalImage strips the resize parameter', () {
      expect(originalImage('https://a/b.jpg?param=200y200'), 'https://a/b.jpg');
      expect(originalImage('https://a/b.jpg'), 'https://a/b.jpg');
    });

    test('imageFileStem drops illegal characters', () {
      expect(imageFileStem('a/b: c?'), 'a_b_c');
      expect(imageFileStem(null), 'netease');
      expect(imageFileStem('   '), 'netease');
    });

    testWidgets('long-pressing a viewable image opens the viewer', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ViewableImage(
              url: 'https://example.com/a.jpg?param=100y100',
              child: SizedBox.square(
                key: Key('img'),
                dimension: 80,
                child: ColoredBox(color: Colors.red),
              ),
            ),
          ),
        ),
      );
      await tester.longPress(find.byKey(const Key('img')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final viewer = tester.widget<ImageViewerPage>(find.byType(ImageViewerPage));
      expect(viewer.url, 'https://example.com/a.jpg?param=100y100');
      expect(find.byTooltip('保存图片'), findsOneWidget);
    });
  });

  group('api', () {
    test('artistAllSongs pages by 100, keeps order and drops strangers', () async {
      final offsets = <String>[];
      final api = NeteaseApi(
        client: MockClient((r) async {
          final f = r.bodyFields;
          expect(r.url.path, '/api/v1/artist/songs');
          expect(f['order'], 'time');
          expect(f['limit'], '100');
          offsets.add(f['offset']!);
          final o = int.parse(f['offset']!);
          final n = o == 200 ? 30 : 100;
          return _json({
            'code': 200,
            'total': 230,
            'more': o < 200,
            'songs': [for (var i = 0; i < n; i++) _song(o + i + 1, artistId: o + i == 5 ? 99 : 7)],
          });
        }),
      );
      final songs = await api.artistAllSongs('7');
      expect(offsets.toSet(), {'0', '100', '200'});
      expect(songs, hasLength(229));
      expect(songs.first.id, '1');
      expect(songs.last.id, '230');
      expect(songs.any((s) => s.id == '6'), isFalse);
    });

    test('searchSuggest fills song covers, album covers and artist avatars', () async {
      final api = NeteaseApi(
        client: MockClient((r) async {
          if (r.url.path.endsWith('/song/detail')) {
            return _json({
              'code': 200,
              'songs': [_song(1)],
            });
          }
          return _json({
            'code': 200,
            'result': {
              'songs': [
                {
                  'id': 1,
                  'name': '歌1',
                  'artists': [
                    {'id': 7, 'name': '歌手7'},
                  ],
                  'album': {'id': 9, 'name': '专辑'},
                },
              ],
              'albums': [
                {'id': 3, 'name': '专辑3', 'picId': 109951169694193626},
              ],
              'artists': [
                {
                  'id': 7,
                  'name': '歌手7',
                  'picUrl': 'http://p1.music.126.net/pic/1.jpg',
                  'img1v1Url':
                      'http://p1.music.126.net/6y-UleORITEDbvrOLV0Q8A==/5639395138885805.jpg',
                },
              ],
            },
          });
        }),
      );
      final r = await api.searchSuggest('歌');
      expect(r.songs.single.coverUrl, 'https://p1.music.126.net/x/1.jpg');
      expect(r.albums.single.coverUrl, contains('0sSZmnxHnBzBejx9k9GxWA=='));
      // 默认头像不用，换成 picUrl。
      expect(r.artists.single.avatarUrl, 'https://p1.music.126.net/pic/1.jpg');
    });
  });

  group('in-list search', () {
    test('songMatches checks every word against title, alias, artist and album', () {
      final s = _s('1', 'Hello World', artist: '周杰伦', album: '叶惠美', subtitle: '别名');
      expect(songMatches(s, 'hello'), isTrue);
      expect(songMatches(s, '周杰伦 world'), isTrue);
      expect(songMatches(s, '叶惠'), isTrue);
      expect(songMatches(s, '别名'), isTrue);
      expect(songMatches(s, 'hello 林俊杰'), isFalse);
    });

    testWidgets('filtering keeps original numbering and plays the full list', (tester) async {
      final f = await fakeServices();
      final songs = [_s('1', '晴天'), _s('2', '七里香'), _s('3', '晴天娃娃')];
      await tester.pumpWidget(
        AppScope(
          services: f.services,
          child: PlayerScope(
            controller: f.services.player,
            child: MaterialApp(
              home: Scaffold(
                body: TrackListView(
                  load: () async => songs,
                  queueTitle: '测试',
                  header: (_, _, _) => const SizedBox(height: 10),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('七里香'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '娃娃');
      await tester.pumpAndSettle();
      expect(find.text('七里香'), findsNothing);
      expect(find.text('晴天娃娃'), findsOneWidget);
      expect(find.text('3'), findsOneWidget); // 序号仍是原来的第 3 首。
      expect(find.text('1 首'), findsOneWidget);

      await tester.tap(find.text('晴天娃娃'));
      await tester.pumpAndSettle();
      expect(f.services.player.queue, hasLength(3));
      expect(f.services.player.current?.id, '3');

      await tester.enterText(find.byType(TextField), '不存在');
      await tester.pumpAndSettle();
      expect(find.text('没有匹配的歌曲'), findsOneWidget);

      // 播放会起进度计时器，暂停后才能结束测试。
      await f.services.player.pause();
    });
  });
}
