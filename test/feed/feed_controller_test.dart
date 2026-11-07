import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:short_video_feed/feed/application/feed_controller.dart';
import 'package:short_video_feed/feed/data/feed_repository.dart';
import 'package:short_video_feed/feed/domain/video_post.dart';

class MockFeedRepository extends Mock implements FeedRepository {}

VideoPost post(String id) => VideoPost(
  id: id,
  videoUrl: 'https://example.com/$id.m3u8',
  format: StreamFormat.hls,
  posterAsset: 'assets/posters/bee.jpg',
  authorHandle: 'a',
  authorName: 'A',
  caption: '',
  likeCount: 0,
);

FeedPage page(List<String> ids, String? next) =>
    FeedPage(items: [for (final id in ids) post(id)], nextCursor: next);

void main() {
  late MockFeedRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = MockFeedRepository();
    container = ProviderContainer.test(
      overrides: [feedRepositoryProvider.overrideWithValue(repo)],
      // Riverpod 3 retries failed providers by default; tests want the error.
      retry: (_, _) => null,
    );
  });

  /// Builds the provider (after the test has stubbed the repository) and
  /// keeps the auto-dispose provider alive for the rest of the test.
  Future<FeedState> start() {
    container.listen(feedControllerProvider, (_, _) {});
    return container.read(feedControllerProvider.future);
  }

  List<String> ids() =>
      container.read(feedControllerProvider).requireValue.posts.map((p) => p.id).toList();
  FeedController notifier() => container.read(feedControllerProvider.notifier);

  test('build loads the first page', () async {
    when(() => repo.fetchPage()).thenAnswer((_) async => page(['a', 'b'], 'c1'));

    final state = await start();
    expect(state.posts.map((p) => p.id), ['a', 'b']);
    expect(state.hasMore, isTrue);
  });

  test('a failing first page surfaces as AsyncError', () async {
    when(() => repo.fetchPage()).thenThrow(Exception('offline'));

    await expectLater(start(), throwsException);
    expect(container.read(feedControllerProvider), isA<AsyncError<FeedState>>());
  });

  test('loadMore appends the next page and skips duplicates', () async {
    when(() => repo.fetchPage()).thenAnswer((_) async => page(['a', 'b'], 'c1'));
    when(() => repo.fetchPage(cursor: 'c1')).thenAnswer((_) async => page(['b', 'c'], 'c2'));
    await start();

    await notifier().loadMore();
    expect(ids(), ['a', 'b', 'c']);
    expect(container.read(feedControllerProvider).requireValue.nextCursor, 'c2');
  });

  test('loadMore while one is in flight does not fetch twice', () async {
    final pending = Completer<FeedPage>();
    when(() => repo.fetchPage()).thenAnswer((_) async => page(['a'], 'c1'));
    when(() => repo.fetchPage(cursor: 'c1')).thenAnswer((_) => pending.future);
    await start();

    final first = notifier().loadMore();
    expect(container.read(feedControllerProvider).requireValue.isLoadingMore, isTrue);
    await notifier().loadMore();
    pending.complete(page(['b'], null));
    await first;

    verify(() => repo.fetchPage(cursor: 'c1')).called(1);
    expect(ids(), ['a', 'b']);
  });

  test('loadMore failure keeps the feed and exposes the error; a retry recovers', () async {
    var calls = 0;
    when(() => repo.fetchPage()).thenAnswer((_) async => page(['a'], 'c1'));
    when(() => repo.fetchPage(cursor: 'c1')).thenAnswer((_) async {
      if (calls++ == 0) throw Exception('timeout');
      return page(['b'], null);
    });
    await start();

    await notifier().loadMore();
    final failed = container.read(feedControllerProvider);
    expect(failed.hasValue, isTrue, reason: 'the feed stays on screen');
    expect(failed.requireValue.loadMoreError, isA<Exception>());
    expect(ids(), ['a']);

    await notifier().loadMore();
    expect(ids(), ['a', 'b']);
    expect(container.read(feedControllerProvider).requireValue.loadMoreError, isNull);
  });

  test('loadMore after the last page does nothing', () async {
    when(() => repo.fetchPage()).thenAnswer((_) async => page(['a'], null));
    await start();

    await notifier().loadMore();
    verify(() => repo.fetchPage()).called(1);
    verifyNoMoreInteractions(repo);
  });

  test('refresh replaces the posts and the cursor', () async {
    var refreshes = 0;
    when(() => repo.fetchPage())
        .thenAnswer((_) async => refreshes++ == 0 ? page(['a', 'b'], 'c1') : page(['x'], 'k1'));
    when(() => repo.fetchPage(cursor: 'c1')).thenAnswer((_) async => page(['c'], 'c2'));
    await start();
    await notifier().loadMore();

    await notifier().refresh();
    expect(ids(), ['x']);
    expect(container.read(feedControllerProvider).requireValue.nextCursor, 'k1');
  });

  test('a page that arrives after a refresh is dropped', () async {
    final stale = Completer<FeedPage>();
    var refreshes = 0;
    when(() => repo.fetchPage())
        .thenAnswer((_) async => refreshes++ == 0 ? page(['a'], 'c1') : page(['x'], 'k1'));
    when(() => repo.fetchPage(cursor: 'c1')).thenAnswer((_) => stale.future);
    await start();

    final loading = notifier().loadMore();
    await notifier().refresh();
    stale.complete(page(['old'], 'c2'));
    await loading;

    expect(ids(), ['x'], reason: 'page 2 of the old feed must not be appended');
  });

  test('a failed refresh keeps the current posts and rethrows', () async {
    var refreshes = 0;
    when(() => repo.fetchPage()).thenAnswer((_) async {
      if (refreshes++ == 0) return page(['a'], 'c1');
      throw Exception('offline');
    });
    await start();

    await expectLater(notifier().refresh(), throwsException);
    expect(ids(), ['a']);
  });
}
