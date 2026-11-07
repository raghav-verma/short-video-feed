import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import '../domain/video_post.dart';
import 'playback_metrics.dart';

/// Creates the player for a post. Injected so tests can hand the pool mocks.
typedef VideoControllerFactory = VideoPlayerController Function(VideoPost post);

/// The production factory: a network player, with an explicit HLS hint so
/// Android's ExoPlayer builds an HLS media source without sniffing the URL.
VideoPlayerController networkVideoController(VideoPost post) => VideoPlayerController.networkUrl(
  post.videoUri,
  formatHint: post.format == StreamFormat.hls ? VideoFormat.hls : null,
);

enum SlotStatus { initializing, ready, failed }

/// A player owned by the pool, plus what the UI needs to know about it.
class PlayerSlot {
  PlayerSlot._(this.post, this.controller);

  final VideoPost post;
  final VideoPlayerController controller;

  SlotStatus _status = SlotStatus.initializing;
  Object? _error;
  bool _disposed = false;
  bool _showingVideo = false;
  VoidCallback? _listener;
  final Completer<void> _settled = Completer<void>();

  SlotStatus get status => _status;
  bool get isReady => _status == SlotStatus.ready;
  Object? get error => _error;

  /// True once the player has shown moving frames since this post last
  /// became active. Until then the UI keeps the first-frame poster on top.
  bool get showingVideo => _showingVideo;

  /// Completes when `initialize()` succeeds or fails, or when the slot is
  /// disposed first. Never hangs, unlike `initialize()` on a controller that
  /// was disposed mid-flight.
  Future<void> get settled => _settled.future;

  void _settle() {
    if (!_settled.isCompleted) _settled.complete();
  }
}

/// Keeps a small window of initialised players around the active page.
///
/// Rules:
///  * Window: the active post plus [preloadRadius] posts on each side.
///    Radius 1 means previous, current and next, so at most 3 players.
///  * Priority: the active post first, then next, previous, next + 1, and so
///    on. Initialisation is sequential, one player at a time, so the active
///    video never competes with its neighbours for bandwidth or a decoder.
///  * Eviction: any player outside the window is disposed straight away,
///    including one that is still initialising.
///  * Playback: only the active post plays, and only while [playbackAllowed]
///    is true (the route is on top and the app is in the foreground) and the
///    user has not paused it. A post that stops being active is paused and
///    rewound, so coming back shows the first frame again, matching the
///    poster.
///  * Players are keyed by post id, not index, so appending a page or
///    refreshing the feed never hands a player to the wrong post.
class VideoControllerPool extends ChangeNotifier {
  VideoControllerPool({
    required this._createController,
    this.preloadRadius = 1,
    PlaybackMetrics? metrics,
    this.initTimeout = const Duration(seconds: 20),
  }) : assert(preloadRadius >= 0, 'preloadRadius must be >= 0'),
       metrics = metrics ?? PlaybackMetrics();

  final VideoControllerFactory _createController;
  final int preloadRadius;
  final PlaybackMetrics metrics;
  final Duration initTimeout;

  final Map<String, PlayerSlot> _slots = {};
  List<VideoPost> _posts = const [];
  int _activeIndex = 0;
  String? _activeId;
  bool _playbackAllowed = true;
  bool _userPaused = false;
  int _generation = 0;
  bool _disposed = false;

  int get activeIndex => _activeIndex;
  String? get activePostId => _activeId;
  bool get playbackAllowed => _playbackAllowed;
  bool get userPaused => _userPaused;
  int get liveControllerCount => _slots.length;
  PlayerSlot? slotFor(String postId) => _slots[postId];

  /// Live slots in feed order, for the debug HUD and tests.
  List<PlayerSlot> get slotsInFeedOrder {
    final order = {for (var i = 0; i < _posts.length; i++) _posts[i].id: i};
    return _slots.values.toList()
      ..sort((a, b) => (order[a.post.id] ?? 0).compareTo(order[b.post.id] ?? 0));
  }

  /// Index of [postId] relative to the active page (-1 previous, +1 next).
  int? offsetFromActive(String postId) {
    final i = _posts.indexWhere((p) => p.id == postId);
    return i < 0 ? null : i - _activeIndex;
  }

  /// Indices to keep, in the order they should be initialised.
  @visibleForTesting
  static List<int> priorityOrder(int center, int length, int radius) {
    if (length == 0) return const [];
    final c = center.clamp(0, length - 1);
    final order = <int>[c];
    for (var d = 1; d <= radius; d++) {
      // Forward first: in a feed most swipes go forward.
      if (c + d < length) order.add(c + d);
      if (c - d >= 0) order.add(c - d);
    }
    return order;
  }

  /// The feed list changed: first load, page appended, or refresh.
  void updatePosts(List<VideoPost> posts) {
    _posts = List.unmodifiable(posts);
    _reconcile();
  }

  /// Page [index] is now on screen. An index past the last post (the
  /// loading footer) means no post is active; the window stays around the
  /// last post so scrolling back is instant.
  void activate(int index) {
    _activeIndex = index;
    _reconcile();
  }

