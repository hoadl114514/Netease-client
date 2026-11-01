import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models.dart';

/// 本地设置，写入 SharedPreferences。
///
/// Cookie 也存在这里（明文，仅本机可读）。alpha 阶段够用，之后可以换成系统钥匙串。
class AppSettings extends ChangeNotifier {
  AppSettings(this._prefs);

  static Future<AppSettings> load() async => AppSettings(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  static const _kCookie = 'cookie';
  static const _kQuality = 'preferred_quality';
  static const _kLyricSource = 'lyric_source';
  static const _kTranslation = 'show_translation';
  static const _kRomaji = 'show_romaji';

  String get cookie => _prefs.getString(_kCookie) ?? '';
  set cookie(String v) => _set(() => _prefs.setString(_kCookie, v));

  /// 默认音质。歌曲没有这一档时自动降到它有的最高档。
  AudioQuality get preferredQuality =>
      AudioQuality.fromLevel(_prefs.getString(_kQuality)) ?? AudioQuality.exhigh;
  set preferredQuality(AudioQuality v) => _set(() => _prefs.setString(_kQuality, v.level));

  /// 默认歌词来源。取不到时自动换另一个来源。
  LyricSource get lyricSource =>
      LyricSource.byName(_prefs.getString(_kLyricSource)) ?? LyricSource.netease;
  set lyricSource(LyricSource v) => _set(() => _prefs.setString(_kLyricSource, v.name));

  bool get showTranslation => _prefs.getBool(_kTranslation) ?? true;
  set showTranslation(bool v) => _set(() => _prefs.setBool(_kTranslation, v));

  bool get showRomaji => _prefs.getBool(_kRomaji) ?? true;
  set showRomaji(bool v) => _set(() => _prefs.setBool(_kRomaji, v));

  /// SharedPreferences 的 set 会先更新内存缓存再异步落盘，所以读到的值立即是新的。
  void _set(Future<bool> Function() write) {
    write();
    notifyListeners();
  }
}
