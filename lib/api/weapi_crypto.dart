import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// 网页端 WEAPI 加密：JSON 先用固定密钥、再用随机 16 位密钥各做一次 AES-128-CBC（Base64），
/// 随机密钥倒序后做无填充 RSA 得到 `encSecKey`。关注之类的接口走明文 / EAPI 会被风控，网页端不会。
abstract final class WeapiCrypto {
  static const _presetKey = '0CoJUm6Qyw8W8jud';
  static const _iv = '0102030405060708';
  static const _chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  static final _modulus = BigInt.parse(
    'e0b509f6259df8642dbc35662901477df22677ec152b5ff68ace615bb7b725152b3ab17a876aea8a5aa76d2e41'
    '7629ec4ee341f56135fccf695280104e0312ecbda92557c93870114af6c9d05c4f7f0c3685b7a46bee255932575c'
    'ce10b424d813cfe4875d3e82047b97ddef52741d546b8e289dc6935b3ece0462db0a22b8e7',
    radix: 16,
  );
  static final _exponent = BigInt.from(0x10001);

  /// 返回表单字段 `params` 和 `encSecKey`。[secretKey] 只在测试里指定。
  static Map<String, String> encrypt(String json, {Random? random, String? secretKey}) {
    final r = random ?? Random.secure();
    final key = secretKey ?? List.generate(16, (_) => _chars[r.nextInt(_chars.length)]).join();
    final params = _aes(_aes(json, _presetKey), key);
    final reversed = key.split('').reversed.join();
    final m = BigInt.parse(_hex(utf8.encode(reversed)), radix: 16);
    final encSecKey = m.modPow(_exponent, _modulus).toRadixString(16).padLeft(256, '0');
    return {'params': params, 'encSecKey': encSecKey};
  }

  static String _aes(String text, String key) {
    final cipher = PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()))
      ..init(
        true,
        PaddedBlockCipherParameters(
          ParametersWithIV(
            KeyParameter(Uint8List.fromList(utf8.encode(key))),
            Uint8List.fromList(utf8.encode(_iv)),
          ),
          null,
        ),
      );
    return base64Encode(cipher.process(Uint8List.fromList(utf8.encode(text))));
  }

  static String _hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
