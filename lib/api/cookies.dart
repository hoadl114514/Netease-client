/// 把 `k1=v1; k2=v2` 形式（也接受换行分隔）的 Cookie 文本解析成键值对。
/// 空键、空值、没有 `=` 的片段会被丢弃；同名键后者覆盖前者。
Map<String, String> parseCookie(String text) {
  final result = <String, String>{};
  for (final part in text.split(RegExp(r'[;\n\r]'))) {
    final i = part.indexOf('=');
    if (i <= 0) continue;
    final key = part.substring(0, i).trim();
    final value = part.substring(i + 1).trim();
    if (key.isEmpty || value.isEmpty) continue;
    result[key] = value;
  }
  return result;
}

/// 拼回请求头里的 `Cookie` 字段。
String encodeCookie(Map<String, String> cookies) =>
    cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
