import 'package:flutter/widgets.dart';

import '../api/cookies.dart';
import '../api/netease_api.dart';
import '../data/models.dart';
import 'settings.dart';

/// 登录状态（只支持 Cookie 登录）、我的歌单和"喜欢"列表。
class AccountController extends ChangeNotifier {
  AccountController({required this._api, required this._settings});

  final NeteaseApi _api;
  final AppSettings _settings;

  UserProfile? _profile;
  List<Playlist> _playlists = const [];
  Set<String> _liked = {};
  bool _busy = false;

  UserProfile? get profile => _profile;
  bool get isLoggedIn => _profile != null;
  bool get busy => _busy;
  List<Playlist> get playlists => _playlists;

  /// 「我喜欢的音乐」歌单。
  Playlist? get likedPlaylist {
    for (final p in _playlists) {
      if (p.isLikedList) return p;
    }
    return null;
  }

  bool isLiked(String songId) => _liked.contains(songId);

  /// 启动时用保存的 Cookie 恢复登录。网络失败时保留 Cookie，下次再试。
  Future<void> restore() async {
    final saved = parseCookie(_settings.cookie);
    if (!saved.containsKey('MUSIC_U')) return;
    _api.cookies = saved;
    try {
      await _refresh();
    } catch (_) {
      // 离线等情况：不清 Cookie，界面显示未登录。
    }
  }

  /// 用一段 Cookie 文本登录，成功返回账号，失败抛 [ApiException]。
  Future<UserProfile> login(String cookieText) async {
    final cookies = parseCookie(cookieText);
    if (!cookies.containsKey('MUSIC_U')) {
      throw const ApiException('Cookie 里没有 MUSIC_U，请确认复制完整');
    }
    final previous = _api.cookies;
    _api.cookies = cookies;
    _setBusy(true);
    try {
      final profile = await _api.account();
      if (profile == null) throw const ApiException('Cookie 无效或已过期');
      _settings.cookie = encodeCookie(cookies);
      await _refresh(profile: profile);
      return profile;
    } catch (e) {
      _api.cookies = previous;
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  void logout() {
    _api.cookies = const {};
    _settings.cookie = '';
    _profile = null;
    _playlists = const [];
    _liked = {};
    notifyListeners();
  }

  /// 重新拉取歌单和喜欢列表。
  Future<void> refresh() => _refresh();

  Future<void> _refresh({UserProfile? profile}) async {
    final p = profile ?? await _api.account();
    _profile = p;
    if (p == null) {
      _playlists = const [];
      _liked = {};
      notifyListeners();
      return;
    }
    notifyListeners();
    // 喜欢列表取不到不影响歌单显示，红心按未喜欢处理。
    final liked = _api.likedSongIds(p.userId).catchError((Object _) => <String>{});
    _playlists = await _api.userPlaylists(p.userId);
    _liked = await liked;
    notifyListeners();
  }

  /// 切换喜欢。先改界面，接口失败再改回来并抛出错误。
  Future<void> toggleLike(String songId) async {
    if (!isLoggedIn) throw const ApiException('登录后才能收藏歌曲', code: 301);
    final liked = !_liked.contains(songId);
    liked ? _liked.add(songId) : _liked.remove(songId);
    notifyListeners();
    try {
      await _api.setLiked(songId, liked);
    } catch (_) {
      liked ? _liked.remove(songId) : _liked.add(songId);
      notifyListeners();
      rethrow;
    }
  }

  void _setBusy(bool v) {
    _busy = v;
    notifyListeners();
  }
}

class AccountScope extends InheritedNotifier<AccountController> {
  const AccountScope({super.key, required AccountController controller, required super.child})
    : super(notifier: controller);

  static AccountController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AccountScope>()!.notifier!;

  static AccountController read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AccountScope>()!.notifier!;
}
