import 'dart:async';
import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:short_video_feed/feed/domain/video_post.dart';
import 'package:short_video_feed/feed/playback/playback_metrics.dart';
import 'package:short_video_feed/feed/playback/video_controller_pool.dart';
import 'package:video_player/video_player.dart';

class MockVideoPlayerController extends Mock implements VideoPlayerController {}

/// One mocked player plus the knobs a test needs: finish or fail its
/// initialisation, and push value updates to the pool's listener.
class PlayerHandle {
  PlayerHandle(this.post) {
    when(() => mock.value).thenAnswer((_) => value);
    when(() => mock.initialize()).thenAnswer((_) => _init.future);
    when(() => mock.setLooping(any())).thenAnswer((_) async {});
    when(() => mock.play()).thenAnswer((_) async => value = value.copyWith(isPlaying: true));
    when(() => mock.pause()).thenAnswer((_) async => value = value.copyWith(isPlaying: false));
    when(() => mock.seekTo(any())).thenAnswer((inv) async {
      value = value.copyWith(position: inv.positionalArguments.first as Duration);
    });
    when(() => mock.dispose()).thenAnswer((_) async {});
    when(() => mock.addListener(any())).thenAnswer((inv) {
      listener = inv.positionalArguments.first as VoidCallback;
    });
    when(() => mock.removeListener(any())).thenAnswer((_) => listener = null);
  }

  final VideoPost post;
  final MockVideoPlayerController mock = MockVideoPlayerController();
  final Completer<void> _init = Completer<void>();
  VideoPlayerValue value = const VideoPlayerValue.uninitialized();
  VoidCallback? listener;

  void finishInit() {
    value = value.copyWith(
      isInitialized: true,
      duration: const Duration(seconds: 10),
      size: const Size(1280, 720),
    );
    _init.complete();
  }

  void failInit() => _init.completeError(Exception('404'));

  /// Simulates video_player's position timer reporting progress.
  void advance(Duration position) {
    value = value.copyWith(position: position);
    listener?.call();
  }
}

List<VideoPost> posts(int n, {String prefix = 'p'}) => [
  for (var i = 0; i < n; i++)
    VideoPost(
      id: '$prefix$i',
      videoUrl: 'https://example.com/$prefix$i.m3u8',
      format: StreamFormat.hls,
      posterAsset: 'assets/posters/bee.jpg',
      authorHandle: 'a',
      authorName: 'A',
      caption: '',
      likeCount: 0,
    ),
];

