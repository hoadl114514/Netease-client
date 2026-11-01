import 'package:flutter/painting.dart';

/// 歌曲。[palette] 是封面图加载出来之前的占位色，也是取不到封面主色时播放页背景的兜底。
class Song {
  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    this.coverUrl,
    this.subtitle,
    this.artists = const [],
    this.albumId,
    this._palette,
  });

  final String id;
  final String title;

  /// 带 id 的歌手列表，用于跳转歌手页。和 [artist] 一一对应；本地构造的歌曲可能为空。
  final List<ArtistRef> artists;

  /// 专辑 id，用于跳转专辑页。
  final String? albumId;

  /// 多位歌手用 ` / ` 连接。
  final String artist;
  final String album;
  final Duration duration;
  final String? coverUrl;

  /// 别名或译名，例如 `(TV动画《…》片头曲)`。
  final String? subtitle;
  final List<Color>? _palette;

  List<Color> get palette => _palette ?? fallbackPalette(id);

  @override
  bool operator ==(Object other) => other is Song && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class Playlist {
  const Playlist({
    required this.id,
    required this.name,
    required this.playCount,
    this.trackCount = 0,
    this.coverUrl,
    this.creator,
    this.creatorId,
    this.description,
    this.subscribed = false,
    this.isLikedList = false,
    this._palette,
  });

  final String id;
  final String name;
  final int playCount;
  final int trackCount;
  final String? coverUrl;
  final String? creator;
  final int? creatorId;

  /// 简介；排行榜用来放更新频率（如「每周四更新」）。
  final String? description;

  /// 当前账号是否收藏了这个歌单（自己创建的为 false）。
  final bool subscribed;

  /// 账号的「我喜欢的音乐」。
  final bool isLikedList;
  final List<Color>? _palette;

  List<Color> get palette => _palette ?? fallbackPalette(id);

  /// 换一个封面（[url] 为 null 时原样返回）。
  Playlist withCover(String? url) => url == null || url == coverUrl
      ? this
      : Playlist(
          id: id,
          name: name,
          playCount: playCount,
          trackCount: trackCount,
          coverUrl: url,
          creator: creator,
          creatorId: creatorId,
          description: description,
          subscribed: subscribed,
          isLikedList: isLikedList,
          palette: _palette,
        );
}

class ArtistRef {
  const ArtistRef(this.id, this.name);

  final String id;
  final String name;
}

class Artist {
  const Artist({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.description,
    this.songCount = 0,
    this.albumCount = 0,
  });

  final String id;
  final String name;
  final String? avatarUrl;
  final String? description;
  final int songCount;
  final int albumCount;
}

class Album {
  const Album({
    required this.id,
    required this.name,
    required this.artist,
    this.coverUrl,
    this.publishTime,
    this.size = 0,
    this.description,
  });

  final String id;
  final String name;

  /// 多位歌手用 ` / ` 连接。
  final String artist;
  final String? coverUrl;
  final DateTime? publishTime;

  /// 曲目数。
  final int size;
  final String? description;
}

class UserProfile {
  const UserProfile({
    required this.userId,
    required this.nickname,
    this.avatarUrl,
    this.vipType = 0,
  });

  final int userId;
  final String nickname;
  final String? avatarUrl;

  /// 0 为普通用户，其他值为各类会员。
  final int vipType;
}

/// 网易云的音质档位，从低到高排列；[index] 越大越好。
enum AudioQuality {
  standard('standard', 'l', '标准', '标准'),
  higher('higher', 'm', '较高', '较高'),
  exhigh('exhigh', 'h', '极高', 'HQ'),
  lossless('lossless', 'sq', '无损', 'SQ'),
  hires('hires', 'hr', 'Hi-Res', 'Hi-Res'),
  jyeffect('jyeffect', 'je', '高清环绕声', '环绕'),
  sky('sky', 'sk', '沉浸环绕声', '沉浸'),
  dolby('dolby', 'db', '杜比全景声', 'Dolby'),
  jymaster('jymaster', 'jm', '超清母带', '母带');

  const AudioQuality(this.level, this.detailKey, this.label, this.badge);

  /// 接口里的 `level` 值。
  final String level;

  /// `song/music/detail/get` 返回里对应的字段名。
  final String detailKey;
  final String label;

  /// 播放页歌手名前的小徽章。
  final String badge;

  static AudioQuality? fromLevel(String? level) {
    for (final q in values) {
      if (q.level == level) return q;
    }
    return null;
  }

  /// 在 [available] 里挑一个：不超过 [preferred] 的最高档；都比它高就取最低档。
  static AudioQuality? pick(Iterable<AudioQuality> available, AudioQuality preferred) {
    final sorted = available.toList()..sort((a, b) => a.index - b.index);
    if (sorted.isEmpty) return null;
    return sorted.lastWhere((q) => q.index <= preferred.index, orElse: () => sorted.first);
  }
}

/// 某一档音质的文件信息。
class QualityInfo {
  const QualityInfo({
    required this.quality,
    required this.bitrate,
    required this.size,
    this.sampleRate,
  });

  final AudioQuality quality;

  /// bit/s。
  final int bitrate;

  /// 字节。
  final int size;
  final int? sampleRate;
}

