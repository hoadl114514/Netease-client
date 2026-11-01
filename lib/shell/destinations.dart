import 'package:flutter/material.dart';

/// 应用内的固定入口。
enum Destination {
  forYou('为我推荐', '首页', Icons.home_rounded),
  discover('发现音乐', '发现', Icons.explore_rounded, ready: false),
  podcast('播客电台', '播客', Icons.podcasts_rounded, ready: false),
  liked('我喜欢的音乐', '我喜欢', Icons.favorite_rounded),
  recent('最近播放', '最近', Icons.history_rounded, ready: false),
  ranking('听歌排行', '排行', Icons.show_chart_rounded, ready: false),
  updates('我的动态', '动态', Icons.campaign_outlined, ready: false),
  settings('设置', '设置', Icons.settings_outlined);

  const Destination(this.label, this.shortLabel, this.icon, {this.ready = true});

  /// false 表示页面待开发。
  final bool ready;

  /// 页面标题。
  final String label;

  /// 底部导航用的短名。
  final String shortLabel;
  final IconData icon;

  /// 底部导航。
  static const tabs = [forYou, discover, podcast, liked];

  /// 抽屉侧栏里的菜单。
  static const drawer = [ranking, recent, updates, settings];
}