void main() {
  setUpAll(() {
    registerFallbackValue(Duration.zero);
    registerFallbackValue(() {});
  });

  late Map<String, PlayerHandle> players;
  late List<String> created;
  late PlaybackMetrics metrics;
  late VideoControllerPool pool;

  VideoControllerPool makePool({int radius = 1}) => VideoControllerPool(
    createController: (post) {
      created.add(post.id);
      return (players[post.id] = PlayerHandle(post)).mock;
    },
    preloadRadius: radius,
    metrics: metrics,
  );

  /// Finishes initialisation of [id] and lets the pool react.
  Future<void> ready(String id) async {
    players[id]!.finishInit();
    await pumpEventQueue();
  }

  setUp(() {
    players = {};
    created = [];
    metrics = PlaybackMetrics();
    pool = makePool();
  });

  tearDown(() => pool.dispose());

  group('priorityOrder', () {
    test('active first, then forward before backward', () {
      expect(VideoControllerPool.priorityOrder(5, 10, 1), [5, 6, 4]);
      expect(VideoControllerPool.priorityOrder(5, 10, 2), [5, 6, 4, 7, 3]);
    });

    test('clamps to the list', () {
      expect(VideoControllerPool.priorityOrder(0, 10, 1), [0, 1]);
      expect(VideoControllerPool.priorityOrder(9, 10, 1), [9, 8]);
      expect(VideoControllerPool.priorityOrder(12, 10, 1), [9, 8]);
      expect(VideoControllerPool.priorityOrder(0, 0, 1), isEmpty);
    });

    test('radius 0 keeps only the active post', () {
      expect(VideoControllerPool.priorityOrder(3, 10, 0), [3]);
    });
  });

  group('preloading', () {
    test('initialises the active post first, then neighbours one at a time', () async {
      pool.activate(4);
      pool.updatePosts(posts(10));
      await pumpEventQueue();
      expect(created, ['p4'], reason: 'neighbours wait for the active player');

      await ready('p4');
      expect(created, ['p4', 'p5'], reason: 'next is preloaded before previous');

      await ready('p5');
      expect(created, ['p4', 'p5', 'p3']);
      expect(pool.liveControllerCount, 3);
    });

    test('plays only the active post, and only once it is ready', () async {
      pool.updatePosts(posts(5));
      await pumpEventQueue();
      verifyNever(() => players['p0']!.mock.play());

      await ready('p0');
      verify(() => players['p0']!.mock.play()).called(1);
      verify(() => players['p0']!.mock.setLooping(true)).called(1);

      await ready('p1');
      verifyNever(() => players['p1']!.mock.play());
    });

    test('moving forward disposes players that leave the window', () async {
      pool.updatePosts(posts(10));
      await ready('p0');
      await ready('p1');

      pool.activate(1);
      await pumpEventQueue();
      await ready('p2');
      expect(pool.liveControllerCount, 3);

      pool.activate(2);
      await pumpEventQueue();
      verify(() => players['p0']!.mock.dispose()).called(1);
      expect(pool.slotFor('p0'), isNull);
      expect(pool.slotFor('p1'), isNotNull);
      expect(pool.slotFor('p2'), isNotNull);
    });

    test('a fast swipe disposes a still-initialising player and never plays it', () async {
      pool.updatePosts(posts(10));
      await pumpEventQueue();
      expect(created, ['p0']);

      pool.activate(6);
      await pumpEventQueue();
      verify(() => players['p0']!.mock.dispose()).called(1);
      expect(created, ['p0', 'p6']);

      // The old initialisation finishing late must not resurrect it.
      players['p0']!.finishInit();
      await pumpEventQueue();
      verifyNever(() => players['p0']!.mock.play());
      expect(pool.slotFor('p0'), isNull);
    });

    test('a post that stops being active is paused and rewound', () async {
      pool.updatePosts(posts(5));
      await ready('p0');
      await ready('p1');

      pool.activate(1);
      await pumpEventQueue();
      verify(() => players['p0']!.mock.pause()).called(1);
      verify(() => players['p0']!.mock.seekTo(Duration.zero)).called(1);
      verify(() => players['p1']!.mock.play()).called(1);
    });

    test('appending a page keeps existing players (keyed by id)', () async {
      final first = posts(3);
      pool.updatePosts(first);
      await ready('p0');
      await ready('p1');

      pool.updatePosts([...first, ...posts(3, prefix: 'q')]);
      await pumpEventQueue();
      verifyNever(() => players['p0']!.mock.dispose());
      expect(created, ['p0', 'p1']);
    });

    test('radius 0 never preloads', () async {
      pool.dispose();
      pool = makePool(radius: 0);
      pool.updatePosts(posts(5));
      await ready('p0');
      expect(created, ['p0']);
    });
  });

  group('playback gating', () {
    test('playbackAllowed=false pauses, true resumes', () async {
      pool.updatePosts(posts(3));
      await ready('p0');

      pool.setPlaybackAllowed(false);
      verify(() => players['p0']!.mock.pause()).called(1);

      pool.setPlaybackAllowed(true);
      verify(() => players['p0']!.mock.play()).called(2);
    });

    test('a player that becomes ready while playback is blocked stays paused', () async {
      pool.setPlaybackAllowed(false);
      pool.updatePosts(posts(3));
      await ready('p0');
      verifyNever(() => players['p0']!.mock.play());
    });

    test('tap-to-pause is reset when the active post changes', () async {
      pool.updatePosts(posts(3));
      await ready('p0');
      await ready('p1');

      pool.toggleUserPause();
      expect(pool.userPaused, isTrue);
      verify(() => players['p0']!.mock.pause()).called(1);

      pool.activate(1);
      expect(pool.userPaused, isFalse);
      verify(() => players['p1']!.mock.play()).called(1);
    });
  });

  group('failures', () {
    test('a failed initialisation is reported and retry builds a new player', () async {
      pool.updatePosts(posts(3));
      players['p0']!.failInit();
      await pumpEventQueue();

      expect(pool.slotFor('p0')!.status, SlotStatus.failed);
      expect(metrics.initFailures, 1);
      expect(created, ['p0', 'p1'], reason: 'a failure does not block the neighbours');

      final failed = players['p0']!.mock;
      pool.retry('p0');
      await pumpEventQueue();
      verify(failed.dispose).called(1);
      expect(created.where((id) => id == 'p0'), hasLength(2));
    });
  });

  group('metrics', () {
    test('records time to first frame, flagged as preloaded or cold', () async {
      pool.updatePosts(posts(3));
      await ready('p0');
      players['p0']!.advance(const Duration(milliseconds: 100));
      expect(metrics.startups.single.wasPreloaded, isFalse);
      expect(pool.slotFor('p0')!.showingVideo, isTrue);

      await ready('p1');
      pool.activate(1);
      await pumpEventQueue();
      players['p1']!.advance(const Duration(milliseconds: 100));
      expect(metrics.startups.last.postId, 'p1');
      expect(metrics.startups.last.wasPreloaded, isTrue);
    });

    test('an abandoned activation records nothing', () async {
      pool.updatePosts(posts(5));
      pool.activate(3);
      await pumpEventQueue();
      expect(metrics.startups, isEmpty);
    });
  });

  test('dispose releases every player', () async {
    pool.updatePosts(posts(5));
    await ready('p0');
    await ready('p1');
    pool.dispose();
    verify(() => players['p0']!.mock.dispose()).called(1);
    verify(() => players['p1']!.mock.dispose()).called(1);
    // Recreate so tearDown has something to dispose.
    pool = makePool();
  });
}
