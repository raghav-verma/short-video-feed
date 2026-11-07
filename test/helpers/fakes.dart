import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:short_video_feed/app/app.dart';
import 'package:short_video_feed/app/locale_controller.dart';
import 'package:short_video_feed/feed/application/feed_controller.dart';
import 'package:short_video_feed/feed/data/feed_repository.dart';
import 'package:short_video_feed/feed/domain/video_post.dart';
import 'package:short_video_feed/feed/playback/playback_providers.dart';
import 'package:video_player/video_player.dart';

/// A stand-in for [VideoPlayerController] for widget and golden tests.
///
/// It never touches the platform. `playerId` stays at the "uninitialised"
/// sentinel, so the real `VideoPlayer` widget renders an empty box instead
/// of a platform texture. Initialisation finishes immediately unless
/// [holdInit] is set, which keeps the poster on screen for goldens.
class FakeVideoPlayerController extends ValueNotifier<VideoPlayerValue>
    implements VideoPlayerController {
  FakeVideoPlayerController(this.post, {this.holdInit = false})
    : super(const VideoPlayerValue.uninitialized());

  final VideoPost post;
  final bool holdInit;
  bool disposed = false;
  int playCalls = 0;
  int pauseCalls = 0;

  @override
  int get playerId => VideoPlayerController.kUninitializedPlayerId;

  @override
  Future<void> initialize() async {
    if (holdInit) return Completer<void>().future;
    value = value.copyWith(
      isInitialized: true,
      duration: const Duration(seconds: 10),
      size: const Size(1280, 720),
    );
  }

  @override
  Future<void> play() async {
    playCalls++;
    value = value.copyWith(isPlaying: true);
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
    value = value.copyWith(isPlaying: false);
  }

  @override
  Future<void> seekTo(Duration position) async => value = value.copyWith(position: position);

  @override
  Future<void> setLooping(bool looping) async => value = value.copyWith(isLooping: looping);

  @override
  Future<void> dispose() async {
    disposed = true;
    super.dispose();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Records every fake the pool creates, in order.
class FakePlayers {
  FakePlayers({this.holdInit = false});

  final bool holdInit;
  final List<FakeVideoPlayerController> created = [];

  FakeVideoPlayerController create(VideoPost post) {
    final c = FakeVideoPlayerController(post, holdInit: holdInit);
    created.add(c);
    return c;
  }

  Iterable<FakeVideoPlayerController> get live => created.where((c) => !c.disposed);

  FakeVideoPlayerController latestFor(String postId) =>
      created.lastWhere((c) => c.post.id == postId);
}

/// Pumps the whole app with a zero-latency demo feed and fake players.
Future<FakePlayers> pumpApp(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  Widget? home,
  FeedRepository? repository,
  bool holdInit = false,
  int preloadRadius = 1,
}) async {
  final players = FakePlayers(holdInit: holdInit);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        feedRepositoryProvider.overrideWithValue(
          repository ?? DemoFeedRepository(latency: Duration.zero, pageSize: 4, pageCount: 2),
        ),
        videoControllerFactoryProvider.overrideWithValue(players.create),
        preloadRadiusProvider.overrideWithValue(preloadRadius),
        appLocaleProvider.overrideWith(() => _FixedLocale(locale)),
      ],
      child: home == null ? const ShortVideoApp() : ShortVideoApp(home: home),
    ),
  );
  return players;
}

/// Starts the app in a fixed locale; the in-app toggle still works.
class _FixedLocale extends AppLocale {
  _FixedLocale(this._locale);

  final Locale _locale;

  @override
  Locale? build() => _locale;
}
