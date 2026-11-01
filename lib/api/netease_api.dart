import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../data/models.dart';
import 'cookies.dart';
import 'eapi_crypto.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.code});

  final String message;

  /// 接口返回的 `code`；网络层错误时为 HTTP 状态码或 null。
  final int? code;

  /// 301 / 302：未登录或登录已失效。
  bool get needsLogin => code == 301 || code == 302;

  @override
  String toString() => code == null ? message : '$message（code=$code）';
}

/// 网易云接口。
///
/// 大部分接口走明文 `/api/`（表单 POST + Cookie），播放地址、歌词和收藏走 EAPI 加密。
/// 只依赖 Cookie 里的 `MUSIC_U` 识别账号；没有 Cookie 时仍可搜索、播放免费歌曲。
class NeteaseApi {
  NeteaseApi({http.Client? client, Map<String, String> cookies = const {}, Random? random})
    : _client = client ?? http.Client(),
      _cookies = Map.of(cookies),
      _random = random ?? Random();

  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/122.0 Safari/537.36 NeteaseMusicDesktop/3.0';
  static const _timeout = Duration(seconds: 15);

  /// 和 PC 客户端一致的默认设备字段，用户 Cookie 里的同名字段优先。
  static const _deviceCookies = {'os': 'pc', 'appver': '', 'osver': '', 'deviceId': 'pyncm!'};

  final http.Client _client;
  final Random _random;
  Map<String, String> _cookies;

  Map<String, String> get cookies => Map.unmodifiable(_cookies);
  set cookies(Map<String, String> value) => _cookies = Map.of(value);

  bool get hasLoginCookie => (_cookies['MUSIC_U'] ?? '').isNotEmpty;

  void close() => _client.close();

  // ---------------------------------------------------------------- 账号

  /// 当前 Cookie 对应的账号；未登录或 Cookie 失效时返回 null。
  Future<UserProfile?> account() async {
    final data = await _api('https://music.163.com/api/nuser/account/get', const {});
    final profile = data['profile'];
    if (profile is! Map) return null;
    return UserProfile(
      userId: _int(profile['userId']),
      nickname: '${profile['nickname'] ?? ''}',
      avatarUrl: _str(profile['avatarUrl']),
      vipType: _int(profile['vipType']),
    );
  }

  // ---------------------------------------------------------------- 搜索 / 详情

  Future<({List<Song> songs, int total})> searchSongs(
    String keyword, {
    int limit = 30,
    int offset = 0,
  }) async {
    final data = await _api('https://music.163.com/api/cloudsearch/pc', {
      's': keyword,
      'type': '1',
      'limit': '$limit',
      'offset': '$offset',
    });
    final result = data['result'];
    if (result is! Map) return (songs: const <Song>[], total: 0);
    final songs = [for (final s in _list(result['songs'])) ?parseSong(s)];
    return (songs: songs, total: _int(result['songCount']));
  }

  /// 批量取歌曲详情，按 [ids] 的顺序返回；查不到的会被跳过。
  Future<List<Song>> songDetails(List<String> ids) async {
    final byId = <String, Song>{};
    for (var i = 0; i < ids.length; i += 500) {
      final chunk = ids.sublist(i, min(i + 500, ids.length));
      final data = await _api('https://music.163.com/api/v3/song/detail', {
        'c': jsonEncode([
          for (final id in chunk) {'id': int.parse(id), 'v': 0},
        ]),
      });
      for (final s in _list(data['songs'])) {
        if (parseSong(s) case final song?) byId[song.id] = song;
      }
    }
    return [for (final id in ids) ?byId[id]];
  }

  /// 这首歌实际提供的音质档位（与账号权益无关），从低到高。
  Future<List<QualityInfo>> qualities(String songId) async {
    final data = await _api('https://interface.music.163.com/api/song/music/detail/get', {
      'songId': songId,
    });
    final detail = data['data'];
    if (detail is! Map) return const [];
    return [
      for (final q in AudioQuality.values)
        if (detail[q.detailKey] case final Map<Object?, Object?> m)
          QualityInfo(
            quality: q,
            bitrate: _int(m['br']),
            size: _int(m['size']),
            sampleRate: m['sr'] == null ? null : _int(m['sr']),
          ),
    ];
  }

