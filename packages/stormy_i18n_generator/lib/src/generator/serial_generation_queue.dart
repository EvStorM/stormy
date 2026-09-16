import 'dart:async';

/// Coalesces edits while a generation is running and processes the latest edit
/// afterward. A failed run completes all callers with that error; the next
/// request may retry.
class SerialGenerationQueue {
  SerialGenerationQueue(this.generate);
  final Future<void> Function() generate;
  bool _dirty = false;
  Future<void>? _running;

  Future<void> request() {
    _dirty = true;
    return _running ??= Future<void>.microtask(_drain).whenComplete(() {
      _running = null;
    });
  }

  Future<void> _drain() async {
    Object? failure;
    StackTrace? stack;
    do {
      _dirty = false;
      try {
        await generate();
        failure = null;
      } catch (error, trace) {
        failure = error;
        stack = trace;
      }
    } while (_dirty);
    if (failure != null) Error.throwWithStackTrace(failure, stack!);
  }
}
