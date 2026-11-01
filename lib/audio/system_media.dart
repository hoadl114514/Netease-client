import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/services.dart';

import '../api/netease_api.dart';
import '../data/models.dart';
import '../state/player_controller.dart';

/// 把 [PlayerController] 注册成系统的媒体会话：
/// Android 上是前台服务 + 媒体通知（保证切到后台、锁屏后继续播放），
/// iOS 上是控制中心 / 锁屏的正在播放信息。
/// 通知栏、锁屏、耳机线控、蓝牙按键的操作都转发回 [PlayerController]。
///
/// 播放逻辑仍然只在 [PlayerController] 里，这里只做双向同步。
class SystemMediaBridge extends BaseAudioHandler with SeekHandler {
  SystemMediaBridge(this._player) {
    _player.addListener(_sync);
    _sync();
  }

  final PlayerController _player;

  /// 注册系统媒体服务。必须在 runApp 之前调用一次。
  static Future<SystemMediaBridge> register(PlayerController player) => AudioService.init(
    builder: () => SystemMediaBridge(player),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'io.github.hoadl114514.netease_client.playback',
      androidNotificationChannelName: '音乐播放',
      // 暂停时也保持前台服务：Android 12+ 不允许应用从后台重新拉起前台服务，
      // 否则暂停后用耳机 / 蓝牙恢复播放会失败。通知里有「停止」按钮可以关掉。
      androidStopForegroundOnPause: false,
    ),
  );

  static const _channel = MethodChannel('netease_client/system_media');

  /// Android 上通知是否开着。关着时媒体通知发不出来，控制中心 / 锁屏看不到播放卡片。
  /// 其他平台、或者原生端没有实现时视为开着。
  static Future<bool> notificationsEnabled() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('notificationsEnabled') ?? true;
    } on MissingPluginException {
      return true;
    } on PlatformException {
      return true;
    }
  }

  /// 打开本应用的系统通知设置。
  static Future<void> openNotificationSettings() async {
    try {
      await _channel.invokeMethod<void>('openNotificationSettings');
    } on MissingPluginException {
      // 非 Android。
    }
  }

  String? _songId;
  ({bool playing, bool loading, int index, AudioQuality? quality})? _last;
  Duration _lastPosition = Duration.zero;
  DateTime _lastUpdate = DateTime.now();

  /// 控制器每 50ms 通知一次，这里只在状态真正变化（播放 / 暂停、切歌、拖动进度）时推给系统；
  /// 正常播放时系统会按 updatePosition + updateTime 自己外推进度。
  void _sync() {
    final song = _player.current;
    if (song == null) return;
    if (song.id != _songId) {
      _songId = song.id;
      mediaItem.add(_item(song));
    }
    final state = (
      playing: _player.isPlaying,
      loading: _player.isLoading,
      index: _player.index,
      quality: _player.quality,
    );
    final now = DateTime.now();
    final expected = state.playing && _last?.playing == true
        ? _lastPosition + now.difference(_lastUpdate)
        : _lastPosition;
    final jumped = (_player.position - expected).abs() > const Duration(seconds: 1);
    if (state == _last && !jumped) return;
    // 试听片段的时长要等加载完才知道。
    if (_last?.loading == true && !state.loading) mediaItem.add(_item(song));
    _last = state;
    _lastPosition = _player.position;
    _lastUpdate = now;
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          state.playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const {MediaAction.seek, MediaAction.seekForward, MediaAction.seekBackward},
        androidCompactActionIndices: const [0, 1, 2],
        processingState: state.loading ? AudioProcessingState.loading : AudioProcessingState.ready,
        playing: state.playing,
        updatePosition: _player.position,
        updateTime: now,
        queueIndex: state.index,
      ),
    );
  }

  MediaItem _item(Song song) => MediaItem(
    id: song.id,
    title: song.title,
    artist: song.artist,
    album: song.album,
    duration: _player.current?.id == song.id ? _player.duration : song.duration,
    artUri: song.coverUrl == null ? null : Uri.parse(sizedImage(song.coverUrl!, 512)),
  );

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> skipToNext() => _player.next();

  @override
  Future<void> skipToPrevious() => _player.previous();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    await _player.pause();
    playbackState.add(
      playbackState.value.copyWith(processingState: AudioProcessingState.idle, playing: false),
    );
    _last = null;
    await super.stop();
  }
}