/// 取到的播放地址。[quality] 是服务端实际给的档位，可能低于请求的档位（版权或会员限制）。
class SongUrl {
  const SongUrl({required this.url, required this.quality, this.trial});

  final String url;
  final AudioQuality? quality;

  /// 非 null 表示只给了试听片段，值为片段在整首歌里的起止时间。
  final ({Duration start, Duration end})? trial;
}

/// 逐字歌词里的一个"字"（实际上可以是一个词或一个音节）。
class LyricWord {
  const LyricWord(this.text, this.start, this.end);

  final String text;
  final Duration start;
  final Duration end;

  /// 在 [position] 时该字已唱出的比例，0–1。
  double progressAt(Duration position) {
    if (position <= start) return 0;
    if (position >= end) return 1;
    return (position - start).inMicroseconds / (end - start).inMicroseconds;
  }
}

class LyricLine {
  const LyricLine({
    required this.start,
    required this.end,
    required this.words,
    this.translation,
    this.romaji,
  });

  final Duration start;
  final Duration end;

  /// 逐字歌词时每个字单独计时；逐行歌词时只有一个覆盖整行的"字"。
  final List<LyricWord> words;
  final String? translation;
  final String? romaji;

  String get text => words.map((w) => w.text).join();

  LyricLine copyWith({String? translation, String? romaji}) => LyricLine(
    start: start,
    end: end,
    words: words,
    translation: translation ?? this.translation,
    romaji: romaji ?? this.romaji,
  );
}

enum LyricSource {
  netease('网易云'),
  qq('QQ 音乐');

  const LyricSource(this.label);

  final String label;

  static LyricSource? byName(String? name) {
    for (final s in values) {
      if (s.name == name) return s;
    }
    return null;
  }
}

/// 一首歌的完整歌词。
class Lyrics {
  const Lyrics({required this.lines, required this.source, required this.wordSynced});

  static const empty = Lyrics(lines: [], source: null, wordSynced: false);

  final List<LyricLine> lines;

  /// 歌词来自哪里；没有歌词时为 null。
  final LyricSource? source;

  /// 是否逐字。
  final bool wordSynced;

  bool get isEmpty => lines.isEmpty;
  bool get hasTranslation => lines.any((l) => l.translation != null);
  bool get hasRomaji => lines.any((l) => l.romaji != null);
}

/// 评论区属于哪类资源。网易云用 `前缀 + id` 作为评论区 id（threadId）。
enum CommentTarget {
  song('R_SO_4_'),
  playlist('A_PL_0_'),
  album('R_AL_3_');

  const CommentTarget(this.prefix);

  final String prefix;

  String threadId(String id) => '$prefix$id';
}

/// 评论排序：按热度或按时间。
enum CommentSort {
  hot(2, '热门'),
  latest(3, '最新');

  const CommentSort(this.type, this.label);

  /// 接口里的 sortType。
  final int type;
  final String label;
}

class CommentUser {
  const CommentUser({required this.userId, required this.nickname, this.avatarUrl});

  final int userId;
  final String nickname;
  final String? avatarUrl;
}

/// 一条评论。楼中楼回复也用它，[replyTo] 是被回复的那条（可能已删除，为 null）。
class Comment {
  const Comment({
    required this.id,
    required this.user,
    required this.content,
    required this.time,
    this.likedCount = 0,
    this.liked = false,
    this.replyCount = 0,
    this.replyTo,
    this.location,
  });

  final int id;
  final CommentUser user;
  final String content;
  final DateTime time;
  final int likedCount;
  final bool liked;

  /// 楼层里的回复数。
  final int replyCount;
  final ({int id, String nickname, String content})? replyTo;

  /// IP 属地，如「广东」。
  final String? location;

  Comment copyWith({int? likedCount, bool? liked, int? replyCount}) => Comment(
    id: id,
    user: user,
    content: content,
    time: time,
    likedCount: likedCount ?? this.likedCount,
    liked: liked ?? this.liked,
    replyCount: replyCount ?? this.replyCount,
    replyTo: replyTo,
    location: location,
  );
}

/// 一页评论。[cursor] 原样传给下一页。
class CommentPage {
  const CommentPage({
    required this.comments,
    required this.total,
    required this.hasMore,
    required this.cursor,
  });

  final List<Comment> comments;
  final int total;
  final bool hasMore;
  final String cursor;
}

/// 根据 id 稳定地挑一组占位色。
List<Color> fallbackPalette(String seed) {
  const palettes = [
    [Color(0xFFF7A8C8), Color(0xFF8E7CF0), Color(0xFFFFD98A)],
    [Color(0xFF6FA8DC), Color(0xFF2B3F66), Color(0xFFBFD8F2)],
    [Color(0xFF1B1036), Color(0xFFE0367F), Color(0xFF29D3F0)],
    [Color(0xFF5A3A22), Color(0xFFE09A4A), Color(0xFF1E140E)],
    [Color(0xFF3B2A4D), Color(0xFFB0605A), Color(0xFFE8B66B)],
    [Color(0xFF2E5E4E), Color(0xFF9FD3A8), Color(0xFF14261F)],
  ];
  // 不用 String.hashCode：它在不同运行之间不保证稳定。
  var h = 0;
  for (final c in seed.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return palettes[h % palettes.length];
}
