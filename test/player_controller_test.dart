import 'package:flutter_test/flutter_test.dart';
import 'package:netease_client/data/models.dart';
import 'package:netease_client/state/player_controller.dart';
import 'package:netease_client/state/settings.dart';

import 'support/fakes.dart';

void main() {
  late FakeEngine engine;
  late FakeBackend backend;
  late AppSettings settings;
  late PlayerController player;
  final queue = [song('1'), song('2'), song('3')];

  setUp(() async {
    engine = FakeEngine();
    backend = FakeBackend();
    settings = await testSettings();
    player = PlayerController(engine: engine, backend: backend, settings: settings);
  });
  tearDown(() => player.dispose());

  test('empty player has no current song', () {
    expect(player.current, isNull);
    expect(player.isPlaying, isFalse);
  });

  test('playQueue picks the best offered quality not above the preference', () async {
    settings.preferredQuality = AudioQuality.lossless;
    backend.qualityMap['2'] = [AudioQuality.standard, AudioQuality.exhigh, AudioQuality.jymaster];
    await player.playQueue(queue, start: 1, title: '测试歌单');
    expect(player.song.id, '2');
    expect(player.queueTitle, '测试歌单');
    expect(backend.urlRequests.single, ('2', AudioQuality.exhigh));
    expect(player.quality, AudioQuality.exhigh);
    expect(player.qualities.map((q) => q.quality), [
      AudioQuality.standard,
      AudioQuality.exhigh,
      AudioQuality.jymaster,
    ]);
    expect(engine.loaded.single, 'https://x/2/exhigh');
    expect(engine.playing, isTrue);
    expect(player.isPlaying, isTrue);
  });

  test('AudioQuality.pick falls back to the lowest when everything is above', () {
    expect(
      AudioQuality.pick([AudioQuality.lossless, AudioQuality.hires], AudioQuality.standard),
      AudioQuality.lossless,
    );
    expect(AudioQuality.pick(const [], AudioQuality.standard), isNull);
  });

  test('server downgrade is reported and reflected', () async {
    settings.preferredQuality = AudioQuality.hires;
    backend.qualityMap['1'] = [AudioQuality.exhigh, AudioQuality.lossless, AudioQuality.hires];
    backend.accountMax = AudioQuality.exhigh;
    final notices = <String>[];
    player.notices.listen(notices.add);
    await player.playQueue(queue);
    await pumpEventQueue();
    expect(player.quality, AudioQuality.exhigh);
    expect(notices.single, contains('极高'));
  });

  test('setQuality keeps position and play state, and becomes the default', () async {
    backend.qualityMap['1'] = [AudioQuality.standard, AudioQuality.lossless];
    await player.playQueue(queue);
    engine.advance(const Duration(seconds: 42));
    await player.pause();
    await player.setQuality(AudioQuality.lossless);
    expect(engine.loaded.last, 'https://x/1/lossless');
    expect(engine.loadStart, const Duration(seconds: 42));
    expect(player.position, const Duration(seconds: 42));
    expect(engine.playing, isFalse);
    expect(settings.preferredQuality, AudioQuality.lossless);
  });

  test('unavailable songs are skipped while playing, but not forever', () async {
    backend.unavailable.addAll(['1', '2']);
    await player.playQueue(queue);
    await pumpEventQueue();
    expect(player.song.id, '3');
    expect(engine.loaded.single, contains('/3/'));

    backend.unavailable.add('3');
    await player.jumpTo(0);
    await pumpEventQueue();
    // 三首都不能放：试过一圈后停下，不无限循环。
    expect(player.isPlaying, isFalse);
  });

  test('lyrics load with fallback, and source switch keeps old lyrics when empty', () async {
    backend.lyricsMap[('1', LyricSource.qq)] = karaoke(source: LyricSource.qq);
    await player.playQueue(queue);
    await pumpEventQueue();
    expect(player.lyrics.source, LyricSource.qq); // 默认网易云没有，自动换 QQ。

    final notices = <String>[];
    player.notices.listen(notices.add);
    await player.setLyricSource(LyricSource.netease);
    await pumpEventQueue();
    expect(player.lyrics.source, LyricSource.qq);
    expect(notices.single, contains('网易云'));
  });

  test('activeLyricIndex follows position and offset', () async {
    backend.lyricsMap[('1', LyricSource.netease)] = karaoke();
    await player.playQueue(queue);
    await pumpEventQueue();
    final lines = player.lyrics.lines;
    expect(player.activeLyricIndex, -1);

    await player.seek(lines[3].start);
    expect(player.activeLyricIndex, 3);

    await player.seek(lines[3].start - const Duration(milliseconds: 1));
    expect(player.activeLyricIndex, 2);

    // 歌词提前 1 秒后，同一播放位置应落到下一行。
    await player.seek(lines[3].start - const Duration(milliseconds: 500));
    player.adjustLyricOffset(const Duration(seconds: 1));
    expect(player.activeLyricIndex, 3);
  });

  test('trial clips map lyric time back to the full song', () async {
    backend.trials['1'] = (start: const Duration(seconds: 60), end: const Duration(seconds: 90));
    await player.playQueue(queue);
    expect(player.duration, const Duration(seconds: 30));
    await player.seek(const Duration(seconds: 5));
    expect(player.lyricPosition, const Duration(seconds: 65));
  });

  test('seek clamps to song bounds', () async {
    await player.playQueue(queue);
    await player.seek(const Duration(hours: 1));
    expect(player.position, player.duration);
    await player.seek(const Duration(seconds: -1));
    expect(player.position, Duration.zero);
  });

  test('previous restarts after 3 seconds, otherwise wraps the queue', () async {
    await player.playQueue(queue);
    await player.seek(const Duration(seconds: 10));
    await player.previous();
    expect(player.position, Duration.zero);
    expect(player.song.id, '1');

    await player.previous();
    expect(player.song.id, '3');
  });

  test('completion advances; repeat-one replays the same song', () async {
    await player.playQueue(queue);
    engine.complete();
    await pumpEventQueue();
    expect(player.song.id, '2');

    player.toggleRepeat();
    expect(player.repeat, Repeat.one);
    engine.advance(const Duration(seconds: 100));
    engine.complete();
    await pumpEventQueue();
    expect(player.song.id, '2');
    expect(player.position, Duration.zero);
  });

  test('a slow load for an old song does not override the new one', () async {
    final first = player.playQueue(queue); // 不等它。
    final second = player.jumpTo(2);
    await Future.wait([first, second]);
    expect(player.song.id, '3');
    expect(engine.loaded.last, contains('/3/'));
  });
}
