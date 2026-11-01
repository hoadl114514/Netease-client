import 'package:flutter_test/flutter_test.dart';
import 'package:netease_client/data/models.dart';
import 'package:netease_client/lyrics/lyric_parser.dart';

Duration ms(int v) => Duration(milliseconds: v);

void main() {
  group('LRC', () {
    test('multiple stamps, 2/3-digit fractions, offset and empty lines', () {
      final lines = LyricParser.parseLrc(
        '[offset:500]\n[00:01.5][00:03.250]你好\n[00:02.00]\n[ti:标题]',
      );
      expect([for (final l in lines) (l.start, l.text)], [(1000, '你好'), (1500, ''), (2750, '你好')]);
    });

    test('NetEase JSON credit lines become plain lines', () {
      final lines = LyricParser.parseLrc('{"t":0,"c":[{"tx":"作词: "},{"tx":"某某"}]}\n[00:05.00]歌');
      expect(lines.first.text, '作词: 某某');
      expect(lines.first.start, 0);
    });
  });

  group('YRC', () {
    test('timing precedes each word and is absolute', () {
      final lines = LyricParser.parseYrc('[1000,2000](1000,400,0)Hi (1400,600,0)you');
      expect(lines.single.start, 1000);
      expect(lines.single.end, 3000);
      expect(
        [for (final w in lines.single.words!) (w.start, w.end, w.text)],
        [(1000, 1400, 'Hi '), (1400, 2000, 'you')],
      );
    });

    test('QRC text is not mistaken for YRC', () {
      expect(LyricParser.parseYrc('[1000,2000]你(1000,400)好(1400,600)'), isEmpty);
    });
  });

  group('QRC', () {
    test('timing follows each word; line time comes from words', () {
      final lines = LyricParser.parseQrc('[999,9999]你(1000,400)好(1400,600)');
      expect(lines.single.start, 1000);
      expect(lines.single.end, 2000);
      expect(lines.single.text, '你好');
    });

    test('parentheses inside text', () {
      final l = LyricParser.parseQrc(
        '[1000,2000]A &(1000,300) (1300,100)((1400,100)B(1500,300))(1800,200)',
      );
      expect(l.single.text, 'A & (B)');
    });

    test('rejects incomplete or out-of-order lines', () {
      for (final v in [
        '[1000,2000]你好',
        '[1000,2000]你(1000,400)好',
        '[1000,2000]你(1400,400)好(1000,400)',
      ]) {
        expect(LyricParser.parseQrc(v), isEmpty, reason: v);
      }
    });

    test('offset is subtracted once and clamps at zero', () {
      expect(
        LyricParser.parseQrc('[offset:100]\n[1000,2000]你(1000,400)好(1400,600)').single.start,
        900,
      );
      final l = LyricParser.parseQrc('[offset:1200]\n[1000,2000]你(1000,400)好(1400,600)').single;
      expect((l.words!.first.start, l.words!.first.end), (0, 200));
    });
  });

  group('build', () {
    test('word-synced main with LRC translation; "//" means no translation', () {
      final lyrics = LyricParser.build(
        main: '[1000,1000](1000,500,0)一(1500,500,0)二\n[3000,1000](3000,1000,0)三',
        translation: '[00:01.10]第一行\n[00:03.00]//',
        source: LyricSource.netease,
      );
      expect(lyrics.wordSynced, isTrue);
      expect(lyrics.lines.map((l) => l.translation), ['第一行', null]);
      expect(lyrics.lines.first.words.length, 2);
    });

    test('line-level lyrics end at the next line (including blank lines) or the song end', () {
      final lyrics = LyricParser.build(
        main: '[00:01.00]一\n[00:02.00]\n[00:05.00]二\n[00:20.00]超出歌曲',
        source: LyricSource.netease,
        duration: const Duration(seconds: 10),
      );
      expect(lyrics.wordSynced, isFalse);
      expect(
        [for (final l in lyrics.lines) (l.text, l.start, l.end)],
        [('一', ms(1000), ms(2000)), ('二', ms(5000), ms(20000))],
      );
      expect(lyrics.lines.first.words.single.text, '一');
    });

    test('translation further than the tolerance is not attached', () {
      final lyrics = LyricParser.build(
        main: '[00:01.00]一',
        translation: '[00:05.00]远',
        source: LyricSource.qq,
      );
      expect(lyrics.hasTranslation, isFalse);
    });

    test('romaji from QRC is attached by line', () {
      final lyrics = LyricParser.build(
        main: '[1000,1000]あ(1000,1000)',
        romaji: '[1000,1000]a(1000,1000)',
        source: LyricSource.qq,
      );
      expect(lyrics.lines.single.romaji, 'a');
    });

    test('nothing parseable gives empty lyrics', () {
      expect(LyricParser.build(main: '纯文本\n没有时间', source: LyricSource.netease).isEmpty, isTrue);
      expect(LyricParser.build(main: '[00:01.00]  ', source: LyricSource.netease).isEmpty, isTrue);
    });
  });
}
