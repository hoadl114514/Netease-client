import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:netease_client/api/weapi_crypto.dart';
import 'package:pointycastle/export.dart';

String _decrypt(String b64, String key) {
  final cipher = PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()))
    ..init(
      false,
      PaddedBlockCipherParameters(
        ParametersWithIV(
          KeyParameter(Uint8List.fromList(utf8.encode(key))),
          Uint8List.fromList(utf8.encode('0102030405060708')),
        ),
        null,
      ),
    );
  return utf8.decode(cipher.process(base64Decode(b64)));
}

void main() {
  test('params is the JSON encrypted twice and decrypts back', () {
    const key = 'abcdefghijklmnop';
    final out = WeapiCrypto.encrypt('{"a":1}', secretKey: key);
    final once = _decrypt(out['params']!, key);
    expect(_decrypt(once, '0CoJUm6Qyw8W8jud'), '{"a":1}');
  });

  test('encSecKey is the reversed key raised to e mod n, as 256 hex digits', () {
    // 期望值用 Python 的 pow(int(key[::-1].hex(), 16), 65537, n) 独立算出。
    final out = WeapiCrypto.encrypt('{}', secretKey: '0123456789abcdef');
    expect(
      out['encSecKey'],
      '35701388baf89fed412e11269b9c76625d095ecaf17f03fa018abe19ea2d38b949debf242ee39a71ca1f6cda71b1b86a'
      '45aa909ee27f7e78e267d34e732f0de948206c3340a788d0003372183e2f753c1f78b66ac23d134ac1fc9b993156520e'
      'a826b8aa89a962d4491b4b8d7e08738e1da9b07aa39bf4a7ef0b1c210728cd52',
    );
  });
}
