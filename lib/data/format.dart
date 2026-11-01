/// 播放量：`9876` → `9876`，`18000` → `1.8万`，`230000000` → `2.3亿`。
String formatPlayCount(int count) {
  if (count < 10000) return '$count';
  if (count < 100000000) return '${(count / 10000).toStringAsFixed(1)}万';
  return '${(count / 100000000).toStringAsFixed(1)}亿';
}

/// `mm:ss`，超过一小时为 `h:mm:ss`。负数按 0 处理。
String formatDuration(Duration d) {
  if (d.isNegative) d = Duration.zero;
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

/// 按小时给出问候语。
String greetingFor(DateTime time) {
  final h = time.hour;
  if (h < 5) return '夜深了';
  if (h < 11) return '上午好';
  if (h < 13) return '中午好';
  if (h < 18) return '下午好';
  return '晚上好';
}
