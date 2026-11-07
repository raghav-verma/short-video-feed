import 'dart:async';
import 'dart:io' show ProcessInfo;

import 'package:flutter/material.dart';

import '../playback/diagnostics.dart';
import '../playback/playback_metrics.dart';
import '../playback/video_controller_pool.dart';

/// Debug overlay: live players in the pool, start-up timings, process memory
/// and (on Android) data received since the overlay opened. Toggled from the
/// feed's app bar.
class PlaybackHud extends StatefulWidget {
  const PlaybackHud({super.key, required this.pool, required this.metrics});

  final VideoControllerPool pool;
  final PlaybackMetrics metrics;

  @override
  State<PlaybackHud> createState() => _PlaybackHudState();
}

class _PlaybackHudState extends State<PlaybackHud> {
  Timer? _timer;
  int _rssBytes = 0;
  int? _rxBaseline;
  int? _rxBytes;

  @override
  void initState() {
    super.initState();
    unawaited(_sample());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => unawaited(_sample()));
  }

  Future<void> _sample() async {
    final rx = await Diagnostics.uidRxBytes();
    if (!mounted) return;
    setState(() {
      _rssBytes = ProcessInfo.currentRss;
      _rxBaseline ??= rx;
      _rxBytes = rx;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: Colors.white,
      fontSize: 11,
      height: 1.35,
      fontFamily: 'monospace',
      fontFeatures: [FontFeature.tabularFigures()],
    );
    return IgnorePointer(
      child: Directionality(
        // Diagnostic text, always LTR.
        textDirection: TextDirection.ltr,
        child: ListenableBuilder(
          listenable: Listenable.merge([widget.pool, widget.metrics]),
          builder: (context, _) {
            final pool = widget.pool;
            final m = widget.metrics;
            final last = m.lastStartup;
            final lines = <String>[
              'radius ${pool.preloadRadius} · players ${pool.liveControllerCount}'
                  ' · RSS ${(_rssBytes / (1024 * 1024)).toStringAsFixed(0)} MB',
              for (final slot in pool.slotsInFeedOrder) _describe(pool, slot),
              'last start  ${last == null ? '-' : '${last.timeToFirstFrame.inMilliseconds} ms'
                        '${last.wasPreloaded ? ' (preloaded)' : ' (cold)'}'}',
              'preloaded   ${m.preloadedStats}',
              'cold        ${m.coldStats}',
              'initialize  ${m.initStats}',
              if (_rxBytes != null && _rxBaseline != null)
                'received    ${((_rxBytes! - _rxBaseline!) / (1024 * 1024)).toStringAsFixed(1)} MB'
                    ' since this overlay opened',
            ];
            return DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(lines.join('\n'), style: style),
              ),
            );
          },
        ),
      ),
    );
  }

  static String _describe(VideoControllerPool pool, PlayerSlot slot) {
    final offset = pool.offsetFromActive(slot.post.id) ?? 0;
    final where = offset == 0 ? '  0' : (offset > 0 ? ' +$offset' : ' $offset');
    final value = slot.controller.value;
    final state = switch (slot.status) {
      SlotStatus.initializing => 'initializing',
      SlotStatus.failed => 'failed',
      SlotStatus.ready when value.isPlaying && value.isBuffering => 'buffering',
      SlotStatus.ready when value.isPlaying => 'playing',
      SlotStatus.ready => 'ready',
    };
    final id = slot.post.id.split('-').last;
    return '[$where] ${id.padRight(12)} $state';
  }
}
