import 'package:flutter_test/flutter_test.dart';
import 'package:netease_client/data/mock_data.dart';
import 'package:netease_client/state/player_controller.dart';

void main() {
  late PlayerController player;

  setUp(() => player = PlayerController(queue: MockData.queue));
  tearDown(() => player.dispose());

  test('activeLyricIndex follows position and offset', () {
    final lines = player.song.lyrics;
    expect(player.activeLyricIndex, -1);

    player.seek(lines[3].start);
    expect(player.activeLyricIndex, 3);

    player.seek(lines[3].start - const Duration(milliseconds: 1));
    expect(player.activeLyricIndex, 2);

    // 歌词提前 1 秒后，同一播放位置应落到下一行。
    player.seek(lines[3].start - const Duration(milliseconds: 500));
    player.adjustLyricOffset(const Duration(seconds: 1));
    expect(player.activeLyricIndex, 3);
  });

  test('seek clamps to song bounds', () {
    player.seek(const Duration(hours: 1));
    expect(player.position, player.song.duration);
    player.seek(const Duration(seconds: -1));
    expect(player.position, Duration.zero);
  });

  test('previous restarts the song after 3 seconds, otherwise wraps the queue', () {
    player.seek(const Duration(seconds: 10));
    player.previous();
    expect(player.position, Duration.zero);
    expect(player.song.id, MockData.queue.first.id);

    player.previous();
    expect(player.song.id, MockData.queue.last.id);
  });

  test('like is per song', () {
    player.toggleLike();
    expect(player.isLiked, isTrue);
    player.next();
    expect(player.isLiked, isFalse);
  });

  test('lyric words are contiguous within each line', () {
    for (final line in MockData.current.lyrics) {
      expect(line.words.first.start, line.start);
      for (var i = 1; i < line.words.length; i++) {
        expect(line.words[i].start, line.words[i - 1].end);
      }
      expect(line.words.last.end <= line.end, isTrue);
    }
  });
}
