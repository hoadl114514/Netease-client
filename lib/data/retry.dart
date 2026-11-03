import 'dart:async';

/// 失败后按 [delays] 依次等待再重试，重试次数就是 [delays] 的长度。
///
/// [retryIf] 返回 false 的错误直接抛出（例如 404、无版权这类重试也没用的）。
/// [shouldStop] 在每次等待之后检查，返回 true 时放弃并抛出最后一次的错误（例如用户已经切歌）。
Future<T> withRetry<T>(
  Future<T> Function() task, {
  List<Duration> delays = defaultRetryDelays,
  bool Function(Object error)? retryIf,
  bool Function()? shouldStop,
}) async {
  for (var attempt = 0; ; attempt++) {
    try {
      return await task();
    } catch (e) {
      if (attempt >= delays.length || !(retryIf?.call(e) ?? true)) rethrow;
      await Future<void>.delayed(delays[attempt]);
      if (shouldStop?.call() ?? false) rethrow;
    }
  }
}

/// 默认重试两次：0.8 秒、2 秒后。
const defaultRetryDelays = [Duration(milliseconds: 800), Duration(seconds: 2)];
