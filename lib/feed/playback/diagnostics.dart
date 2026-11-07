import 'package:flutter/services.dart';

/// Platform diagnostics for the playback HUD and the benchmark.
abstract final class Diagnostics {
  static const MethodChannel _channel = MethodChannel('short_video_feed/diagnostics');

  /// Total bytes this app has received over the network since boot, from
  /// Android's `TrafficStats`. Null where unsupported (iOS, tests).
  static Future<int?> uidRxBytes() async {
    try {
      return await _channel.invokeMethod<int>('uidRxBytes');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
