import 'package:flutter/painting.dart';

/// 歌曲。接入真实 API 前，封面用 [palette] 生成的渐变图代替。
class Song {
  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.palette,
    this.tags = const [],
    this.lyrics = const [],
  });

  final String id;
  final String title;
  final String artist;
  final String album;
  final Duration duration;
  final List<Color> palette;

  /// 音质 / 歌词类型等标签，例如 `SQ`、`逐字`。
  final List<String> tags;
  final List<LyricLine> lyrics;
}

class Playlist {
  const Playlist({
    required this.id,
    required this.name,
    required this.playCount,
    required this.palette,
    this.trackCount = 0,
  });

  final String id;
  final String name;
  final int playCount;
  final int trackCount;
  final List<Color> palette;
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
  final List<LyricWord> words;
  final String? translation;
  final String? romaji;

  String get text => words.map((w) => w.text).join();
}
