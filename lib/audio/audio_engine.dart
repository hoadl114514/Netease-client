import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

/// 播放器内核。抽出接口是为了测试里换成假的实现。
abstract class AudioEngine {
  /// 加载地址并停在 [start]，不自动播放。
  Future<void> load(String url, {Duration start = Duration.zero});
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setVolume(double volume);

  /// 当前位置。播放中会按时间外推，可以高频读取。
  Duration get position;

  /// 当前音频的时长；未知时为 null。
  Duration? get duration;

  /// 播放到结尾。
  Stream<void> get completed;

  /// 播放过程中出错（解码失败、网络中断等）。
  Stream<Object> get errors;

  Future<void> dispose();
}

class JustAudioEngine implements AudioEngine {
  JustAudioEngine() {
    _sub = _player.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed) _completed.add(null);
    }, onError: (Object e, StackTrace _) => _errors.add(e));
  }

  /// 声明为音乐播放，交给系统处理来电、其他应用抢占等打断。
  static Future<void> configureSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  }

  final _player = AudioPlayer();
  final _completed = StreamController<void>.broadcast();
  final _errors = StreamController<Object>.broadcast();
  late final StreamSubscription<PlayerState> _sub;

  @override
  Future<void> load(String url, {Duration start = Duration.zero}) async {
    await _player.setAudioSource(
      AudioSource.uri(Uri.parse(url), headers: const {'Referer': 'https://music.163.com/'}),
      initialPosition: start,
    );
  }

  /// just_audio 的 play() 要等到暂停或播完才返回，这里不等它。
  @override
  Future<void> play() async => unawaited(_player.play().catchError((Object e) => _errors.add(e)));

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Duration get position => _player.position;

  @override
  Duration? get duration => _player.duration;

  @override
  Stream<void> get completed => _completed.stream;

  @override
  Stream<Object> get errors => _errors.stream;

  @override
  Future<void> dispose() async {
    await _sub.cancel();
    await _player.dispose();
    await _completed.close();
    await _errors.close();
  }
}
