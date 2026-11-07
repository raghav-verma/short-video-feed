import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/feed_repository.dart';
import '../domain/video_post.dart';

part 'feed_controller.g.dart';

/// Loaded feed data plus the state of the "load more" request.
///
/// "Load more" is kept separate from the provider's own `AsyncValue`: a failed
/// page append must not replace a feed that is already on screen with an
/// error screen.
@immutable
class FeedState {
  const FeedState({
    required this.posts,
    required this.nextCursor,
    this.isLoadingMore = false,
    this.loadMoreError,
  });

  final List<VideoPost> posts;
  final String? nextCursor;
  final bool isLoadingMore;
  final Object? loadMoreError;

  bool get hasMore => nextCursor != null;

  FeedState copyWith({
    List<VideoPost>? posts,
    String? Function()? nextCursor,
    bool? isLoadingMore,
    Object? Function()? loadMoreError,
  }) => FeedState(
    posts: posts ?? this.posts,
    nextCursor: nextCursor != null ? nextCursor() : this.nextCursor,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    loadMoreError: loadMoreError != null ? loadMoreError() : this.loadMoreError,
  );
}

@Riverpod(keepAlive: true)
FeedRepository feedRepository(Ref ref) => DemoFeedRepository();

/// Paginated feed: first page in [build], then [loadMore] for infinite scroll
/// and [refresh] for pull-to-refresh.
@riverpod
class FeedController extends _$FeedController {
  @override
  Future<FeedState> build() async {
    final page = await ref.watch(feedRepositoryProvider).fetchPage();
    return FeedState(posts: page.items, nextCursor: page.nextCursor);
  }

  /// Appends the next page. Safe to call on every page change: it ignores
  /// calls while the first page or another append is in flight, and after
  /// the last page.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || state.isLoading || current.isLoadingMore || !current.hasMore) {
      return;
    }
    final cursor = current.nextCursor;
    state = AsyncData(current.copyWith(isLoadingMore: true, loadMoreError: () => null));
    try {
      final page = await ref.read(feedRepositoryProvider).fetchPage(cursor: cursor);
      if (!ref.mounted) return;
      final latest = state.value;
      // A refresh landed while this page was loading. Drop the stale page
      // rather than appending page N of the old feed to the new one.
      if (latest == null || latest.nextCursor != cursor) return;
      final seen = {for (final p in latest.posts) p.id};
      state = AsyncData(
        latest.copyWith(
          posts: [...latest.posts, ...page.items.where((p) => !seen.contains(p.id))],
          nextCursor: () => page.nextCursor,
          isLoadingMore: false,
        ),
      );
    } on Object catch (error) {
      if (!ref.mounted) return;
      final latest = state.value;
      if (latest == null || latest.nextCursor != cursor) return;
      state = AsyncData(latest.copyWith(isLoadingMore: false, loadMoreError: () => error));
    }
  }

  /// Reloads from the first page. The old posts stay on screen until the new
  /// page arrives; on failure they stay and the error is rethrown so the
  /// caller can show a snackbar.
  Future<void> refresh() async {
    final page = await ref.read(feedRepositoryProvider).fetchPage();
    if (!ref.mounted) return;
    state = AsyncData(FeedState(posts: page.items, nextCursor: page.nextCursor));
  }
}
