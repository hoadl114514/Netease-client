import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:netease_client/data/models.dart';
import 'package:netease_client/lyrics/qq_lyrics.dart';

// 上游 C# DESHelper 独立编译后加密的 `[1000,2000]你(1000,400)好(1400,600)`。
const _encrypted =
    'bc8d35f203db1e28f887ef48290ac2b8de6aa9f06944e7140c89d5dfd2b08b838'
    '79d9519fd5d6870fb03375cce457b8bcb80dd584150d828bef246048cbbf326591'
    '500c679855739861a99ec3b2e9403ff8c0da56dc5009909f405efce9f96f1df71dcb7f4f885af';
const _qrc = '[1000,2000]你(1000,400)好(1400,600)';

const _source = Song(
  id: '1',
  title: '稻香',
  artist: '周杰伦',
  album: '魔杰座',
  duration: Duration(milliseconds: 223000),
);

QqSong candidate({
  int id = 1,
  String name = '稻香',
  List<String> artists = const ['周杰伦'],
  String album = '魔杰座',
  int durationMs = 223000,
  String subtitle = '',
}) => QqSong(
  id: id,
  name: name,
  artists: artists,
  album: album,
  durationMs: durationMs,
  subtitle: subtitle,
);

void main() {
  group('matching', () {
    test('exact match scores high', () {
      expect(scoreMatch(_source, candidate())!.score, greaterThan(99));
    });

    test('case, width and punctuation are ignored', () {
      const s = Song(
        id: '1',
        title: 'Ｈｅｌｌｏ， World!',
        artist: 'A / B',
        album: '',
        duration: Duration(seconds: 200),
      );
      expect(
        scoreMatch(s, candidate(name: 'hello world', artists: ['A', 'B'], durationMs: 200000)),
        isNotNull,
      );
    });

    test('different version, wrong lead artist or far duration is rejected', () {
      expect(scoreMatch(_source, candidate(name: '稻香 (Live)')), isNull);
      expect(scoreMatch(_source, candidate(name: '稻香 (伴奏)')), isNull);
      expect(scoreMatch(_source, candidate(artists: ['别人', '周杰伦'])), isNull);
      expect(scoreMatch(_source, candidate(durationMs: 240000)), isNull);
      expect(scoreMatch(_source, candidate(name: '稻花')), isNull); // 短标题必须完全一致。
    });

    test('soundtrack annotations do not count as a version', () {
      expect(scoreMatch(_source, candidate(name: '稻香 (电影《某某》主题曲)')), isNotNull);
    });

    test('ambiguous different recordings are rejected', () {
      const s = Song(
        id: '1',
        title: 'This Is A Long Song Title',
        artist: 'Singer',
        album: 'Album',
        duration: Duration(seconds: 120),
      );
      final matches = selectMatches(s, [
        candidate(id: 1, name: s.title, artists: ['Singer'], album: 'Album', durationMs: 120000),
        candidate(
          id: 2,
          name: '${s.title}s',
          artists: ['Singer'],
          album: 'Album',
          durationMs: 120000,
        ),
      ]);
      expect(matches, isEmpty);
    });

    test('a featured artist listed on only one side still matches', () {
      expect(
        selectMatches(_source, [
          candidate(artists: ['周杰伦', '其他人']),
        ]).map((m) => m.song.id),
        [1],
      );
      const duet = Song(
        id: '1',
        title: '稻香',
        artist: '周杰伦 / 其他人',
        album: '',
        duration: Duration(milliseconds: 223000),
      );
      expect(selectMatches(duet, [candidate()]).map((m) => m.song.id), [1]);
    });

    test('bracketed artist aliases match either name', () {
      const s = Song(
        id: '1',
        title: 'Blueming',
        artist: 'IU',
        album: 'Love poem',
        duration: Duration(milliseconds: 217000),
      );
      final c = candidate(
        name: 'Blueming',
        artists: ['IU (아이유)'],
        album: 'Love poem',
        durationMs: 217000,
      );
      expect(scoreMatch(s, c)!.score, greaterThan(99));
      const korean = Song(
        id: '1',
        title: 'Blueming',
        artist: '아이유',
        album: '',
        duration: Duration(milliseconds: 217000),
      );
      expect(selectMatches(korean, [c]), isNotEmpty);
    });

    test('feat. in the title and remaster tags are ignored', () {
      const s = Song(
        id: '1',
        title: 'Stay (feat. Justin Bieber)',
        artist: 'The Kid LAROI / Justin Bieber',
        album: '',
        duration: Duration(milliseconds: 141000),
      );
      expect(
        selectMatches(s, [
          candidate(name: 'Stay', artists: ['The Kid LAROI', 'Justin Bieber'], durationMs: 141000),
        ]),
        isNotEmpty,
      );
      const r = Song(
        id: '1',
        title: 'Hotel California',
        artist: 'Eagles',
        album: '',
        duration: Duration(milliseconds: 391000),
      );
      expect(
        scoreMatch(
          r,
          candidate(
            name: 'Hotel California (2013 Remaster)',
            artists: ['Eagles'],
            durationMs: 391000,
          ),
        ),
        isNotNull,
      );
    });

    test('the Netease alias can match a translated QQ title', () {
      const s = Song(
        id: '1',
        title: '打上花火',
        artist: 'DAOKO / 米津玄師',
        album: '',
        duration: Duration(milliseconds: 289000),
        subtitle: 'Uchiage Hanabi',
      );
      expect(
        scoreMatch(
          s,
          candidate(name: 'Uchiage Hanabi', artists: ['DAOKO', '米津玄師'], durationMs: 289000),
        ),
        isNotNull,
      );
    });

    test('single and album releases a few seconds apart pick the closer one', () {
      final cs = [
        candidate(id: 1, album: '单曲', durationMs: 227000),
        candidate(id: 2, album: '另一张专辑', durationMs: 223000),
      ];
      expect(selectMatches(_source, cs).first.song.id, 2);
    });

    test('search title drops feat. and soundtrack notes', () {
      expect(searchTitle('Stay (feat. Justin Bieber)'), 'Stay');
      expect(searchTitle('稻香 (电影《某某》主题曲)'), '稻香');
      expect(searchTitle('晴天 (Live)'), '晴天 (Live)');
    });

    test('equivalent releases are all returned, tried ids excluded', () {
      final cs = [candidate(id: 1), candidate(id: 2, album: '精选集', durationMs: 223800)];
      expect(selectMatches(_source, cs).map((m) => m.song.id), [1, 2]);
      expect(selectMatches(_source, cs, exclude: {1}).map((m) => m.song.id), [2]);
    });
  });

  group('download response', () {
    test('decrypts content inside comments; broken translation does not lose original', () {
      final r = decodeDownloadResponse(
        '<?xml version="1.0"?><!--<lyric><content><![CDATA[$_encrypted]]></content>'
        '<contentts>bad ciphertext</contentts></lyric>-->',
      );
      expect(r.original, _qrc);
      expect(r.translation, 'bad ciphertext'); // 不是十六进制：当成明文原样返回。
      final r2 = decodeDownloadResponse(
        '<root><content>$_encrypted</content><contentts>0011</contentts></root>',
      );
      expect(r2.translation, '');
    });

    test('a non-zero result code is a rejection', () {
      expect(
        () => decodeDownloadResponse('<root><result code="-1"/></root>'),
        throwsFormatException,
      );
    });

    test('LyricContent with raw quotes, < and & is unwrapped', () {
      const xml =
          '<?xml version="1.0"?><QrcInfos><Lyric_1 LyricType="1" '
          'LyricContent="[1000,1000]Say "A & B < C"(1000,1000)\n[3000,1000]N&amp;T(3000,1000)"/></QrcInfos>';
      expect(
        unwrapLyricContent(xml),
        '[1000,1000]Say "A & B < C"(1000,1000)\n[3000,1000]N&T(3000,1000)',
      );
      expect(unwrapLyricContent('[00:01.00]plain'), '[00:01.00]plain');
    });
  });

  test('fetch searches, matches and returns word-synced lyrics', () async {
    final queries = <String>[];
    final client = MockClient((req) async {
      if (req.url.host == 'u.y.qq.com') {
        queries.add((jsonDecode(req.body) as Map)['req_1']['param']['query'] as String);
        return http.Response(
          jsonEncode({
            'code': 0,
            'req_1': {
              'code': 0,
              'data': {
                'body': {
                  'song': {
                    'list': [
                      {
                        'id': 7,
                        'title': '稻香',
                        'name': '稻香',
                        'singer': [
                          {'name': '周杰伦'},
                        ],
                        'album': {'title': '魔杰座'},
                        'interval': 223,
                      },
                    ],
                  },
                },
              },
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      expect(req.bodyFields['musicid'], '7');
      return http.Response('<root><content>$_encrypted</content></root>', 200);
    });
    final lyrics = await QqLyrics(client: client).fetch(_source);
    expect(queries.first, '稻香 周杰伦');
    expect(lyrics.source, LyricSource.qq);
    expect(lyrics.wordSynced, isTrue);
    expect(lyrics.lines.single.text, '你好');
  });
}
