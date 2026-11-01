import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';

import '../api/netease_api.dart';
import '../audio/audio_engine.dart';
import '../data/models.dart';
import '../lyrics/lyric_service.dart';
import '../widgets/cover_palette.dart';
import 'settings.dart';

/// 播放器需要的数据来源。测试里换成假的实现。
abstract class PlaybackBackend {
  Future<List<QualityInfo>> qualities(String songId);
  Future<SongUrl?> songUrl(String songId, AudioQuality quality);
  Future<Lyrics> lyrics(Song song, LyricSource source, {required bool fallback});
}

class NeteaseBackend implements PlaybackBackend {
  NeteaseBackend(this._api, this._lyrics);

  final NeteaseApi _api;
  final LyricService _lyrics;

  @override
  Future<List<QualityInfo>> qualities(String songId) => _api.qualities(songId);

  @override
  Future<SongUrl?> songUrl(String songId, AudioQuality quality) => _api.songUrl(songId, quality);

  @override
  Future<Lyrics> lyrics(Song song, LyricSource source, {required bool fallback}) =>
      _lyrics.fetch(song, source, fallback: fallback);
}

enum Repeat { list, one }

/// 播放器状态：队列、进度、音质、歌词。
///
/// 每次切歌递增 [_token]；异步结果回来时 token 已变说明用户又切了歌，直接丢弃。
class PlayerController extends ChangeNotifier {
  PlayerController({required this._engine, required this._backend, required this._settings}) {
    _subs = [
      _engine.completed.listen((_) => _onCompleted()),
      _engine.errors.listen((e) => _fail('播放出错：$e')),
    ];
  }

  static const _tick = Duration(milliseconds: 50);

  final AudioEngine _engine;
  final PlaybackBackend _backend;
  final AppSettings _settings;
  late final List<StreamSubscription<Object?>> _subs;
  final _notices = StreamController<String>.broadcast();
  final _random = Random();

  List<Song> _queue = const [];
  String _queueTitle = '';
  int _index = -1;
  int _token = 0;

  Duration _position = Duration.zero;
  bool _playing = false;
  bool _loading = false;

  /// 加载完成后是否自动播放。
  bool _wantPlay = false;
  Duration _lyricOffset = Duration.zero;
  double _volume = 1;
  bool _shuffle = false;
  Repeat _repeat = Repeat.list;
  final List<int> _history = [];
  int _failStreak = 0;

  List<QualityInfo> _qualities = const [];
  AudioQuality? _quality;
  ({Duration start, Duration end})? _trial;

  Lyrics _lyrics = Lyrics.empty;
  bool _lyricsLoading = false;
  List<Color>? _coverPalette;

  Timer? _timer;

  /// 给用户看的提示（切歌失败、试听、音质降级等），由界面弹 SnackBar。
  Stream<String> get notices => _notices.stream;

  Song? get current => _index >= 0 && _index < _queue.length ? _queue[_index] : null;

  /// 当前歌曲。只在确定有歌时使用（播放页、播放条）。
  Song get song => current!;
  List<Song> get queue => _queue;
  int get index => _index;

  /// 队列来源，例如歌单名、"搜索：xxx"。
  String get queueTitle => _queueTitle;
  Duration get position => _position;

  /// 正在播放，或正在加载且加载完会自动播放。用于播放 / 暂停按钮。
  bool get isPlaying => _playing || (_loading && _wantPlay);

  /// 正在取播放地址或缓冲。
  bool get isLoading => _loading;
  double get volume => _volume;
  bool get shuffle => _shuffle;
  Repeat get repeat => _repeat;

  /// 这首歌提供的音质（从低到高）。取不到时为空。
  List<QualityInfo> get qualities => _qualities;

  /// 实际在放的音质。
  AudioQuality? get quality => _quality;

  /// 非 null 表示只拿到了试听片段。
  ({Duration start, Duration end})? get trial => _trial;

  /// 当前封面的主色（从图片里取，取到之前用占位色）。
  List<Color> get palette => _coverPalette ?? current?.palette ?? const [Color(0xFF333333)];

