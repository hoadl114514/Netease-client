import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../app/app.dart';
import '../data/models.dart';

const _channel = MethodChannel('netease_client/share');

/// 歌曲的网页链接。
String songShareUrl(Song song) => 'https://music.163.com/#/song?id=${song.id}';

/// 用链接分享歌曲：Android 上弹系统分享面板，其他平台（或原生端不可用时）复制到剪贴板。
Future<void> shareSong(Song song) async {
  final url = songShareUrl(song);
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    try {
      await _channel.invokeMethod<void>('shareText', {
        'text': url,
        'subject': '${song.title} - ${song.artist}',
        'title': '分享歌曲',
      });
      return;
    } on MissingPluginException {
      // 落到复制链接。
    } on PlatformException {
      // 同上。
    }
  }
  await Clipboard.setData(ClipboardData(text: url));
  AppScope.toast('已复制歌曲链接');
}
