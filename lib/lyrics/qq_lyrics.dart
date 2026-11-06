// QQ 音乐歌词：搜索 → 保守匹配同一录音 → 下载并解密 QRC。
//
// 搜索、下载接口和 QRC 时间语义参考 Lyricify Lyrics Helper（Apache-2.0，Copyright 2023 XY Wang, WXRIW）；
// 版本识别与置信度判定移植自作者此前的 Python 插件。详见 THIRD_PARTY_NOTICES.md。

import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../data/models.dart';
import 'lyric_parser.dart';
import 'qrc_decrypter.dart';

class QqSong {
  const QqSong({
    required this.id,
    required this.name,
    required this.artists,
    required this.album,
    required this.durationMs,
    this.subtitle = '',
  });

  final int id;
  final String name;
  final List<String> artists;
  final String album;
  final int durationMs;
  final String subtitle;
}

class QqMatch {
  const QqMatch(this.song, this.score, this.durationDiffMs);

  final QqSong song;
  final double score;
  final int durationDiffMs;
}

/// 下载到的原始歌词文本。
typedef QqLyricTexts = ({String original, String translation, String romaji});

class QqLyrics {
  QqLyrics({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/63.0.3239.132 Safari/537.36',
    'Referer': 'https://c.y.qq.com/',
  };
  static const _timeout = Duration(seconds: 12);

  void close() => _client.close();

  /// 找到可信匹配并且有可用歌词时返回，否则返回 [Lyrics.empty]。优先逐字歌词。
  Future<Lyrics> fetch(Song song) async {
    final primaryArtist = _stripBrackets(song.artist.split(_artistSeparator).first).trim();
    // 去掉 feat.、影视注释等括注再搜一次：这些字常让 QQ 搜不到原曲。
    final plainTitle = searchTitle(song.title);
    final queries = {
      '${song.title} $primaryArtist'.trim(),
      if (plainTitle.isNotEmpty) '$plainTitle $primaryArtist'.trim(),
      song.title,
    }.toList();
    final candidates = <int, QqSong>{};
    final tried = <int>{};
    Lyrics fallback = Lyrics.empty;
    Object? searchError;
    for (final q in queries) {
      final List<QqSong> found;
      try {
        found = await search(q);
      } catch (e) {
        // 一个关键词搜索失败，继续试下一个。
        searchError = e;
        continue;
      }
      for (final c in found) {
        candidates[c.id] = c;
      }
      for (final m in selectMatches(song, candidates.values.toList(), exclude: tried)) {
        tried.add(m.song.id);
        final QqLyricTexts texts;
        try {
          texts = await download(m.song.id);
        } catch (_) {
          continue;
        }
        if (texts.original.isEmpty) continue;
        final lyrics = LyricParser.build(
          main: texts.original,
          translation: texts.translation,
          romaji: texts.romaji,
          source: LyricSource.qq,
          duration: song.duration,
        );
        if (lyrics.isEmpty) continue;
        if (lyrics.wordSynced) return lyrics;
        if (fallback.isEmpty) fallback = lyrics;
      }
    }
    // 一个候选都没搜到又出过错：报错，而不是说 QQ 没有这首歌。
    if (fallback.isEmpty && candidates.isEmpty && searchError != null) throw searchError;
    return fallback;
  }

  Future<List<QqSong>> search(String keyword) async {
    final res = await _client
        .post(
          Uri.parse('https://u.y.qq.com/cgi-bin/musicu.fcg'),
          headers: {..._headers, 'Content-Type': 'application/json'},
          body: jsonEncode({
            'req_1': {
              'module': 'music.search.SearchCgiService',
              'method': 'DoSearchForQQMusicDesktop',
              'param': {'num_per_page': 20, 'page_num': 1, 'query': keyword, 'search_type': 0},
            },
          }),
        )
        .timeout(_timeout);
    if (res.statusCode != 200) throw http.ClientException('QQ 搜索 HTTP ${res.statusCode}');
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    final req = data is Map ? data['req_1'] : null;
    if (data['code'] != 0 || req is! Map || req['code'] != 0) {
      throw http.ClientException('QQ 搜索接口返回失败');
    }
    final list = (((req['data'] as Map?)?['body'] as Map?)?['song'] as Map?)?['list'];
    final out = <int, QqSong>{};
    for (final raw in list is List ? list : const []) {
      if (raw is! Map) continue;
      // 同一首歌的其他发行版本在 grp 里。
      for (final e in [raw, ...?(raw['grp'] as List?)]) {
        if (e is! Map) continue;
        final id = int.tryParse('${e['id']}') ?? 0;
        var title = '${e['title'] ?? e['name'] ?? ''}';
        final rawName = '${e['name'] ?? ''}';
        if (title.isNotEmpty && rawName.contains(title)) title = rawName;
        final artists = [
          for (final s in (e['singer'] as List?) ?? const [])
            if (s is Map && '${s['name'] ?? ''}'.isNotEmpty) '${s['name']}',
        ];
        if (id <= 0 || title.isEmpty || artists.isEmpty) continue;
        final album = e['album'];
        out[id] = QqSong(
          id: id,
          name: title,
          artists: artists,
          album: album is Map ? '${album['title'] ?? album['name'] ?? ''}' : '',
          durationMs: (int.tryParse('${e['interval']}') ?? 0) * 1000,
          subtitle: '${e['subtitle'] ?? ''}',
        );
      }
    }
    return out.values.toList();
  }

  Future<QqLyricTexts> download(int songId) async {
    final res = await _client
        .post(
          Uri.parse('https://c.y.qq.com/qqmusic/fcgi-bin/lyric_download.fcg'),
          headers: _headers,
          body: {'version': '15', 'miniversion': '82', 'lrctype': '4', 'musicid': '$songId'},
        )
        .timeout(_timeout);
    if (res.statusCode != 200) throw http.ClientException('QQ 歌词 HTTP ${res.statusCode}');
    return decodeDownloadResponse(utf8.decode(res.bodyBytes, allowMalformed: true));
  }
}

// ------------------------------------------------------------------ 响应解码

final _resultCode = RegExp(r'''<result\b[^>]*\bcode\s*=\s*["']?(-?\d+)''');
final _cdata = RegExp(r'^<!\[CDATA\[([\s\S]*)\]\]>$');

String _field(String xml, String tag) {
  final m = RegExp('<$tag\\b[^>]*>([\\s\\S]*?)</$tag>').firstMatch(xml);
  if (m == null) return '';
  final body = m.group(1)!.trim();
  return (_cdata.firstMatch(body)?.group(1) ?? body).trim();
}

/// 拆出原文、翻译、罗马音三段，各自独立解密：翻译坏了不影响原文。
/// 服务端明确拒绝（`result code` 非 0）时抛 [FormatException]。
QqLyricTexts decodeDownloadResponse(String response) {
  final xml = response.replaceAll('<!--', '').replaceAll('-->', '');
  final code = _resultCode.firstMatch(xml)?.group(1);
  if (code != null && code != '0') throw FormatException('QQ 歌词下载被拒绝：result=$code');
  String decode(String tag) {
    var text = _field(xml, tag);
    if (text.isEmpty) return '';
    try {
      if (RegExp(r'^[0-9a-fA-F\s]+$').hasMatch(text)) text = decryptQrc(text);
      return unwrapLyricContent(text);
    } on FormatException {
      return '';
    }
  }

  return (
    original: decode('content'),
    translation: decode('contentts'),
    romaji: decode('contentroma'),
  );
}

/// 解密后的文本可能是包着 `<Lyric_1 LyricContent="…"/>` 的 XML，也可能直接是 QRC / LRC。
///
/// QQ 的 XML 不规范（属性值里可能有未转义的引号、`<`、`&`），所以不走 XML 解析器，
/// 而是取到 `LyricContent="` 之后、最后一个闭合 `"/>` 之前的内容。
String unwrapLyricContent(String text) {
  text = text.trim();
  if (text.startsWith('﻿')) text = text.substring(1);
  if (!text.startsWith('<')) return text;
  final m = RegExp(r'''<Lyric_1\b[\s\S]*?\bLyricContent\s*=\s*(["'])([\s\S]*)\1\s*/?>''')
      .firstMatch(text);
  if (m == null) return '';
  return _unescapeXml(m.group(2)!);
}

String _unescapeXml(String s) => s.replaceAllMapped(
  RegExp(r'&(amp|lt|gt|quot|apos|#\d+|#x[0-9a-fA-F]+);'),
  (m) => switch (m.group(1)!) {
    'amp' => '&',
    'lt' => '<',
    'gt' => '>',
    'quot' => '"',
    'apos' => "'",
    final n when n.startsWith('#x') => String.fromCharCode(int.parse(n.substring(2), radix: 16)),
    final n => String.fromCharCode(int.parse(n.substring(1))),
  },
);

// ------------------------------------------------------------------ 匹配

final _artistSeparator = RegExp(
  r'\s+(?:feat\.?|ft\.?|featuring|and|x)\s+|[、,&;／/＆]',
  caseSensitive: false,
);

const _versions = {
  'live': r'\blive\b|现场|演唱会',
  'instrumental': r'\binstrumental\b|\baccompaniment\b|伴奏|纯音乐',
  'cover': r'\bcover\b|翻唱',
  'remix': r'\bremix\b|\bmix\b|混音',
  'sped': r'\bsped[\s-]*up\b|加速|倍速',
  'slow': r'\bslow(?:ed)?\b|慢速|降速',
  'acoustic': r'\bacoustic\b|不插电',
  'demo': r'\bdemo\b|小样',
  'remaster': r'\bremaster(?:ed)?\b|重制|重录',
  'mandarin': r'国语版|普通话版|mandarin\s+version',
  'cantonese': r'粤语版|广东话版|cantonese\s+version',
  'english': r'英文版|英语版|english\s+version',
  'japanese': r'日语版|日文版|japanese\s+version',
  'korean': r'韩语版|韩文版|korean\s+version',
  'clean': r'\bclean\b|消音版',
  'explicit': r'\bexplicit\b',
};

/// 不影响歌词内容和时间轴的标记，比较版本时忽略。
const _cosmeticVersions = {'remaster', 'clean', 'explicit'};
final _versionRes = {
  for (final e in _versions.entries) e.key: RegExp(e.value, caseSensitive: false),
};
final _brackets = RegExp(r'\([^()]*\)|\[[^\[\]]*\]|【[^【】]*】|（[^（）]*）');
final _description = RegExp(
  r'主题曲|片尾曲|片头曲|插曲|推广曲|原声带|soundtrack|^\W*(?:feat\.?|ft\.?|featuring|with)\s',
  caseSensitive: false,
);

String _stripBrackets(String v) =>
    v.replaceAll(_brackets, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

/// 搜索用的标题：去掉影视注释、feat. 这类括注，保留版本标记。
String searchTitle(String title) => title
    .replaceAllMapped(_brackets, (m) {
      final inner = m.group(0)!.substring(1, m.group(0)!.length - 1);
      return _description.hasMatch(inner) ? ' ' : m.group(0)!;
    })
    .replaceAll(RegExp(r'\s+(?:feat\.?|ft\.?|featuring)\s.*$', caseSensitive: false), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// 全角转半角、转小写、只留字母数字（含汉字、假名等）。没有做繁简转换。
String normalizeTitle(String v) {
  final sb = StringBuffer();
  for (var r in _unescapeXml(v).runes) {
    if (r >= 0xFF01 && r <= 0xFF5E) r -= 0xFEE0;
    if (r == 0x3000) r = 0x20;
    final ch = String.fromCharCode(r).toLowerCase();
    if (RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(ch)) sb.write(ch);
  }
  return sb.toString();
}

/// 标题主干 + 版本标记（live、remix、伴奏……）。版本不同的不是同一录音。
({String base, Set<String> versions}) titleKey(String name, [String subtitle = '']) {
  final brackets = _brackets.allMatches(name).map((m) => m.group(0)!).toList();
  final suffix = RegExp(
    r'(?:\s+-\s+|\s+)(live|instrumental|remix|acoustic|demo|remastered|sped up|slowed)(?:\s+version)?$',
    caseSensitive: false,
  ).firstMatch(name);
  final context = [...brackets, subtitle, suffix?.group(0) ?? ''].join(' ');
  final versions = {
    for (final e in _versionRes.entries)
      if (!_cosmeticVersions.contains(e.key) && e.value.hasMatch(context)) e.key,
  };
  var base = suffix == null ? name : name.substring(0, suffix.start);
  base = base.replaceAllMapped(_brackets, (m) {
    final t = m.group(0)!;
    final inner = t.substring(1, t.length - 1);
    return _description.hasMatch(inner) || _versionRes.values.any((r) => r.hasMatch(t)) ? '' : t;
  });
  // 标题末尾不带括号的 feat.：Song feat. Someone。
  base = base.replaceFirst(
    RegExp(r'\s+(?:feat\.?|ft\.?|featuring)\s.*$', caseSensitive: false),
    '',
  );
  base = base.replaceFirst(RegExp(r'(?:现场|伴奏|翻唱|加速|慢速|国语|粤语|英文|日语|韩语)版$'), '');
  return (base: normalizeTitle(base), versions: versions);
}

/// 每位歌手的几种写法：完整名、去掉括注的名字、括注里的名字。
/// QQ 常写成 `IU (아이유)`、`防弹少年团 (BTS)`，网易云多半只写其中一个。
List<Set<String>> artistAliases(List<String> names) {
  final out = <Set<String>>[];
  for (final n in names) {
    for (final part in n.split(_artistSeparator)) {
      final full = normalizeTitle(part);
      if (full.isEmpty) continue;
      final keys = {
        full,
        normalizeTitle(part.replaceAll(_brackets, '')),
        for (final m in _brackets.allMatches(part))
          normalizeTitle(m.group(0)!.substring(1, m.group(0)!.length - 1)),
      }..remove('');
      if (out.any((o) => o.first == full)) continue;
      out.add(keys); // 第一个元素是完整名。
    }
  }
  return out;
}

bool _sameArtist(Set<String> a, Set<String> b) => a.any(b.contains);

/// 2 × 最长公共子序列 / 总长，和 difflib 的 ratio 同量纲。
double similarity(String a, String b) {
  if (a.isEmpty && b.isEmpty) return 1;
  final x = a.runes.toList(), y = b.runes.toList();
  var prev = List.filled(y.length + 1, 0);
  for (var i = 1; i <= x.length; i++) {
    final cur = List.filled(y.length + 1, 0);
    for (var j = 1; j <= y.length; j++) {
      cur[j] = x[i - 1] == y[j - 1] ? prev[j - 1] + 1 : max(prev[j], cur[j - 1]);
    }
    prev = cur;
  }
  return 2 * prev[y.length] / (x.length + y.length);
}

bool _setEq(Set<String> a, Set<String> b) => a.length == b.length && a.containsAll(b);

double? _titleScore(String source, QqSong c) {
  final t1 = titleKey(source);
  final t2 = titleKey(c.name, c.subtitle);
  if (t1.base.isEmpty || t2.base.isEmpty || !_setEq(t1.versions, t2.versions)) return null;
  final score = similarity(t1.base, t2.base);
  // 短标题必须完全一致：差一个字就可能是另一首歌。
  if (score < 0.88 || (min(t1.base.length, t2.base.length) <= 4 && t1.base != t2.base)) {
    return null;
  }
  return score;
}

/// 给候选打分；明显不是同一录音时返回 null。满分 100。
QqMatch? scoreMatch(Song source, QqSong c) {
  // 网易云的别名 / 译名也算标题：有些歌两边用的是不同语言的歌名。
  final titleScore = [
    for (final t in [source.title, ?source.subtitle])
      if (t.isNotEmpty) ?_titleScore(t, c),
  ].fold<double?>(null, (a, b) => a == null || b > a ? b : a);
  if (titleScore == null) return null;
  final a1 = artistAliases([source.artist]), a2 = artistAliases(c.artists);
  if (a1.isEmpty || a2.isEmpty) return null;
  // 只靠合作歌手对上不够：QQ 的主唱必须在网易云的歌手里。
  // 反过来不要求，因为 QQ 常把网易云的主唱写成 feat.，或者漏掉合作歌手。
  bool inA2(Set<String> a) => a2.any((b) => _sameArtist(a, b));
  if (!a1.any((a) => _sameArtist(a, a2.first))) return null;
  final common = a1.where(inA2).length;
  final overlap = common / (a1.length + a2.length - common);
  // 主唱对上就是大头，合作歌手列得多或少只扣一点：两边平台常常漏写 feat.。
  final artistScore = 0.7 + 0.3 * overlap;
  final srcMs = source.duration.inMilliseconds;
  if (srcMs <= 0 || c.durationMs <= 0) return null;
  final diff = (srcMs - c.durationMs).abs();
  if (diff > 10000) return null;
  final durationScore = diff <= 2000
      ? 1.0
      : diff <= 5000
      ? 0.8
      : 0.8 * (10000 - diff) / 5000;
  final album = normalizeTitle(source.album);
  final albumScore = album.isNotEmpty && album == normalizeTitle(c.album) ? 1.0 : 0.0;
  return QqMatch(c, 45 * titleScore + 35 * artistScore + 15 * durationScore + 5 * albumScore, diff);
}

/// 同名、同版本、同主唱的就是同一首歌，只是发在不同专辑里（单曲、专辑、精选集）。
/// 时长差几秒不算另一首：这种情况按时长更近的优先，而不是因为“有歧义”整个放弃。
bool _sameRecording(QqSong a, QqSong b) {
  final ta = titleKey(a.name, a.subtitle), tb = titleKey(b.name, b.subtitle);
  final aa = artistAliases(a.artists), ab = artistAliases(b.artists);
  return ta.base == tb.base &&
      _setEq(ta.versions, tb.versions) &&
      aa.isNotEmpty &&
      ab.isNotEmpty &&
      _sameArtist(aa.first, ab.first) &&
      (a.durationMs - b.durationMs).abs() <= 10000;
}

/// 选出可信的候选（最多 3 个，都是同一录音）。最高分低于 85、或和另一录音分差小于 8 时放弃。
List<QqMatch> selectMatches(Song source, List<QqSong> candidates, {Set<int> exclude = const {}}) {
  final matches = [for (final c in candidates) ?scoreMatch(source, c)]
    ..sort((a, b) {
      final s = b.score.compareTo(a.score);
      return s != 0 ? s : a.durationDiffMs - b.durationDiffMs;
    });
  if (matches.isEmpty || matches.first.score < 85) return const [];
  final best = matches.first;
  for (final m in matches.skip(1)) {
    if (_sameRecording(best.song, m.song)) continue;
    if (best.score - m.score < 8) return const [];
    break;
  }
  return matches
      .where(
        (m) => m.score >= 85 && _sameRecording(best.song, m.song) && !exclude.contains(m.song.id),
      )
      .take(3)
      .toList();
}
