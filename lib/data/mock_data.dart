import 'package:flutter/painting.dart';

import 'models.dart';

/// 预览用的假数据。歌名、歌手、歌词都是原创占位内容，接 API 后整个文件删掉即可。
abstract final class MockData {
  static const userName = '冬屿清';

  static const dailyPalette = [Color(0xFF3B2A4D), Color(0xFFB0605A), Color(0xFFE8B66B)];
  static const likedPalette = [Color(0xFFE85A9A), Color(0xFF6A4BC4), Color(0xFF1F1A3A)];

  static final Song current = Song(
    id: 's1',
    title: '星屑メロディー',
    artist: '月見ヶ丘ユニット',
    album: 'Starlight Pocket',
    duration: const Duration(minutes: 3, seconds: 56),
    palette: const [Color(0xFFF7A8C8), Color(0xFF8E7CF0), Color(0xFFFFD98A)],
    tags: const ['SQ', '逐字', '原创'],
    lyrics: _starDustLyrics,
  );

  static final List<Song> queue = [
    current,
    const Song(
      id: 's2',
      title: '雨音レター',
      artist: '白瀬しずく',
      album: '雨音レター',
      duration: Duration(minutes: 4, seconds: 12),
      palette: [Color(0xFF6FA8DC), Color(0xFF2B3F66), Color(0xFFBFD8F2)],
      tags: ['HQ'],
    ),
    const Song(
      id: 's3',
      title: 'Neon Drift',
      artist: 'KAIRO',
      album: 'Night Highway',
      duration: Duration(minutes: 2, seconds: 48),
      palette: [Color(0xFF1B1036), Color(0xFFE0367F), Color(0xFF29D3F0)],
      tags: ['SQ', 'Hi-Res'],
    ),
  ];

  static const List<Playlist> recommended = [
    Playlist(
      id: 'p1',
      name: '『ACG』深夜循环的温柔旋律',
      playCount: 600123,
      trackCount: 86,
      palette: [Color(0xFFE6E2DA), Color(0xFF7C7A86), Color(0xFF2E2C36)],
    ),
    Playlist(
      id: 'p2',
      name: '『日系』那些年追过的片头曲',
      playCount: 18234,
      trackCount: 120,
      palette: [Color(0xFF5A3A22), Color(0xFFE09A4A), Color(0xFF1E140E)],
    ),
    Playlist(
      id: 'p3',
      name: '随性街角 · 浪漫氛围',
      playCount: 14567,
      trackCount: 45,
      palette: [Color(0xFFBFB7A8), Color(0xFF6D6355), Color(0xFF34302A)],
    ),
    Playlist(
      id: 'p4',
      name: '二次元燃向战斗 BGM 合集',
      playCount: 632001,
      trackCount: 100,
      palette: [Color(0xFFF08A24), Color(0xFFFFFFFF), Color(0xFF3A3A3A)],
    ),
    Playlist(
      id: 'p5',
      name: '游戏角色曲精选（持续更新）',
      playCount: 180456,
      trackCount: 64,
      palette: [Color(0xFFE9862F), Color(0xFFF4F4F4), Color(0xFF2A2A2A)],
    ),
    Playlist(
      id: 'p6',
      name: '深夜电台：末日之后的回声',
      playCount: 38001,
      trackCount: 32,
      palette: [Color(0xFF0E0E0E), Color(0xFF3A3A3A), Color(0xFFDADADA)],
    ),
    Playlist(
      id: 'p7',
      name: '主线剧情经典曲目组曲',
      playCount: 17320,
      trackCount: 58,
      palette: [Color(0xFF2C2A24), Color(0xFFC9A646), Color(0xFF5B6B7A)],
    ),
    Playlist(
      id: 'p8',
      name: '【欧美】进口心脏起搏器',
      playCount: 375000,
      trackCount: 150,
      palette: [Color(0xFF2E2E2E), Color(0xFFD9C34A), Color(0xFF7E8F3A)],
    ),
    Playlist(
      id: 'p9',
      name: '你喜欢的 Afro 都在这里',
      playCount: 1142000,
      trackCount: 77,
      palette: [Color(0xFF6B3A2A), Color(0xFFE7B49A), Color(0xFF1C1210)],
    ),
    Playlist(
      id: 'p10',
      name: '魔法学园的优等生们',
      playCount: 59012,
      trackCount: 40,
      palette: [Color(0xFF14243D), Color(0xFF4F86C6), Color(0xFFEDEDED)],
    ),
    Playlist(
      id: 'p11',
      name: 'TV 动画 OP / ED 全收录',
      playCount: 45230,
      trackCount: 210,
      palette: [Color(0xFFF2EDE4), Color(0xFFE05A5A), Color(0xFF3B6EA8)],
    ),
    Playlist(
      id: 'p12',
      name: '摇滚 / 电音 / 流行（游戏向）',
      playCount: 15420,
      trackCount: 66,
      palette: [Color(0xFFDDE6F5), Color(0xFF9FB4D8), Color(0xFF5C6E99)],
    ),
    Playlist(
      id: 'p13',
      name: '电子振荡｜音波穿透霓虹',
      playCount: 100321,
      trackCount: 88,
      palette: [Color(0xFF2B0F4C), Color(0xFFE23E8B), Color(0xFF2EC4D6)],
    ),
    Playlist(
      id: 'p14',
      name: '唱片 / 塞壬 / 超长合辑',
      playCount: 940210,
      trackCount: 300,
      palette: [Color(0xFF3B2A1E), Color(0xFFE2B85C), Color(0xFF3E6FA6)],
    ),
  ];