  Lyrics get lyrics => _lyrics;
  bool get lyricsLoading => _lyricsLoading;

  /// 歌词时间轴偏移。正值表示歌词提前。
  Duration get lyricOffset => _lyricOffset;

  /// 进度条用的总时长：试听时是片段长度。
  Duration get duration {
    if (_trial case final t?) return t.end - t.start;
    final d = current?.duration ?? Duration.zero;
    return d > Duration.zero ? d : (_engine.duration ?? Duration.zero);
  }

  double get progress {
    final total = duration.inMicroseconds;
    return total == 0 ? 0 : (_position.inMicroseconds / total).clamp(0.0, 1.0);
  }

  /// 用于歌词对齐的时间点：叠加偏移；试听片段换算回整首歌的时间。
  Duration get lyricPosition => _position + (_trial?.start ?? Duration.zero) + _lyricOffset;

  /// 当前所在歌词行；还没到第一行时返回 -1。
  int get activeLyricIndex {
    final lines = _lyrics.lines;
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

  // ---------------------------------------------------------------- 队列

  /// 替换队列并从 [start] 开始播放。
  Future<void> playQueue(List<Song> songs, {int start = 0, String title = ''}) {
    if (songs.isEmpty) return Future.value();
    _queue = List.unmodifiable(songs);
    _queueTitle = title;
    _history.clear();
    _failStreak = 0;
    return _load(start.clamp(0, songs.length - 1));
  }

  /// 跳到队列里的第 [i] 首。
  Future<void> jumpTo(int i) {
    if (i < 0 || i >= _queue.length) return Future.value();
    _history.add(_index);
    return _load(i);
  }

  Future<void> next() => _advance(auto: false);

  Future<void> previous() {
    // 和多数播放器一致：播放超过 3 秒时"上一首"先回到开头。
    if (_position > const Duration(seconds: 3) || _queue.length <= 1) return seek(Duration.zero);
    if (_shuffle && _history.isNotEmpty) return _load(_history.removeLast());
    return _load((_index - 1 + _queue.length) % _queue.length);
  }

  void toggleShuffle() {
    _shuffle = !_shuffle;
    _history.clear();
    notifyListeners();
  }

  void toggleRepeat() {
    _repeat = _repeat == Repeat.list ? Repeat.one : Repeat.list;
    notifyListeners();
  }

  Future<void> _advance({required bool auto}) {
    if (_queue.isEmpty) return Future.value();
    if (auto && _repeat == Repeat.one) {
      return seek(Duration.zero).then((_) => play());
    }
    _history.add(_index);
    if (_shuffle && _queue.length > 1) {
      var i = _index;
      while (i == _index) {
        i = _random.nextInt(_queue.length);
      }
      return _load(i);
    }
    return _load((_index + 1) % _queue.length);
  }

  void _onCompleted() {
    if (!_playing) return;
    _advance(auto: true);
  }

  // ---------------------------------------------------------------- 加载

  Future<void> _load(
    int index, {
    Duration startAt = Duration.zero,
    bool? autoplay,
    bool keepLyrics = false,
  }) async {
    final token = ++_token;
    _wantPlay = autoplay ?? true;
    final changingSong = index != _index;
    _index = index;
    final song = this.song;
    _position = startAt;
    _loading = true;
    _stopTicker();
    if (changingSong) {
      _qualities = const [];
      _quality = null;
      _trial = null;
      _lyricOffset = Duration.zero;
      _coverPalette = null;
      if (song.coverUrl case final url?) {
        unawaited(
          CoverPalette.of(url).then((p) {
            if (p != null && p.isNotEmpty && current?.id == song.id) {
              _coverPalette = p;
              notifyListeners();
            }
          }),
        );
      }
    }
    if (!keepLyrics) {
      _lyrics = Lyrics.empty;
      unawaited(_loadLyrics(song, _settings.lyricSource, fallback: true));
    }
    _playing = false;
    notifyListeners();
    unawaited(_engine.pause());

    try {
      if (changingSong || _qualities.isEmpty) {
        try {
          _qualities = await _backend.qualities(song.id);
        } on ApiException {
          _qualities = const []; // 取不到就直接按偏好请求，由服务端降级。
        }
        if (token != _token) return;
      }
      final preferred = _settings.preferredQuality;
      final target = AudioQuality.pick(_qualities.map((q) => q.quality), preferred) ?? preferred;
      final url = await _backend.songUrl(song.id, target);
      if (token != _token) return;
      if (url == null) {
        _loading = false;
        _playing = false;
        notifyListeners();
        _notices.add('「${song.title}」暂无版权或需要会员');
        _failStreak++;
        if (_wantPlay && _failStreak < _queue.length) unawaited(_advance(auto: false));
        return;
      }
      _quality = url.quality ?? target;
      _trial = url.trial;
      if (url.trial != null) {
        _notices.add('「${song.title}」只能试听片段，登录会员账号后可完整播放');
      } else if (_quality != null && _quality!.index < target.index) {
        _notices.add('当前账号最高可用 ${_quality!.label}');
      }
      await _engine.load(url.url, start: startAt);
      if (token != _token) return;
      _failStreak = 0;
      _loading = false;
      if (_wantPlay) {
        await _startPlayback();
      } else {
        notifyListeners();
      }
    } catch (e) {
      if (token != _token) return;
      _fail(e is ApiException ? e.message : '播放失败：$e');
    }
  }

  Future<void> _loadLyrics(Song song, LyricSource source, {required bool fallback}) async {
    _lyricsLoading = true;
    try {
      final l = await _backend.lyrics(song, source, fallback: fallback);
      if (current?.id != song.id) return;
      if (l.isEmpty && !fallback) {
        _notices.add('${source.label}没有这首歌的歌词');
        return;
      }
      _lyrics = l;
    } catch (_) {
      if (current?.id != song.id) return;
      if (!fallback) _notices.add('${source.label}歌词获取失败');
    } finally {
      if (current?.id == song.id) {
        _lyricsLoading = false;
        notifyListeners();
      }
    }
  }

  void _fail(String message) {
    _loading = false;
    _playing = false;
    _stopTicker();
    notifyListeners();
    _notices.add(message);
  }

  // ---------------------------------------------------------------- 控制

  Future<void> play() async {
    if (current == null || _playing) return;
    if (_loading) {
      // 加载完成后自动开始。
      _wantPlay = true;
      notifyListeners();
      return;
    }
    await _startPlayback();
  }

  Future<void> _startPlayback() async {
    _playing = true;
    await _engine.play();
    _startTicker();
    notifyListeners();
  }

  Future<void> pause() async {
    if (_loading) {
      _wantPlay = false;
      notifyListeners();
      return;
    }
    if (!_playing) return;
    _playing = false;
    _stopTicker();
    _position = _engine.position;
    await _engine.pause();
    notifyListeners();
  }

  Future<void> toggle() => isPlaying ? pause() : play();

  Future<void> seek(Duration to) async {
    _position = Duration(microseconds: to.inMicroseconds.clamp(0, duration.inMicroseconds));
    notifyListeners();
    await _engine.seek(_position);
  }

  Future<void> seekBy(Duration delta) => seek(_position + delta);

  /// 切换音质并设为默认。保持进度和播放状态。
  Future<void> setQuality(AudioQuality q) {
    _settings.preferredQuality = q;
    if (current == null || q == _quality) return Future.value();
    return _load(_index, startAt: _position, autoplay: isPlaying, keepLyrics: true);
  }

  /// 换一个歌词来源（只查这一个来源）。没有歌词时保留当前歌词并提示。
  Future<void> setLyricSource(LyricSource source) async {
    final s = current;
    if (s == null || source == _lyrics.source) return;
    await _loadLyrics(s, source, fallback: false);
  }

  void setVolume(double v) {
    _volume = v.clamp(0.0, 1.0);
    _engine.setVolume(_volume);
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

  void _startTicker() {
    _timer ??= Timer.periodic(_tick, (_) {
      _position = _engine.position;
      notifyListeners();
    });
  }

  void _stopTicker() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stopTicker();
    for (final s in _subs) {
      s.cancel();
    }
    _notices.close();
    _engine.dispose();
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
