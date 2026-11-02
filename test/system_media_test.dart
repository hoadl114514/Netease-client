import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netease_client/api/netease_api.dart';
import 'package:netease_client/audio/system_media.dart';
import 'package:netease_client/state/account_controller.dart';
import 'package:netease_client/state/player_controller.dart';

import 'support/fakes.dart';

void main() {
  late FakeEngine engine;
  late PlayerController player;
  late SystemMediaBridge bridge;
  late AccountController account;
  final queue = [song('1'), song('2')];

  setUp(() async {
    engine = FakeEngine();
    player = PlayerController(
      engine: engine,
      backend: FakeBackend(),
      settings: await testSettings(),
    );
    account = AccountController(api: NeteaseApi(), settings: await testSettings());
    bridge = SystemMediaBridge(player, account);
  });
  tearDown(() => player.dispose());

  test('publishes the current song and play state to the system', () async {
    await player.playQueue(queue);
    expect(bridge.mediaItem.value?.id, '1');
    expect(bridge.mediaItem.value?.title, '歌曲1');
    expect(bridge.playbackState.value.playing, isTrue);
    expect(bridge.playbackState.value.processingState, AudioProcessingState.ready);
    expect(bridge.playbackState.value.controls, contains(MediaControl.pause));

    await player.pause();
    expect(bridge.playbackState.value.playing, isFalse);
    expect(bridge.playbackState.value.controls, contains(MediaControl.play));
  });

  test('seeks are pushed, ordinary progress ticks are not', () async {
    await player.playQueue(queue);
    await player.pause();
    final before = bridge.playbackState.value;
    await player.seek(const Duration(seconds: 90));
    expect(bridge.playbackState.value.updatePosition, const Duration(seconds: 90));
    expect(identical(before, bridge.playbackState.value), isFalse);

    final afterSeek = bridge.playbackState.value;
    player.adjustLyricOffset(const Duration(milliseconds: 500)); // 触发通知但状态没变。
    expect(identical(afterSeek, bridge.playbackState.value), isTrue);
  });

  test('notification / headset actions drive the player', () async {
    await player.playQueue(queue);
    await bridge.pause();
    expect(player.isPlaying, isFalse);
    await bridge.play();
    expect(player.isPlaying, isTrue);
    await bridge.skipToNext();
    expect(player.song.id, '2');
    expect(bridge.mediaItem.value?.id, '2');
    await bridge.seek(const Duration(seconds: 30));
    expect(player.position, const Duration(seconds: 30));
  });

  test('the notification shows a like button instead of stop', () async {
    await player.playQueue(queue);
    final controls = bridge.playbackState.value.controls;
    expect(controls, isNot(contains(MediaControl.stop)));
    final like = controls.last;
    expect(like.action, MediaAction.custom);
    expect(like.customAction?.name, SystemMediaBridge.likeAction);
    expect(like.label, '喜欢');
  });

  test('tapping like while logged out tells the user to log in', () async {
    await player.playQueue(queue);
    final notices = <String>[];
    final sub = player.notices.listen(notices.add);
    await bridge.customAction(SystemMediaBridge.likeAction);
    await pumpEventQueue();
    expect(notices, ['登录后才能收藏歌曲']);
    await sub.cancel();
  });
}
