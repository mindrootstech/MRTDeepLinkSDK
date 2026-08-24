import 'dart:async';

import 'package:flutter/services.dart';

/// Minimal Dart API — mirrors iOS `onLinkReceived` only.
class CliqIt {
  static const MethodChannel _methods = MethodChannel('cliqit');
  static const EventChannel _links = EventChannel('cliqit/onLinkReceived');

  static Stream<Map<String, dynamic>>? _linkStream;

  /// Subscribe before [configure].
  static Stream<Map<String, dynamic>> get onLinkReceived {
    return _linkStream ??= _links
        .receiveBroadcastStream()
        .map((event) => Map<String, dynamic>.from(event as Map));
  }

  static Future<void> configure({required String apiKey}) async {
    await _methods.invokeMethod('configure', {'apiKey': apiKey});
  }

  /// Optional — Scene hooks also forward URLs via the plugin.
  static Future<bool> handleUrl(String url) async {
    final result = await _methods.invokeMethod('handleUrl', {'url': url});
    if (result is Map && result['ok'] == true) return true;
    return false;
  }
}
