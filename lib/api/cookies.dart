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

/// 解析响应头里的 `Set-Cookie`，只取每条的 `名=值`，忽略 Path、Expires 等属性。
///
/// `package:http` 会把多条 `Set-Cookie` 用逗号拼成一个字符串，而 `Expires` 的值里本身也有逗号
/// （`Wed, 29 Oct 2036 …`），所以只在「逗号后面紧跟 `名=`」的位置切分。
/// 值为空或为 `deleted` 的（服务端在清除 Cookie）会被丢弃。
Map<String, String> parseSetCookie(String? header) {
  final result = <String, String>{};
  if (header == null || header.isEmpty) return result;
  for (final entry in header.split(RegExp(r',\s*(?=[^;,=\s]+=)'))) {
    final pair = entry.split(';').first;
    final i = pair.indexOf('=');
    if (i <= 0) continue;
    final key = pair.substring(0, i).trim();
    final value = pair.substring(i + 1).trim();
    if (key.isEmpty || value.isEmpty || value == 'deleted') continue;
    result[key] = value;
  }
  return result;
}
