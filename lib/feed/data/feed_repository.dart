import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/video_post.dart';
import 'demo_catalog.dart';

/// One page of the feed plus the cursor for the next one.
@immutable
class FeedPage {
  const FeedPage({required this.items, required this.nextCursor});

  final List<VideoPost> items;

  /// `null` means the end of the feed.
  final String? nextCursor;
}

/// The feed API seam. The app talks to this interface, so tests can mock it
/// and a real backend could replace [DemoFeedRepository] without UI changes.
abstract interface class FeedRepository {
  Future<FeedPage> fetchPage({String? cursor});
}

/// A fake paginated backend over [demoCatalog].
///
/// * Cursor-based pages of [pageSize] items, ending after [pageCount] pages.
/// * Each refresh (a fetch with no cursor) starts a new "epoch": ids change and
///   the order rotates, so pull-to-refresh visibly brings new posts and the
///   controller pool has to swap players.
/// * [latency] simulates the network so the loading states are real.
class DemoFeedRepository implements FeedRepository {
  DemoFeedRepository({
    this.pageSize = 6,
    this.pageCount = 5,
    this.latency = const Duration(milliseconds: 500),
    this._catalog = demoCatalog,
  });

  final int pageSize;
  final int pageCount;
  final Duration latency;
  final List<VideoPost> _catalog;
  int _epoch = -1;

  @override
  Future<FeedPage> fetchPage({String? cursor}) async {
    final ({int epoch, int page}) position;
    if (cursor == null) {
      _epoch++;
      position = (epoch: _epoch, page: 0);
    } else {
      position = _parseCursor(cursor);
    }
    if (latency > Duration.zero) {
      await Future<void>.delayed(latency);
    }

    final start = position.page * pageSize;
    final items = [
      for (var i = start; i < start + pageSize; i++)
        _catalog[(i + position.epoch) % _catalog.length].copyWith(
          id:
              'e${position.epoch}-p${position.page}-$i-'
              '${_catalog[(i + position.epoch) % _catalog.length].id}',
        ),
    ];
    final isLast = position.page + 1 >= pageCount;
    return FeedPage(
      items: items,
      nextCursor: isLast ? null : '${position.epoch}:${position.page + 1}',
    );
  }

  ({int epoch, int page}) _parseCursor(String cursor) {
    final parts = cursor.split(':');
    if (parts.length != 2) {
      throw FormatException('Bad cursor', cursor);
    }
    return (epoch: int.parse(parts[0]), page: int.parse(parts[1]));
  }
}
