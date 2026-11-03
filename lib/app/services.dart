import 'dart:async';

import 'package:flutter/painting.dart';

import '../api/cookies.dart';
import '../api/netease_api.dart';
import '../audio/audio_engine.dart';
import '../audio/system_media.dart';
import '../data/track_cache.dart';
import '../lyrics/lyric_service.dart';
import '../lyrics/qq_lyrics.dart';
import '../state/account_controller.dart';
import '../state/player_controller.dart';
import '../state/settings.dart';
import '../widgets/image_disk_cache.dart';

/// 应用级的单例集合，在 main 里建好后整个往下传。
class AppServices {
  AppServices({
    required this.settings,
    required this.api,
    required this.account,
    required this.player,
    PlaylistTracks? tracks,
  }) : tracks = tracks ?? PlaylistTracks(api);

  /// 正式环境：真实网络 + just_audio。
  static Future<AppServices> create() async {
    // 内存里多留些解码好的图（默认 100MB 只够二三十张大封面），切页面回来不用重新解码。
    PaintingBinding.instance.imageCache
      ..maximumSize = 2000
      ..maximumSizeBytes = 256 << 20;
    unawaited(ImageDiskCache.prune());
    final settings = await AppSettings.load();
    final api = NeteaseApi(cookies: parseCookie(settings.cookie));
    final lyrics = LyricService(netease: api, qq: QqLyrics());
    await JustAudioEngine.configureSession();
    final player = PlayerController(
      engine: JustAudioEngine(),
      backend: NeteaseBackend(api, lyrics),
      settings: settings,
    );
    final account = AccountController(api: api, settings: settings);
    // 注册系统媒体会话（Android 前台服务 + 通知、iOS 锁屏），保证后台持续播放。
    await SystemMediaBridge.register(player, account);
    return AppServices(
      settings: settings,
      api: api,
      account: account,
      player: player,
      tracks: PlaylistTracks(api, store: FileTrackStore()),
    );
  }

  final AppSettings settings;
  final NeteaseApi api;
  final AccountController account;
  final PlayerController player;

  /// 歌单歌曲（带本地缓存）。
  final PlaylistTracks tracks;

  void dispose() {
    player.dispose();
    account.dispose();
    api.close();
  }
}
