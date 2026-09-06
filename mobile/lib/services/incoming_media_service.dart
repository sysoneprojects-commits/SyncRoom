import 'dart:async';
import 'package:flutter/services.dart';

class IncomingMediaService {
  IncomingMediaService._();
  static final instance = IncomingMediaService._();
  static const _channel = MethodChannel('syncroom/open_media');
  final _controller = StreamController<String>.broadcast();
  Stream<String> get media => _controller.stream;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'videoOpened' && call.arguments is String) {
        _controller.add(call.arguments as String);
      }
    });
    try {
      final initial = await _channel.invokeMethod<String>('getInitialVideo');
      if (initial != null && initial.isNotEmpty) _controller.add(initial);
    } catch (_) {
      // Non-Android platforms do not provide this channel.
    }
  }
}