  /// 取播放地址。没有版权、需要购买或会员时返回 null。
  Future<SongUrl?> songUrl(String songId, AudioQuality quality) async {
    final payload = <String, Object?>{
      'ids': [int.parse(songId)],
      'level': quality.level,
      'encodeType': quality == AudioQuality.dolby ? 'mp4' : 'flac',
      if (quality == AudioQuality.sky) 'immerseType': 'c51',
    };
    final data = await _eapi('/api/song/enhance/player/url/v1', payload);
    final entries = _list(data['data']);
    if (entries.isEmpty) return null;
    final entry = entries.first as Map;
    final url = _str(entry['url']);
    if (url == null) return null;
    final trial = entry['freeTrialInfo'];
    return SongUrl(
      url: url,
      quality: AudioQuality.fromLevel(_str(entry['level'])),
      trial: trial is Map
          ? (
              start: Duration(milliseconds: _int(trial['start'])),
              end: Duration(milliseconds: _int(trial['end'])),
            )
          : null,
    );
  }

  /// 原始歌词文本：`lrc` 逐行原文、`yrc` 逐字原文、`tlyric` 翻译、`romalrc` 罗马音、
  /// `ytlrc` / `yromalrc` 与逐字歌词对齐的翻译 / 罗马音。缺的字段为空串。
  Future<Map<String, String>> lyricTexts(String songId) async {
    final data = await _eapi(
      '/api/song/lyric/v1',
      {
        'id': int.parse(songId),
        'cp': false,
        'lv': -1,
        'tv': -1,
        'rv': -1,
        'yv': -1,
        'ytv': -1,
        'yrv': -1,
      },
      host: 'https://interface.music.163.com',
      encryptedResponse: true,
    );
    String text(String key) => switch (data[key]) {
      final Map<Object?, Object?> m => '${m['lyric'] ?? ''}'.replaceAll('\u0000', '').trim(),
      _ => '',
    };
    return {
      for (final k in const ['lrc', 'yrc', 'tlyric', 'romalrc', 'ytlrc', 'yromalrc']) k: text(k),
    };
  }

  // ---------------------------------------------------------------- 歌单 / 喜欢

  Future<List<Playlist>> userPlaylists(int userId) async {
    final data = await _api('https://music.163.com/api/user/playlist', {
      'uid': '$userId',
      'limit': '1000',
      'offset': '0',
      'includeVideo': 'true',
    });
    return [for (final p in _list(data['playlist'])) ?_parsePlaylist(p)];
  }

  /// 歌单信息和全部歌曲。
  Future<({Playlist playlist, List<Song> tracks})> playlistDetail(String id) async {
    final data = await _api('https://music.163.com/api/v6/playlist/detail', {'id': id, 'n': '0'});
    final raw = data['playlist'];
    final playlist = raw is Map ? _parsePlaylist(raw) : null;
    if (playlist == null) throw const ApiException('歌单不存在或无权查看');
    final ids = [
      for (final t in _list((raw as Map)['trackIds']))
        if (t is Map && t['id'] != null) '${t['id']}',
    ];
    return (playlist: playlist, tracks: await songDetails(ids));
  }

  Future<Set<String>> likedSongIds(int userId) async {
    final data = await _api('https://music.163.com/api/song/like/get', {'uid': '$userId'});
    return {for (final id in _list(data['ids'])) '$id'};
  }

  Future<void> setLiked(String songId, bool liked) => _eapi('/api/radio/like', {
    'alg': 'itembased',
    'trackId': int.parse(songId),
    'like': liked,
    'time': '3',
  });

  // ---------------------------------------------------------------- 解析

