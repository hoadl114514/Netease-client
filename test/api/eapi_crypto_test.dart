import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:netease_client/api/eapi_crypto.dart';

Uint8List hex(String s) => Uint8List.fromList([
  for (var i = 0; i < s.length; i += 2) int.parse(s.substring(i, i + 2), radix: 16),
]);

void main() {
  // 期望值用 openssl enc -aes-128-ecb 和 md5sum 独立算出。
  test('encrypt matches an openssl-computed vector', () {
    expect(
      EapiCrypto.encrypt('/api/song/lyric/v1', '{"id":1,"header":"{}"}'),
      '04AE33D34A93FE3EC22DA8FA305D290AB337D0FE5F36D211DE0D338CC6AA89D0D3176FE50ABE9F1D59C2CD7291C608D1'
      'C3C709DCDD84AD57A1E7575F05E23FEED3C400A8D133A7FD1D0762A09B1E126656BF2C01CA3766AB95FAC5134369ACA2'
      'F9FD8B70C204928796BE56E6D1ECF019',
    );
  });

  test('decrypt handles UTF-8 and PKCS7 padding', () {
    expect(
      EapiCrypto.decrypt(hex('fbe9396a97d9f21d1ab440de4ba21d96310c5dbc87df48280cdc17bb501d16d2')),
      '{"code":200,"x":"中"}',
    );
  });
}
