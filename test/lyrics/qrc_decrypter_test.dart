import 'package:flutter_test/flutter_test.dart';
import 'package:netease_client/lyrics/qrc_decrypter.dart';

// 两组密文均由上游 C# DESHelper 独立编译后加密生成（来自作者此前的 Python 插件测试）。
const _encrypted =
    'bc8d35f203db1e28f887ef48290ac2b8de6aa9f06944e7140c89d5dfd2b08b838'
    '79d9519fd5d6870fb03375cce457b8bcb80dd584150d828bef246048cbbf326591'
    '500c679855739861a99ec3b2e9403ff8c0da56dc5009909f405efce9f96f1df71dcb7f4f885af';
const _decrypted =
    '<?xml version="1.0"?><QrcInfos><Lyric_1 '
    'LyricContent="[1000,2000]你(1000,400)好(1400,600)"/></QrcInfos>';

const _nonStandard =
    'bc8d35f203db1e28f887ef48290ac2b8de6aa9f06944e714eeacc7867349bfd86af2e099ad96a3a039ead6370604fbf6'
    '287b9845e0c4d11437446a119079e6c9ca95dfa0eff85b7ba5e03bf08c09f21bad49b5b1eda9cbfb6bb3cdb9bb7a665e'
    '784d4c8a62b0b4eb8893d577cefca37a500c4c8ace2d4d0d743c67c1c14838d2a855b05e4d8e44d9234f6284f01af225'
    'e057841aa4b1a851';

void main() {
  test('decrypts reference ciphertext (QQ DES + zlib + BOM)', () {
    expect(decryptQrc(_encrypted), _decrypted);
  });

  test('decrypts multi-line payload with raw quotes', () {
    final xml = decryptQrc(_nonStandard);
    expect(xml, contains('[1000,1000]Say "A & B < C"(1000,1000)\n[3000,1000]Next(3000,1000)'));
  });

  test('rejects malformed ciphertext', () {
    for (final v in ['', '00', 'this is not hex!', '00' * 8]) {
      expect(() => decryptQrc(v), throwsFormatException, reason: v);
    }
  });
}