  static Song? parseSong(Object? raw) {
    if (raw is! Map || raw['id'] == null) return null;
    final artists = _list(raw['ar'] ?? raw['artists']);
    final album = raw['al'] ?? raw['album'];
    final alias = [
      ..._list(raw['tns']),
      ..._list(raw['alia']),
    ].map((e) => '$e').where((e) => e.isNotEmpty);
    return Song(
      id: '${raw['id']}',
      title: '${raw['name'] ?? ''}',
      artist: [
        for (final a in artists)
          if (a is Map && _str(a['name']) != null) a['name'],
      ].join(' / '),
      album: album is Map ? '${album['name'] ?? ''}' : '',
      duration: Duration(milliseconds: _int(raw['dt'] ?? raw['duration'])),
      coverUrl: album is Map ? _https(_str(album['picUrl'])) : null,
      subtitle: alias.isEmpty ? null : alias.first,
    );
  }

  static Playlist? _parsePlaylist(Object? raw) {
    if (raw is! Map || raw['id'] == null) return null;
    final creator = raw['creator'];
    return Playlist(
      id: '${raw['id']}',
      name: '${raw['name'] ?? ''}',
      playCount: _int(raw['playCount']),
      trackCount: _int(raw['trackCount']),
      coverUrl: _https(_str(raw['coverImgUrl'])),
      creator: creator is Map ? _str(creator['nickname']) : null,
      isLikedList: _int(raw['specialType']) == 5,
    );
  }

  // ---------------------------------------------------------------- 传输

  Map<String, String> _headers() => {
    'User-Agent': _userAgent,
    'Referer': 'https://music.163.com/',
    'Cookie': encodeCookie({..._deviceCookies, ..._cookies}),
  };

  Future<Map<String, Object?>> _api(String url, Map<String, String> form) async {
    final res = await _post(Uri.parse(url), form);
    return _check(_decodeJson(utf8.decode(res.bodyBytes)));
  }

  Future<Map<String, Object?>> _eapi(
    String apiPath,
    Map<String, Object?> params, {
    String host = 'https://interface3.music.163.com',
    bool encryptedResponse = false,
  }) async {
    final header = {
      ..._deviceCookies,
      'deviceId': _cookies['deviceId'] ?? _deviceCookies['deviceId']!,
      'requestId': '${20000000 + _random.nextInt(10000000)}',
    };
    final payload = jsonEncode({
      ...params,
      if (encryptedResponse) 'e_r': true,
      'header': jsonEncode(header),
    });
    final url = Uri.parse('$host${apiPath.replaceFirst('/api/', '/eapi/')}');
    final res = await _post(url, {'params': EapiCrypto.encrypt(apiPath, payload)});
    final String body;
    try {
      body = encryptedResponse ? EapiCrypto.decrypt(res.bodyBytes) : utf8.decode(res.bodyBytes);
    } catch (_) {
      throw const ApiException('接口返回无法解密');
    }
    return _check(_decodeJson(body));
  }

  Future<http.Response> _post(Uri url, Map<String, String> form) async {
    final http.Response res;
    try {
      res = await _client.post(url, headers: _headers(), body: form).timeout(_timeout);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('网络请求失败：$e');
    }
    if (res.statusCode != 200) throw ApiException('HTTP ${res.statusCode}', code: res.statusCode);
    return res;
  }

  static Map<String, Object?> _decodeJson(String body) {
    try {
      final v = jsonDecode(body);
      if (v is Map<String, Object?>) return v;
    } on FormatException {
      // 落到下面统一报错。
    }
    throw const ApiException('接口返回格式错误');
  }

  static Map<String, Object?> _check(Map<String, Object?> data) {
    final code = data['code'];
    if (code is int && code != 200) {
      final msg = _str(data['message']) ?? _str(data['msg']) ?? '接口返回错误';
      throw ApiException(msg, code: code);
    }
    return data;
  }

  static List<Object?> _list(Object? v) => v is List ? v : const [];
  static int _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
  static String? _str(Object? v) => v is String && v.isNotEmpty ? v : null;

  /// 网易云图片地址有时是 http，统一换成 https。
  static String? _https(String? url) => url?.replaceFirst(RegExp('^http:'), 'https:');
}

/// 网易云图片按尺寸裁剪：`?param=200y200`。
String sizedImage(String url, int px) => '$url${url.contains('?') ? '&' : '?'}param=${px}y$px';
