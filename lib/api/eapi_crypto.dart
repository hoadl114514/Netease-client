import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

/// 网易云 EAPI 加解密：AES-128-ECB + PKCS7，密钥固定。
///
/// 请求体格式：`{path}-36cd479b6b5-{json}-36cd479b6b5-{md5("nobody{path}use{json}md5forencrypt")}`，
/// 加密后转成大写十六进制作为表单字段 `params`。`path` 是把 `/eapi/` 换成 `/api/` 之后的路径。
abstract final class EapiCrypto {
  static final _key = Uint8List.fromList(utf8.encode('e82ckenh8dichen8'));
  static const _sep = '-36cd479b6b5-';

  static String encrypt(String apiPath, String payloadJson) {
    final digest = md5.convert(utf8.encode('nobody${apiPath}use${payloadJson}md5forencrypt'));
    final plain = utf8.encode('$apiPath$_sep$payloadJson$_sep$digest');
    return _hex(_cipher(true).process(Uint8List.fromList(plain)));
  }

  /// 解密 `e_r: true` 的响应体。
  static String decrypt(Uint8List body) => utf8.decode(_cipher(false).process(body));

  static PaddedBlockCipherImpl _cipher(bool forEncryption) =>
      PaddedBlockCipherImpl(PKCS7Padding(), ECBBlockCipher(AESEngine()))
        ..init(forEncryption, PaddedBlockCipherParameters(KeyParameter(_key), null));

  static String _hex(Uint8List bytes) {
    final sb = StringBuffer();
    for (final b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString().toUpperCase();
  }
}
