import 'package:flutter/material.dart';

/// 侧边栏的固定入口。
enum Destination {
  forYou('为我推荐', Icons.home_rounded),
  discover('发现音乐', Icons.library_music_rounded),
  roaming('私人漫游', Icons.radio_rounded),
  podcast('播客电台', Icons.podcasts_rounded),
  liked('我喜欢的音乐', Icons.favorite_rounded),
  collection('我的收藏', Icons.star_rounded),
  cloud('我的云盘', Icons.cloud_rounded),
  local('本地歌曲', Icons.folder_rounded),
  recent('最近播放', Icons.history_rounded);

  const Destination(this.label, this.icon);

  final String label;
  final IconData icon;

  static const primary = [forYou, discover, roaming, podcast];
  static const library = [liked, collection, cloud, local, recent];

  /// 窄屏底部导航只放这几个。
  static const mobile = [forYou, discover, liked, recent];
}
