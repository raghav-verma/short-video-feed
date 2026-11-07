// Profile-mode benchmark for the controller pool. Runs the real app against
// the real streams on a device, swipes through the feed and reports start-up
// latency, initialisation time and memory. See tool/benchmark.sh.
import 'dart:io' show Platform, ProcessInfo;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:short_video_feed/app/app.dart';
import 'package:short_video_feed/app/app_config.dart';
import 'package:short_video_feed/feed/playback/diagnostics.dart';
import 'package:short_video_feed/feed/playback/playback_providers.dart';

const int swipes = int.fromEnvironment('BENCH_SWIPES', defaultValue: 20);
const int dwellMs = int.fromEnvironment('BENCH_DWELL_MS', defaultValue: 4000);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Let the engine draw frames on its own, as in the real app, rather than
  // only when the test pumps.
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('swipe through the feed', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const ShortVideoApp()),
    );
    final metrics = container.read(playbackMetricsProvider);

    // First video: includes app start-up and the first page fetch, so it is
    // reported but kept out of the swipe statistics.
    await _waitUntil(() => metrics.startups.isNotEmpty, const Duration(seconds: 30));
    final firstVideoMs = metrics.startups.first.timeToFirstFrame.inMilliseconds;
    await Future<void>.delayed(const Duration(milliseconds: dwellMs));
    metrics.reset();

    final rxBefore = await Diagnostics.uidRxBytes();
    final rssMb = <double>[_rssMb()];
    final pager = find.byKey(const Key('feed-pager'));
    for (var i = 0; i < swipes; i++) {
      await tester.fling(pager, const Offset(0, -600), 2500);
      await Future<void>.delayed(const Duration(milliseconds: dwellMs));
      rssMb.add(_rssMb());
    }
    final rxAfter = await Diagnostics.uidRxBytes();

    binding.reportData = {
      'preload_radius': AppConfig.preloadRadius,
      'swipes': swipes,
      'dwell_ms': dwellMs,
      'platform': Platform.operatingSystem,
      'os_version': Platform.operatingSystemVersion,
      'first_video_ms': firstVideoMs,
      // Bytes received during the swipes only (start-up excluded).
      if (rxBefore != null && rxAfter != null) 'received_mb': (rxAfter - rxBefore) / (1024 * 1024),
      ...metrics.toJson(),
      'startups': [
        for (final s in metrics.startups)
          {
            'id': s.postId.split('-').last,
            'preloaded': s.wasPreloaded,
            'ms': s.timeToFirstFrame.inMilliseconds,
          },
      ],
      'rss_mb': {
        'start': rssMb.first,
        'max': rssMb.reduce((a, b) => a > b ? a : b),
        'end': rssMb.last,
        'samples': rssMb,
      },
    };
  });
}

double _rssMb() => double.parse((ProcessInfo.currentRss / (1024 * 1024)).toStringAsFixed(1));

Future<void> _waitUntil(bool Function() condition, Duration timeout) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw StateError('Timed out after $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}
