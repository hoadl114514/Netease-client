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

  // ---------------------------------------------------------------- 扫码 / 手机号登录
  //
  // 登录接口不带用户 Cookie。成功后网易云通过 Set-Cookie 下发 MUSIC_U 等字段，
  // 调用方拿到后交给 AccountController 验证并保存。

  /// 申请一个扫码登录用的 key。
  Future<String> qrKey() async {
    final data = await _api('https://music.163.com/api/login/qrcode/unikey', const {
      'type': '3',
    }, anonymous: true);
    final key = _str(data['unikey']);
    if (key == null) throw const ApiException('获取二维码失败');
    return key;
  }

  /// 二维码内容：用网易云音乐 App 扫这个地址。
  static String qrContent(String key) => 'https://music.163.com/login?codekey=$key';

  /// 查询扫码状态。800 过期、801 等待扫码、802 已扫码待确认、803 登录成功（带 Cookie）。
  Future<QrCheck> qrCheck(String key) async {
    final res = await _post(Uri.parse('https://music.163.com/api/login/qrcode/client/login'), {
      'key': key,
      'type': '3',
    }, anonymous: true);
    final data = _decodeJson(utf8.decode(res.bodyBytes));
    final code = _int(data['code']);
    final status = switch (code) {
      800 => QrStatus.expired,
      801 => QrStatus.waiting,
      802 => QrStatus.scanned,
      803 => QrStatus.confirmed,
      _ => throw ApiException(_str(data['message']) ?? '扫码状态查询失败', code: code),
    };
    return QrCheck(
      status: status,
      nickname: _str(data['nickname']),
      avatarUrl: _https(_str(data['avatarUrl'])),
      cookies: status == QrStatus.confirmed ? parseSetCookie(res.headers['set-cookie']) : const {},
    );
  }

  /// 给手机号发登录验证码。
  Future<void> sendCaptcha(String phone, {String countryCode = '86'}) => _api(
    'https://music.163.com/api/sms/captcha/sent',
    {'cellphone': phone, 'ctcode': countryCode},
    anonymous: true,
  );

  /// 手机号 + 验证码登录，返回网易云下发的 Cookie。
  Future<Map<String, String>> loginWithCaptcha(
    String phone,
    String captcha, {
    String countryCode = '86',
  }) async {
    final res = await _post(Uri.parse('https://music.163.com/api/w/login/cellphone'), {
      'type': '1',
      'https': 'true',
      'phone': phone,
      'countrycode': countryCode,
      'captcha': captcha,
      'remember': 'true',
    }, anonymous: true);
    _check(_decodeJson(utf8.decode(res.bodyBytes)));
    final cookies = parseSetCookie(res.headers['set-cookie']);
    if (!cookies.containsKey('MUSIC_U')) throw const ApiException('登录失败：没有拿到登录凭证');
    return cookies;
  }

  // ---------------------------------------------------------------- 搜索 / 详情

  /// 输入时的联想词（像搜索引擎的下拉补全）。
  Future<List<String>> searchKeywords(String keyword) async {
    final data = await _api('https://music.163.com/api/search/suggest/keyword', {'s': keyword});
    final r = data['result'];
    return [
      if (r is Map)
        for (final m in _list(r['allMatch']))
          if (m is Map) ?_str(m['keyword']),
    ];
  }

  /// 输入时的快速结果：几首歌、歌手、专辑、歌单。
  Future<SearchSuggestion> searchSuggest(String keyword) async {
    final data = await _api('https://music.163.com/api/search/suggest/web', {'s': keyword});
    final r = data['result'];
    if (r is! Map) return const SearchSuggestion();
    return SearchSuggestion(
      // 联想接口里的歌曲是旧格式（artists / album），没有封面。
      songs: [for (final s in _list(r['songs'])) ?parseSong(s)],
      artists: [for (final a in _list(r['artists'])) ?_parseArtist(a)],
      albums: [for (final a in _list(r['albums'])) ?_parseAlbum(a)],
      playlists: [for (final p in _list(r['playlists'])) ?_parsePlaylist(p)],
    );
  }

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

  /// 往自己的歌单里加歌。网易云对这个接口有风控，异常网络环境下会返回 -462。
  Future<void> addToPlaylist(String playlistId, List<String> songIds) =>
      _manipulateTracks('add', playlistId, songIds);

  /// 从自己的歌单里删歌。
  Future<void> removeFromPlaylist(String playlistId, List<String> songIds) =>
      _manipulateTracks('del', playlistId, songIds);

  Future<void> _manipulateTracks(String op, String playlistId, List<String> songIds) =>
      _api('https://music.163.com/api/playlist/manipulate/tracks', {
        'op': op,
        'pid': playlistId,
        'trackIds': jsonEncode([for (final id in songIds) int.parse(id)]),
        'imme': 'true',
      });

  /// 收藏 / 取消收藏别人的歌单。
  Future<void> setPlaylistSubscribed(String playlistId, bool subscribed) => _api(
    'https://music.163.com/api/playlist/${subscribed ? 'subscribe' : 'unsubscribe'}',
    {'id': playlistId},
  );

  // ---------------------------------------------------------------- 推荐 / 发现

  /// 每日推荐歌曲（需要登录）。
  Future<List<Song>> dailySongs() async {
    final data = await _api('https://music.163.com/api/v3/discovery/recommend/songs', const {});
    final d = data['data'];
    return [
      if (d is Map)
        for (final s in _list(d['dailySongs'])) ?parseSong(s),
    ];
  }

  /// 私人 FM 的下一批（一次约 3 首，需要登录）。
  Future<List<Song>> personalFm() async {
    final data = await _api('https://music.163.com/api/v1/radio/get', const {});
    return [for (final s in _list(data['data'])) ?parseSong(s)];
  }

  /// 私人 FM 里标记「不喜欢」。
  Future<void> fmTrash(String songId) => _api(
    'https://music.163.com/api/radio/trash/add?alg=RT&songId=$songId&time=25',
    {'songId': songId},
  );

  /// 推荐歌单。登录后是每日推荐歌单，未登录是通用推荐。
  Future<List<Playlist>> recommendPlaylists({int limit = 30}) async {
    if (hasLoginCookie) {
      final data = await _api(
        'https://music.163.com/api/v1/discovery/recommend/resource',
        const {},
      );
      final list = [for (final p in _list(data['recommend'])) ?_parseRecommend(p)];
      if (list.isNotEmpty) return list.take(limit).toList();
    }
    final data = await _api('https://music.163.com/api/personalized/playlist', {
      'limit': '$limit',
      'total': 'true',
      'n': '1000',
    });
    return [for (final p in _list(data['result'])) ?_parseRecommend(p)];
  }

  /// 官方排行榜。[Playlist.description] 是更新频率。
  Future<List<Playlist>> toplists() async {
    final data = await _api('https://music.163.com/api/toplist', const {});
    return [for (final p in _list(data['list'])) ?_parsePlaylist(p)];
  }

  /// 热搜词。
  Future<List<String>> hotSearches() async {
    final data = await _api('https://music.163.com/api/hotsearchlist/get', const {});
    return [
      for (final h in _list(data['data']))
        if (h is Map) ?_str(h['searchWord']),
    ];
  }

  // ---------------------------------------------------------------- 听歌记录

  /// 听歌排行：[weekly] 为 true 是最近一周，否则是所有时间。
  Future<List<({Song song, int playCount})>> playRecord(int userId, {bool weekly = true}) async {
    final data = await _api('https://music.163.com/api/v1/play/record', {
      'uid': '$userId',
      'type': weekly ? '1' : '0',
    });
    return [
      for (final r in _list(data[weekly ? 'weekData' : 'allData']))
        if (r is Map)
          if (parseSong(r['song']) case final song?) (song: song, playCount: _int(r['playCount'])),
    ];
  }

  /// 最近播放的歌曲（需要登录）。
  Future<List<Song>> recentSongs({int limit = 300}) async {
    final data = await _api('https://music.163.com/api/play-record/song/list', {'limit': '$limit'});
    final d = data['data'];
    return [
      if (d is Map)
        for (final r in _list(d['list']))
          if (r is Map) ?parseSong(r['data']),
    ];
  }

  // ---------------------------------------------------------------- 歌手 / 专辑

  /// 歌手信息和热门歌曲（最多 50 首）。
  Future<({Artist artist, List<Song> hotSongs})> artistDetail(String id) async {
    final data = await _api('https://music.163.com/api/v1/artist/$id', const {});
    final a = data['artist'];
    if (a is! Map) throw const ApiException('歌手不存在');
    return (
      artist: _parseArtist(a)!,
      hotSongs: [for (final s in _list(data['hotSongs'])) ?parseSong(s)],
    );
  }

  /// 歌手的专辑，按发行时间从新到旧。
  Future<({List<Album> albums, bool more})> artistAlbums(
    String id, {
    int limit = 30,
    int offset = 0,
  }) async {
    final data = await _api('https://music.163.com/api/artist/albums/$id', {
      'limit': '$limit',
      'offset': '$offset',
      'total': 'true',
    });
    return (
      albums: [for (final a in _list(data['hotAlbums'])) ?_parseAlbum(a)],
      more: data['more'] == true,
    );
  }

  /// 专辑信息和曲目。
  Future<({Album album, List<Song> songs})> album(String id) async {
    final data = await _api('https://music.163.com/api/v1/album/$id', const {});
    final album = _parseAlbum(data['album']);
    if (album == null) throw const ApiException('专辑不存在');
    // 专辑接口里的歌曲没有带封面，统一补上专辑封面。
    final songs = [
      for (final s in _list(data['songs']))
        if (parseSong(s) case final song?) song.coverUrl == null ? _withCover(song, album) : song,
    ];
    return (album: album, songs: songs);
  }

  static Song _withCover(Song s, Album a) => Song(
    id: s.id,
    title: s.title,
    artist: s.artist,
    album: s.album.isEmpty ? a.name : s.album,
    duration: s.duration,
    coverUrl: a.coverUrl,
    subtitle: s.subtitle,
    artists: s.artists,
    albumId: s.albumId ?? a.id,
  );

  // ---------------------------------------------------------------- 搜索其他类型

  Future<({List<Playlist> items, int total})> searchPlaylists(
    String keyword, {
    int limit = 30,
    int offset = 0,
  }) async {
    final r = await _cloudSearch(keyword, 1000, limit, offset);
    return (
      items: [for (final p in _list(r['playlists'])) ?_parsePlaylist(p)],
      total: _int(r['playlistCount']),
    );
  }

  Future<({List<Artist> items, int total})> searchArtists(
    String keyword, {
    int limit = 30,
    int offset = 0,
  }) async {
    final r = await _cloudSearch(keyword, 100, limit, offset);
    return (
      items: [for (final a in _list(r['artists'])) ?_parseArtist(a)],
      total: _int(r['artistCount']),
    );
  }

  Future<({List<Album> items, int total})> searchAlbums(
    String keyword, {
    int limit = 30,
    int offset = 0,
  }) async {
    final r = await _cloudSearch(keyword, 10, limit, offset);
    return (
      items: [for (final a in _list(r['albums'])) ?_parseAlbum(a)],
      total: _int(r['albumCount']),
    );
  }

  Future<Map<Object?, Object?>> _cloudSearch(
    String keyword,
    int type,
    int limit,
    int offset,
  ) async {
    final data = await _api('https://music.163.com/api/cloudsearch/pc', {
      's': keyword,
      'type': '$type',
      'limit': '$limit',
      'offset': '$offset',
    });
    final r = data['result'];
    return r is Map ? r : const {};
  }

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
      artists: [
        for (final a in artists)
          if (a is Map && _str(a['name']) != null && _int(a['id']) > 0)
            ArtistRef('${a['id']}', '${a['name']}'),
      ],
      albumId: album is Map && _int(album['id']) > 0 ? '${album['id']}' : null,
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
      creatorId: creator is Map ? _int(creator['userId']) : null,
      description: _str(raw['updateFrequency']),
      subscribed: raw['subscribed'] == true,
      isLikedList: _int(raw['specialType']) == 5,
    );
  }

  /// 推荐歌单接口的字段名和歌单详情不一样（picUrl / playcount）。
  static Playlist? _parseRecommend(Object? raw) {
    if (raw is! Map || raw['id'] == null) return null;
    final creator = raw['creator'];
    return Playlist(
      id: '${raw['id']}',
      name: '${raw['name'] ?? ''}',
      playCount: _int(raw['playcount'] ?? raw['playCount']),
      trackCount: _int(raw['trackCount']),
      coverUrl: _https(_str(raw['picUrl'])),
      creator: creator is Map ? _str(creator['nickname']) : null,
      creatorId: creator is Map ? _int(creator['userId']) : null,
    );
  }

  static Artist? _parseArtist(Object? raw) {
    if (raw is! Map || raw['id'] == null) return null;
    return Artist(
      id: '${raw['id']}',
      name: '${raw['name'] ?? ''}',
      avatarUrl: _https(_str(raw['img1v1Url']) ?? _str(raw['picUrl'])),
      description: _str(raw['briefDesc']),
      songCount: _int(raw['musicSize']),
      albumCount: _int(raw['albumSize']),
    );
  }

  static Album? _parseAlbum(Object? raw) {
    if (raw is! Map || raw['id'] == null) return null;
    final artists = _list(raw['artists']);
    final main = raw['artist'];
    final names = [
      for (final a in artists)
        if (a is Map) ?_str(a['name']),
    ];
    final publish = _int(raw['publishTime']);
    return Album(
      id: '${raw['id']}',
      name: '${raw['name'] ?? ''}',
      artist: names.isNotEmpty
          ? names.join(' / ')
          : main is Map
          ? '${main['name'] ?? ''}'
          : '',
      coverUrl: _https(_str(raw['picUrl'])),
      publishTime: publish > 0 ? DateTime.fromMillisecondsSinceEpoch(publish) : null,
      size: _int(raw['size']),
      description: _str(raw['description']) ?? _str(raw['briefDesc']),
    );
  }

  // ---------------------------------------------------------------- 传输

  Map<String, String> _headers({bool anonymous = false}) => {
    'User-Agent': _userAgent,
    'Referer': 'https://music.163.com/',
    'Cookie': encodeCookie({..._deviceCookies, if (!anonymous) ..._cookies}),
  };

  Future<Map<String, Object?>> _api(
    String url,
    Map<String, String> form, {
    bool anonymous = false,
  }) async {
    final res = await _post(Uri.parse(url), form, anonymous: anonymous);
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

  Future<http.Response> _post(Uri url, Map<String, String> form, {bool anonymous = false}) async {
    final http.Response res;
    try {
      res = await _client
          .post(
            url,
            headers: _headers(anonymous: anonymous),
            body: form,
          )
          .timeout(_timeout);
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

enum QrStatus { expired, waiting, scanned, confirmed }

class QrCheck {
  const QrCheck({required this.status, this.nickname, this.avatarUrl, this.cookies = const {}});

  final QrStatus status;

  /// 已扫码（802）时返回扫码账号的昵称和头像。
  final String? nickname;
  final String? avatarUrl;

  /// 登录成功（803）时网易云下发的 Cookie。
  final Map<String, String> cookies;
}

class SearchSuggestion {
  const SearchSuggestion({
    this.songs = const [],
    this.artists = const [],
    this.albums = const [],
    this.playlists = const [],
  });

  final List<Song> songs;
  final List<Artist> artists;
  final List<Album> albums;
  final List<Playlist> playlists;

  bool get isEmpty => songs.isEmpty && artists.isEmpty && albums.isEmpty && playlists.isEmpty;
}
