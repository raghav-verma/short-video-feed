import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_config.dart';
import '../../app/locale_controller.dart';
import '../../app/route_observer.dart';
import '../../composer/composer_page.dart';
import '../../composer/suggestions.dart';
import '../../l10n/generated/app_localizations.dart';
import '../application/feed_controller.dart';
import '../playback/playback_providers.dart';
import '../playback/video_controller_pool.dart';
import 'playback_hud.dart';
import 'video_post_view.dart';

/// The vertical feed.
///
/// Visibility rules for playback: only the settled page plays (the pool), and
/// only while this route is on top (RouteAware) and the app is visible
/// (AppLifecycleListener). Pushing the composer or backgrounding the app
/// pauses without disposing the preloaded window.
class FeedPage extends ConsumerStatefulWidget {
  const FeedPage({super.key});

  /// Start loading the next page this many posts before the end.
  static const int loadMoreThreshold = 3;

  @override
  ConsumerState<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends ConsumerState<FeedPage> with RouteAware {
  late final VideoControllerPool _pool;
  final PageController _pageController = PageController();
  late final AppLifecycleListener _lifecycle;
  bool _routeVisible = true;
  bool _appVisible = true;
  bool _showHud = AppConfig.showPlaybackHud;
  ModalRoute<void>? _route;

  @override
  void initState() {
    super.initState();
    _pool = VideoControllerPool(
      createController: ref.read(videoControllerFactoryProvider),
      preloadRadius: ref.read(preloadRadiusProvider),
      metrics: ref.read(playbackMetricsProvider),
    );
    // Start from the real state: `flutter run` on a locked phone, or a cold
    // start from a notification, can build the feed while the app is hidden.
    _appVisible = _isVisible(WidgetsBinding.instance.lifecycleState);
    _pool.setPlaybackAllowed(_appVisible);
    _lifecycle = AppLifecycleListener(onStateChange: (state) => _setAppVisible(_isVisible(state)));
    ref.listenManual(feedControllerProvider, (previous, next) {
      final posts = next.value?.posts;
      if (posts != null && !identical(posts, previous?.value?.posts)) {
        _pool.updatePosts(posts);
      }
    }, fireImmediately: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null && route != _route) {
      if (_route != null) feedRouteObserver.unsubscribe(this);
      _route = route;
      feedRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    feedRouteObserver.unsubscribe(this);
    _lifecycle.dispose();
    _pageController.dispose();
    _pool.dispose();
    super.dispose();
  }

  @override
  void didPushNext() => _setRouteVisible(false);

  @override
  void didPopNext() => _setRouteVisible(true);

  void _setRouteVisible(bool visible) {
    _routeVisible = visible;
    _pool.setPlaybackAllowed(_routeVisible && _appVisible);
  }

  void _setAppVisible(bool visible) {
    _appVisible = visible;
    _pool.setPlaybackAllowed(_routeVisible && _appVisible);
  }

  /// Only `resumed` counts as visible. `inactive` covers the lock screen
  /// over a running app (seen on a OnePlus 8: the decoder kept going
  /// behind the keyguard), the app switcher and system sheets; a feed should
  /// not play sound behind any of them.
  static bool _isVisible(AppLifecycleState? state) =>
      state == null || state == AppLifecycleState.resumed;

  void _onPageChanged(int index) {
    _pool.activate(index);
    final feed = ref.read(feedControllerProvider).value;
    if (feed != null && index >= feed.posts.length - FeedPage.loadMoreThreshold) {
      ref.read(feedControllerProvider.notifier).loadMore();
    }
  }

  Future<void> _onRefresh() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(feedControllerProvider.notifier).refresh();
      if (_pageController.hasClients) _pageController.jumpToPage(0);
      _pool.activate(0);
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(l10n.feedLoadError)));
    }
  }

  Future<void> _openComposer() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final draft = await Navigator.of(context).push<PostDraft>(
      MaterialPageRoute(builder: (_) => const ComposerPage(), fullscreenDialog: true),
    );
    if (draft == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          l10n.postedSummary(
            l10n.mentionCount(draft.mentions.length),
            l10n.hashtagCount(draft.hashtags.length),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final feed = ref.watch(feedControllerProvider);
    final topInset = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text(l10n.feedTitle),
          actions: [
            IconButton(
              tooltip: l10n.language,
              icon: const Icon(Icons.translate),
              onPressed: () =>
                  ref.read(appLocaleProvider.notifier).toggle(Localizations.localeOf(context)),
            ),
            IconButton(
              tooltip: l10n.playbackStats,
              isSelected: _showHud,
              icon: const Icon(Icons.speed),
              onPressed: () => setState(() => _showHud = !_showHud),
            ),
            IconButton(
              key: const Key('compose-button'),
              tooltip: l10n.newPost,
              icon: const Icon(Icons.add_box_outlined),
              onPressed: _openComposer,
            ),
          ],
        ),
        body: switch (feed) {
          AsyncValue(:final value?) => Stack(
            children: [
              RefreshIndicator(
                edgeOffset: topInset + kToolbarHeight,
                onRefresh: _onRefresh,
                child: PageView.builder(
                  key: const Key('feed-pager'),
                  controller: _pageController,
                  scrollDirection: Axis.vertical,
                  onPageChanged: _onPageChanged,
                  itemCount: value.posts.length + 1,
                  itemBuilder: (context, index) {
                    if (index == value.posts.length) {
                      return _FeedFooter(
                        state: value,
                        onRetry: () => ref.read(feedControllerProvider.notifier).loadMore(),
                      );
                    }
                    final post = value.posts[index];
                    return VideoPostView(key: ValueKey(post.id), post: post, pool: _pool);
                  },
                ),
              ),
              if (_showHud)
                PositionedDirectional(
                  top: topInset + kToolbarHeight + 4,
                  start: 8,
                  end: 8,
                  child: Align(
                    alignment: AlignmentDirectional.topStart,
                    child: PlaybackHud(pool: _pool, metrics: ref.read(playbackMetricsProvider)),
                  ),
                ),
            ],
          ),
          AsyncError() => _FeedError(onRetry: () => ref.invalidate(feedControllerProvider)),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class _FeedFooter extends StatelessWidget {
  const _FeedFooter({required this.state, required this.onRetry});

  final FeedState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const textStyle = TextStyle(color: Colors.white);
    final Widget child;
    if (state.loadMoreError != null) {
      child = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.feedLoadError, style: textStyle),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: Text(l10n.retry)),
        ],
      );
    } else if (state.hasMore) {
      child = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(l10n.loadingMore, style: textStyle),
        ],
      );
    } else {
      child = Text(l10n.endOfFeed, key: const Key('end-of-feed'), style: textStyle);
    }
    return ColoredBox(
      color: Colors.black,
      child: Center(child: child),
    );
  }
}

class _FeedError extends StatelessWidget {
  const _FeedError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.feedLoadError, style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: Text(l10n.retry)),
        ],
      ),
    );
  }
}
