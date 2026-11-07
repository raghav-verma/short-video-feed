import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// One measured start-up: from the page becoming active to the first moving
/// frame (the player reports `position > 0` while playing).
@immutable
class StartupSample {
  const StartupSample({
    required this.postId,
    required this.wasPreloaded,
    required this.timeToFirstFrame,
  });

  final String postId;

  /// The player had finished `initialize()` before the page became active.
  final bool wasPreloaded;
  final Duration timeToFirstFrame;
}

/// Summary statistics over a set of durations, in milliseconds.
@immutable
class DurationStats {
  const DurationStats({
    required this.count,
    required this.p50,
    required this.p90,
    required this.max,
  });

  factory DurationStats.of(Iterable<Duration> values) {
    final ms = values.map((d) => d.inMilliseconds).toList()..sort();
    if (ms.isEmpty) {
      return const DurationStats(count: 0, p50: 0, p90: 0, max: 0);
    }
    int pct(double p) => ms[math.min(ms.length - 1, (p * (ms.length - 1)).round())];
    return DurationStats(count: ms.length, p50: pct(0.5), p90: pct(0.9), max: ms.last);
  }

  final int count;
  final int p50;
  final int p90;
  final int max;

  Map<String, int> toJson() => {'count': count, 'p50_ms': p50, 'p90_ms': p90, 'max_ms': max};

  @override
  String toString() => count == 0 ? 'n=0' : 'n=$count p50=${p50}ms p90=${p90}ms max=${max}ms';
}

/// Collects start-up and initialisation timings from the controller pool.
///
/// The README numbers come from here, read by the profile-mode benchmark in
/// `integration_test/feed_benchmark_test.dart`.
class PlaybackMetrics extends ChangeNotifier {
  PlaybackMetrics({Stopwatch Function()? stopwatchFactory})
    : _newStopwatch = stopwatchFactory ?? Stopwatch.new;

  final Stopwatch Function() _newStopwatch;
  final Map<String, ({Stopwatch watch, bool preloaded})> _pending = {};
  final List<StartupSample> _startups = [];
  final List<Duration> _initDurations = [];
  int _initFailures = 0;
  int _livePlayers = 0;
  int _maxLivePlayers = 0;

  List<StartupSample> get startups => List.unmodifiable(_startups);
  List<Duration> get initDurations => List.unmodifiable(_initDurations);
  int get initFailures => _initFailures;
  int get livePlayers => _livePlayers;

  /// Most players alive at once: the pool's real memory footprint driver.
  int get maxLivePlayers => _maxLivePlayers;
  StartupSample? get lastStartup => _startups.isEmpty ? null : _startups.last;

  DurationStats get preloadedStats =>
      DurationStats.of(_startups.where((s) => s.wasPreloaded).map((s) => s.timeToFirstFrame));
  DurationStats get coldStats =>
      DurationStats.of(_startups.where((s) => !s.wasPreloaded).map((s) => s.timeToFirstFrame));
  DurationStats get allStats => DurationStats.of(_startups.map((s) => s.timeToFirstFrame));
  DurationStats get initStats => DurationStats.of(_initDurations);

  /// A page became active. Starts the clock unless one is already running.
  void activationStarted(String postId, {required bool preloaded}) {
    _pending[postId] = (watch: _newStopwatch()..start(), preloaded: preloaded);
  }

  /// The page stopped being active before it showed a frame.
  void activationAbandoned(String postId) => _pending.remove(postId);

  /// The active page showed its first moving frame.
  void firstFrame(String postId) {
    final pending = _pending.remove(postId);
    if (pending == null) return;
    _startups.add(
      StartupSample(
        postId: postId,
        wasPreloaded: pending.preloaded,
        timeToFirstFrame: pending.watch.elapsed,
      ),
    );
    notifyListeners();
  }

  void initialized(Duration took) {
    _initDurations.add(took);
    notifyListeners();
  }

  void initFailed() {
    _initFailures++;
    notifyListeners();
  }

  void livePlayersChanged(int count) {
    _livePlayers = count;
    if (count > _maxLivePlayers) _maxLivePlayers = count;
  }

  void reset() {
    _pending.clear();
    _startups.clear();
    _initDurations.clear();
    _initFailures = 0;
    _maxLivePlayers = _livePlayers;
    notifyListeners();
  }

  Map<String, Object> toJson() => {
    'startup_all': allStats.toJson(),
    'startup_preloaded': preloadedStats.toJson(),
    'startup_cold': coldStats.toJson(),
    'initialize': initStats.toJson(),
    'init_failures': _initFailures,
    'max_live_players': _maxLivePlayers,
  };
}