  /// Route covered or app backgrounded: pause without losing the window.
  void setPlaybackAllowed(bool allowed) {
    if (_playbackAllowed == allowed) return;
    _playbackAllowed = allowed;
    _applyPlayback();
    notifyListeners();
  }

  /// Tap-to-pause on the active post. Reset when the active post changes.
  void toggleUserPause() {
    _userPaused = !_userPaused;
    _applyPlayback();
    notifyListeners();
  }

  /// Replaces a failed player with a fresh one.
  void retry(String postId) {
    if (_slots[postId]?.status != SlotStatus.failed) return;
    _disposeSlot(postId);
    _reconcile();
  }

  void _reconcile() {
    if (_disposed) return;
    final generation = ++_generation;
    final hasActive = _activeIndex >= 0 && _activeIndex < _posts.length;
    final newActiveId = hasActive ? _posts[_activeIndex].id : null;

    if (newActiveId != _activeId) {
      final previous = _activeId;
      if (previous != null) {
        metrics.activationAbandoned(previous);
        _deactivate(_slots[previous]);
      }
      _activeId = newActiveId;
      _userPaused = false;
      if (newActiveId != null) {
        metrics.activationStarted(newActiveId, preloaded: _slots[newActiveId]?.isReady ?? false);
      }
    }

    final order = priorityOrder(
      math.min(_activeIndex, _posts.length - 1),
      _posts.length,
      preloadRadius,
    );
    final wanted = {for (final i in order) _posts[i].id};
    for (final id in _slots.keys.toList()) {
      if (!wanted.contains(id)) _disposeSlot(id);
    }

    _applyPlayback();
    notifyListeners();
    unawaited(_fill(generation, [for (final i in order) _posts[i]]));
  }

  /// Creates missing players one at a time, in priority order. A newer
  /// reconcile bumps [_generation] and this loop stops at its next check.
  Future<void> _fill(int generation, List<VideoPost> posts) async {
    for (final post in posts) {
      if (_disposed || generation != _generation) return;
      final slot = _slots[post.id] ?? _createSlot(post);
      await slot.settled;
    }
  }

  PlayerSlot _createSlot(VideoPost post) {
    final slot = PlayerSlot._(post, _createController(post));
    _slots[post.id] = slot;
    metrics.livePlayersChanged(_slots.length);
    void listener() => _onControllerValue(slot);
    slot._listener = listener;
    slot.controller.addListener(listener);
    notifyListeners();
    unawaited(_initialize(slot));
    return slot;
  }

  Future<void> _initialize(PlayerSlot slot) async {
    final watch = Stopwatch()..start();
    try {
      await slot.controller.initialize().timeout(initTimeout);
      if (slot._disposed) return;
      await slot.controller.setLooping(true);
      if (slot._disposed) return;
      slot._status = SlotStatus.ready;
      metrics.initialized(watch.elapsed);
    } on Object catch (error) {
      if (slot._disposed) return;
      slot._status = SlotStatus.failed;
      slot._error = error;
      metrics.initFailed();
    } finally {
      slot._settle();
      if (!slot._disposed && !_disposed) {
        _applyPlayback();
        notifyListeners();
      }
    }
  }

  /// Detects the first moving frame of the active post: the player says it
  /// is playing and its position has advanced. Position is polled by
  /// video_player every 100 ms, which bounds the precision of the metric.
  void _onControllerValue(PlayerSlot slot) {
    if (slot._disposed || slot._showingVideo || slot.post.id != _activeId) return;
    final value = slot.controller.value;
    if (value.isPlaying && value.position > Duration.zero) {
      slot._showingVideo = true;
      metrics.firstFrame(slot.post.id);
      notifyListeners();
    }
  }

  void _applyPlayback() {
    for (final slot in _slots.values) {
      if (!slot.isReady) continue;
      final shouldPlay = slot.post.id == _activeId && _playbackAllowed && !_userPaused;
      final isPlaying = slot.controller.value.isPlaying;
      if (shouldPlay && !isPlaying) {
        unawaited(slot.controller.play());
      } else if (!shouldPlay && isPlaying) {
        unawaited(slot.controller.pause());
      }
    }
  }

  void _deactivate(PlayerSlot? slot) {
    if (slot == null) return;
    slot._showingVideo = false;
    if (slot.isReady) {
      unawaited(slot.controller.pause());
      unawaited(slot.controller.seekTo(Duration.zero));
    }
  }

  void _disposeSlot(String id) {
    final slot = _slots.remove(id);
    if (slot == null) return;
    metrics.livePlayersChanged(_slots.length);
    slot._disposed = true;
    slot._settle();
    final listener = slot._listener;
    if (listener != null) slot.controller.removeListener(listener);
    // Safe while initialize() is still running: video_player waits for the
    // platform player to exist before releasing it.
    unawaited(slot.controller.dispose());
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    for (final id in _slots.keys.toList()) {
      _disposeSlot(id);
    }
    super.dispose();
  }
}
