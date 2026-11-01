import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/models.dart';

/// 假播放器：没有真实音频，只用计时器推进进度，用来驱动 UI。
/// 接入音频引擎后保持这套接口不变，内部换成真实回调即可。
class PlayerController extends ChangeNotifier {
  PlayerController({required List<Song> queue, Duration initialPosition = Duration.zero})
    : assert(queue.isNotEmpty),
      _queue = List.unmodifiable(queue),
      _position = initialPosition;

  static const _tick = Duration(milliseconds: 50);

  final List<Song> _queue;
  int _index = 0;
  Duration _position;
  bool _playing = false;
  final Set<String> _liked = {};
  Duration _lyricOffset = Duration.zero;
  double _volume = 0.7;

  Timer? _timer;
  final Stopwatch _stopwatch = Stopwatch();

  Song get song => _queue[_index];
  List<Song> get queue => _queue;
  Duration get position => _position;
  bool get isPlaying => _playing;
  bool get isLiked => _liked.contains(song.id);
  double get volume => _volume;

  /// 歌词时间轴偏移。正值表示歌词提前。
  Duration get lyricOffset => _lyricOffset;

  double get progress {
    final total = song.duration.inMicroseconds;
    return total == 0 ? 0 : (_position.inMicroseconds / total).clamp(0.0, 1.0);
  }

  /// 用于歌词对齐的时间点（已叠加偏移）。
  Duration get lyricPosition => _position + _lyricOffset;

  /// 当前所在歌词行；还没到第一行时返回 -1。
  int get activeLyricIndex {
    final lines = song.lyrics;
    final p = lyricPosition;
    var lo = 0, hi = lines.length - 1, ans = -1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (lines[mid].start <= p) {
        ans = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return ans;
  }

  void play() {
    if (_playing) return;
    _playing = true;
    _stopwatch
      ..reset()
      ..start();
    _timer = Timer.periodic(_tick, (_) => _advance());
    notifyListeners();
  }

  void pause() {
    if (!_playing) return;
    _advance(notify: false);
    _playing = false;
    _timer?.cancel();
    _timer = null;
    _stopwatch.stop();
    notifyListeners();
  }

  void toggle() => _playing ? pause() : play();

  void seek(Duration to) {
    _position = Duration(microseconds: to.inMicroseconds.clamp(0, song.duration.inMicroseconds));
    _stopwatch.reset();
    notifyListeners();
  }

  void seekBy(Duration delta) => seek(_position + delta);

  void next() => _jump(1);

  void previous() {
    // 和多数播放器一致：播放超过 3 秒时"上一首"先回到开头。
    if (_position > const Duration(seconds: 3)) {
      seek(Duration.zero);
    } else {
      _jump(-1);
    }
  }

  void toggleLike() {
    if (!_liked.remove(song.id)) _liked.add(song.id);
    notifyListeners();
  }

  void setVolume(double v) {
    _volume = v.clamp(0.0, 1.0);
    notifyListeners();
  }

  void adjustLyricOffset(Duration delta) {
    _lyricOffset += delta;
    notifyListeners();
  }

  void resetLyricOffset() {
    _lyricOffset = Duration.zero;
    notifyListeners();
  }

  void _jump(int step) {
    _index = (_index + step) % _queue.length;
    _position = Duration.zero;
    _stopwatch.reset();
    notifyListeners();
  }

  void _advance({bool notify = true}) {
    _position += _stopwatch.elapsed;
    _stopwatch.reset();
    if (_position >= song.duration) {
      _jump(1);
      return;
    }
    if (notify) notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// 把 [PlayerController] 挂到树上；依赖它的 widget 会在进度变化时重建。
class PlayerScope extends InheritedNotifier<PlayerController> {
  const PlayerScope({super.key, required PlayerController controller, required super.child})
    : super(notifier: controller);

  static PlayerController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PlayerScope>()!.notifier!;

  /// 只取引用、不订阅变化，用于按钮回调。
  static PlayerController read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<PlayerScope>()!.notifier!;
}
