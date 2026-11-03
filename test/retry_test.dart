import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:netease_client/data/retry.dart';
import 'package:netease_client/widgets/retry_image.dart';

/// 1×1 的 PNG。
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

void main() {
  group('withRetry', () {
    const fast = [Duration.zero, Duration.zero];

    test('retries until it succeeds', () async {
      var calls = 0;
      final v = await withRetry(() async {
        if (++calls < 3) throw Exception('flaky');
        return 'ok';
      }, delays: fast);
      expect(v, 'ok');
      expect(calls, 3);
    });

    test('gives up after the last delay and rethrows', () async {
      var calls = 0;
      await expectLater(
        withRetry<void>(() async {
          calls++;
          throw StateError('down');
        }, delays: fast),
        throwsStateError,
      );
      expect(calls, 3);
    });

    test('does not retry errors that retryIf rejects, and stops when asked', () async {
      var calls = 0;
      await expectLater(
        withRetry<void>(
          () async {
            calls++;
            throw ArgumentError('404');
          },
          delays: fast,
          retryIf: (e) => e is! ArgumentError,
        ),
        throwsArgumentError,
      );
      expect(calls, 1);

      calls = 0;
      await expectLater(
        withRetry<void>(
          () async {
            calls++;
            throw Exception('x');
          },
          delays: fast,
          shouldStop: () => true,
        ),
        throwsException,
      );
      expect(calls, 1);
    });
  });

  group('RetryNetworkImage', () {
    tearDown(() {
      RetryNetworkImage.clientFactory = null;
      RetryNetworkImage.retryDelays = defaultRetryDelays;
      PaintingBinding.instance.imageCache.clear();
    });

    Future<ui.Image> resolve(ImageProvider provider) {
      final done = Completer<ui.Image>();
      final stream = provider.resolve(ImageConfiguration.empty);
      stream.addListener(
        ImageStreamListener(
          (info, _) => done.complete(info.image),
          onError: (e, _) => done.completeError(e),
        ),
      );
      return done.future;
    }

    testWidgets('retries server errors and truncated bodies, then decodes', (tester) async {
      var calls = 0;
      RetryNetworkImage.retryDelays = const [Duration.zero, Duration.zero];
      RetryNetworkImage.clientFactory = () => MockClient((r) async {
        calls++;
        return switch (calls) {
          1 => http.Response('busy', 503),
          2 => http.Response.bytes(
            _png.sublist(0, 10),
            200,
            headers: {'content-length': '${_png.length}'},
          ),
          _ => http.Response.bytes(_png, 200),
        };
      });
      final image = await tester.runAsync(
        () => resolve(const RetryNetworkImage('https://a/1.png')),
      );
      expect(image!.width, 1);
      expect(calls, 3);
    });

    testWidgets('does not retry a 404', (tester) async {
      var calls = 0;
      RetryNetworkImage.retryDelays = const [Duration.zero, Duration.zero];
      RetryNetworkImage.clientFactory = () => MockClient((r) async {
        calls++;
        return http.Response('nope', 404);
      });
      await tester.runAsync(() async {
        await expectLater(
          resolve(const RetryNetworkImage('https://a/2.png')),
          throwsA(isA<ImageHttpException>()),
        );
      });
      expect(calls, 1);
    });
  });
}
