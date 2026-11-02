import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:netease_client/api/cookies.dart';
import 'package:netease_client/api/netease_api.dart';
import 'package:netease_client/api/xeapi_crypto.dart';
import 'package:netease_client/data/models.dart';
import 'package:pointycastle/export.dart';

http.Response json(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

final _xeapiStaticKey = Uint8List.fromList([
  for (var i = 0; i < 64; i += 2)
    int.parse(
      'ab1d5a430f6bb04a3f01e81ddd72bd916d5ce591248ac128714806d7f8fb1b84'.substring(i, i + 2),
      radix: 16,
    ),
]);

Uint8List _aes(List<int> key, List<int> data) =>
    (PaddedBlockCipherImpl(PKCS7Padding(), ECBBlockCipher(AESEngine()))
          ..init(true, PaddedBlockCipherParameters(KeyParameter(Uint8List.fromList(key)), null)))
        .process(Uint8List.fromList(data));

void main() {
  test('parseCookie handles separators, blanks and "=" in values', () {
    expect(parseCookie(' MUSIC_U=ab=c ; __csrf=x\nbad; empty= ;=v'), {
      'MUSIC_U': 'ab=c',
      '__csrf': 'x',
    });
    expect(encodeCookie({'a': '1', 'b': '2'}), 'a=1; b=2');
  });

  test('requests carry device defaults plus the user cookie', () async {
    late http.Request seen;
    final api = NeteaseApi(
      client: MockClient((r) async {
        seen = r;
        return json({'code': 200, 'profile': null});
      }),
      cookies: {'MUSIC_U': 'secret', 'os': 'android'},
    );
    expect(await api.account(), isNull);
    final cookie = seen.headers['Cookie']!;
    expect(cookie, contains('MUSIC_U=secret'));
    expect(cookie, contains('os=android')); // 用户的同名字段优先。
    expect(cookie, contains('deviceId=pyncm!'));
  });

  test('searchSongs parses artists, album cover and alias', () async {
    final api = NeteaseApi(
      client: MockClient(
        (r) async => json({
          'code': 200,
          'result': {
            'songCount': 99,
            'songs': [
              {
                'id': 5,
                'name': '歌',
                'ar': [
                  {'name': 'A'},
                  {'name': 'B'},
                ],
                'al': {'name': '专辑', 'picUrl': 'http://p1.music.126.net/x.jpg'},
                'dt': 1234,
                'tns': ['Song'],
              },
            ],
          },
        }),
      ),
    );
    final r = await api.searchSongs('歌');
    expect(r.total, 99);
    final s = r.songs.single;
    expect((s.id, s.title, s.artist, s.album, s.subtitle), ('5', '歌', 'A / B', '专辑', 'Song'));
    expect(s.duration, const Duration(milliseconds: 1234));
    expect(s.coverUrl, 'https://p1.music.126.net/x.jpg');
  });

  test('qualities lists only the levels the track has, low to high', () async {
    final api = NeteaseApi(
      client: MockClient(
        (r) async => json({
          'code': 200,
          'data': {
            'l': {'br': 128000, 'size': 1, 'sr': 44100},
            'h': {'br': 320000, 'size': 2, 'sr': 44100},
            'sq': {'br': 900000, 'size': 3, 'sr': 48000},
            'hr': null,
            'db': null,
            'jm': {'br': 5000000, 'size': 4, 'sr': 192000},
            'vi': {'br': 1, 'size': 1},
          },
        }),
      ),
    );
    final qs = await api.qualities('1');
    expect(qs.map((q) => q.quality), [
      AudioQuality.standard,
      AudioQuality.exhigh,
      AudioQuality.lossless,
      AudioQuality.jymaster,
    ]);
    expect(qs[2].sampleRate, 48000);
  });

  test('songUrl goes through XEAPI with a registered public key', () async {
    final server = Uint8List.fromList(List.generate(32, (i) => i * 7 + 3));
    final requests = <http.Request>[];
    final api = NeteaseApi(
      cookies: {'MUSIC_U': 'u'},
      client: MockClient((r) async {
        requests.add(r);
        if (r.url.path == '/api/bsr/sk/get') {
          final f = r.bodyFields;
          expect(f['signature'], XeapiCrypto.sign(f['timestamp']!, f['nonce']!));
          final key = jsonEncode({
            'publicKey': base64.encode(X25519.publicKey(server)),
            'version': '3',
            'sk': 'sk1',
          });
          return json({
            'code': 200,
            'data': {
              'encryptedData': base64.encode(_aes(_xeapiStaticKey, utf8.encode(key))),
              'timestamp': 42,
              'signature': XeapiCrypto.sign('42', f['nonce']!),
            },
          });
        }
        expect(
          r.url.toString(),
          'https://interface3.music.163.com/xeapi/song/enhance/player/url/v1',
        );
        expect(r.headers['x-music-u'], 'u');
        expect(r.bodyFields.keys, ['C', 'S', 'R']);
        final body = jsonEncode({
          'code': 200,
          'data': [
            {'url': 'http://m801.music.126.net/x.flac', 'level': 'hires'},
          ],
        });
        return http.Response.bytes(_aes(utf8.encode('e82ckenh8dichen8'), utf8.encode(body)), 200);
      }),
    );
    final u = await api.songUrl('1', AudioQuality.hires);
    expect(u!.quality, AudioQuality.hires);
    expect(u.url, 'http://m801.music.126.net/x.flac');
    // 公钥只取一次。
    await api.songUrl('2', AudioQuality.hires);
    expect(requests.where((r) => r.url.path == '/api/bsr/sk/get'), hasLength(1));
  });

  test('songUrl falls back to EAPI and reads level / trial; null url means unavailable', () async {
    final bodies = <Map<String, String>>[];
    var call = 0;
    final api = NeteaseApi(
      client: MockClient((r) async {
        // XEAPI 拿不到公钥时退回 EAPI。
        if (r.url.path == '/api/bsr/sk/get') return json({'code': 500});
        bodies.add(r.bodyFields);
        expect(r.url.path, '/eapi/song/enhance/player/url/v1');
        return call++ == 0
            ? json({
                'code': 200,
                'data': [
                  {
                    'url': 'http://m701.music.126.net/a.flac',
                    'level': 'exhigh',
                    'freeTrialInfo': {'start': 30000, 'end': 60000},
                  },
                ],
              })
            : json({
                'code': 200,
                'data': [
                  {'url': null, 'code': 404},
                ],
              });
      }),
    );
    final u = await api.songUrl('1', AudioQuality.lossless);
    expect(u!.quality, AudioQuality.exhigh);
    expect(u.trial, (start: const Duration(seconds: 30), end: const Duration(seconds: 60)));
    expect(bodies.first['params'], matches(RegExp(r'^[0-9A-F]+$')));
    expect(await api.songUrl('1', AudioQuality.standard), isNull);
  });

  test('non-200 codes become ApiException; 301 means login needed', () async {
    final api = NeteaseApi(client: MockClient((r) async => json({'code': 301, 'msg': '需要登录'})));
    await expectLater(
      api.userPlaylists(1),
      throwsA(
        isA<ApiException>()
            .having((e) => e.needsLogin, 'needsLogin', isTrue)
            .having((e) => e.message, 'message', '需要登录'),
      ),
    );
  });

  test('network and HTTP failures become ApiException', () async {
    final api = NeteaseApi(client: MockClient((r) async => http.Response('oops', 503)));
    await expectLater(api.searchSongs('x'), throwsA(isA<ApiException>()));
    final api2 = NeteaseApi(client: MockClient((r) async => throw http.ClientException('offline')));
    await expectLater(api2.searchSongs('x'), throwsA(isA<ApiException>()));
  });
}
