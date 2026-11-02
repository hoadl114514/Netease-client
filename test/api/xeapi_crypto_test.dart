import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:netease_client/api/xeapi_crypto.dart';
import 'package:pointycastle/export.dart';

Uint8List _hex(String s) => Uint8List.fromList([
  for (var i = 0; i < s.length; i += 2) int.parse(s.substring(i, i + 2), radix: 16),
]);

String _toHex(List<int> b) => b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

void main() {
  test('X25519 matches the RFC 7748 test vectors', () {
    final alice = _hex('77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a');
    final bob = _hex('5dab087e624a8a4b79e17f8b83800ee66f3bb1292618b6fd1c2f8b27ff88e0eb');
    expect(
      _toHex(X25519.publicKey(alice)),
      '8520f0098930a754748b7ddcb43ef75a0dbf3a0d26381af4eba4a98eaa9b4e6a',
    );
    final bobPublic = X25519.publicKey(bob);
    expect(_toHex(bobPublic), 'de9edb7d7b7dc1b4d35b61c2ece435373f8343c85b78674dadfc7e146f882b4f');
    expect(
      _toHex(X25519.sharedSecret(alice, bobPublic)),
      '4a5d9d5ba4ce2de1728e3bf480350f25e07e21c947d19e3376f09b3c1e161742',
    );
  });

  test('request fields have the expected shape', () {
    final server = Uint8List.fromList(List.generate(32, (i) => i + 1));
    final key = XeapiPublicKey(
      publicKey: base64.encode(X25519.publicKey(server)),
      version: '7',
      sk: 'secret',
    );
    final f = XeapiCrypto.encrypt({'ids': '[1]', 'level': 'hires'}, key, random: Random(1));
    expect(f.keys, ['C', 'S', 'R']);
    expect(f['C'], isNot(contains('=')));
    // S = 临时公钥 32 + IV 12 + 密文 + 标签 16；服务端用私钥能解开。
    final s = base64.decode(f['S']!);
    final ephemeral = s.sublist(0, 32);
    final shared = X25519.sharedSecret(server, ephemeral);
    expect(shared.length, 32);
    expect(s.length, greaterThan(60));
  });

  test('responses are decrypted with the EAPI key', () {
    final cipher = PaddedBlockCipherImpl(PKCS7Padding(), ECBBlockCipher(AESEngine()))
      ..init(
        true,
        PaddedBlockCipherParameters(
          KeyParameter(Uint8List.fromList(utf8.encode('e82ckenh8dichen8'))),
          null,
        ),
      );
    final body = cipher.process(Uint8List.fromList(utf8.encode('{"code":200}')));
    expect(XeapiCrypto.decrypt(body), '{"code":200}');
  });
}