  static const List<Playlist> created = [
    Playlist(
      id: 'c1',
      name: '从零开始的异世界…',
      playCount: 0,
      trackCount: 42,
      palette: [Color(0xFF8FB8F0), Color(0xFFE6EEFA), Color(0xFF5A6FA8)],
    ),
    Playlist(
      id: 'c2',
      name: '暂定',
      playCount: 0,
      trackCount: 7,
      palette: [Color(0xFF7A5CC8), Color(0xFFE88BC0), Color(0xFF3A2E6E)],
    ),
    Playlist(
      id: 'c3',
      name: 'phonk',
      playCount: 0,
      trackCount: 23,
      palette: [Color(0xFF1E2A2A), Color(0xFF4F8A7A), Color(0xFF0E1414)],
    ),
    Playlist(
      id: 'c4',
      name: '纯音乐',
      playCount: 0,
      trackCount: 61,
      palette: [Color(0xFF6CC7A0), Color(0xFFE8F4D8), Color(0xFF3A8A7A)],
    ),
    Playlist(
      id: 'c5',
      name: '吉吉岛',
      playCount: 0,
      trackCount: 15,
      palette: [Color(0xFF4A5A6A), Color(0xFFB7C4D0), Color(0xFF1E262E)],
    ),
  ];

  static final List<LyricLine> _starDustLyrics = [
    for (final (offset, verse) in const [(12.0, _verse), (82.0, _verse), (152.0, _verse)])
      for (final (i, l) in verse.indexed) _line(offset + i * 6.2, 5.6, l.$1, l.$2, l.$3),
  ];

  // (分词后的原文, 翻译, 罗马音)
  static const _verse = [
    (
      ['夜空', 'に', '灯', 'る', '小', 'さ', 'な', '光'],
      '夜空中亮起的小小光芒',
      'yo zo ra ni to mo ru chi i sa na hi ka ri',
    ),
    (['君', 'の', '名前', 'を', '呼', 'んで', 'み', 'た'], '试着呼唤了你的名字', 'ki mi no na ma e wo yo n de mi ta'),
    (['風', 'が', '運', 'ぶ', 'メロ', 'ディー'], '风儿带来的旋律', 'ka ze ga ha ko bu me ro di i'),
    (
      ['届', 'く', 'か', 'な ', '届', 'け', 'た', 'い', 'な'],
      '能传达到吗 好想传达给你',
      'to do ku ka na to do ke ta i na',
    ),
    (['星屑', 'を', '集', 'め', 'て'], '把星屑收集起来', 'ho shi ku zu wo a tsu me te'),
    (['ポケット', 'いっぱい', 'に', '詰', 'め', 'て'], '装满整个口袋', 'po ke tto i ppa i ni tsu me te'),
    (['明日', 'の', '扉', 'を', '開', 'け', 'よう'], '去打开明天的门吧', 'a shi ta no to bi ra wo a ke yo u'),
    (['ねえ ', '一緒', 'に', '歌', 'お', 'う', 'よ'], '呐 一起唱吧', 'ne e i ssho ni u ta o u yo'),
    (['きら', 'きら ', 'きら', 'きら'], '闪闪发光 闪闪发光', 'ki ra ki ra ki ra ki ra'),
    (['こ', 'の', '夜', 'が', '終', 'わ', 'る', 'ま', 'で'], '直到这个夜晚结束', 'ko no yo ru ga o wa ru ma de'),
  ];

  /// 按字数把一行的时长分给每个字，留最后 10% 当换气。
  static LyricLine _line(
    double startSec,
    double durSec,
    List<String> words,
    String translation,
    String romaji,
  ) {
    Duration at(double sec) => Duration(microseconds: (sec * 1e6).round());
    final totalChars = words.fold<int>(0, (n, w) => n + w.trim().length);
    final singing = durSec * 0.9;
    var t = startSec;
    final timed = <LyricWord>[];
    for (final w in words) {
      final d = singing * w.trim().length / totalChars;
      timed.add(LyricWord(w, at(t), at(t + d)));
      t += d;
    }
    return LyricLine(
      start: at(startSec),
      end: at(startSec + durSec),
      words: timed,
      translation: translation,
      romaji: romaji,
    );
  }
}
