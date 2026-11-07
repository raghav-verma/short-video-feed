import 'package:flutter_test/flutter_test.dart';
import 'package:short_video_feed/feed/data/demo_catalog.dart';
import 'package:short_video_feed/feed/data/feed_repository.dart';

void main() {
  DemoFeedRepository repo() =>
      DemoFeedRepository(latency: Duration.zero, pageSize: 4, pageCount: 3);

  test('pages through the catalog until the last page', () async {
    final r = repo();
    final pages = <FeedPage>[await r.fetchPage()];
    while (pages.last.nextCursor != null) {
      pages.add(await r.fetchPage(cursor: pages.last.nextCursor));
    }
    expect(pages, hasLength(3));
    final ids = pages.expand((p) => p.items).map((p) => p.id).toList();
    expect(ids, hasLength(12));
    expect(ids.toSet(), hasLength(12), reason: 'ids are unique across pages');
  });

  test('every refresh is a new epoch with new ids and a rotated order', () async {
    final r = repo();
    final first = await r.fetchPage();
    final second = await r.fetchPage();
    expect(first.items.first.id, isNot(second.items.first.id));
    expect(second.items.first.videoUrl, demoCatalog[1].videoUrl);
  });

  test('rejects a malformed cursor', () {
    expect(repo().fetchPage(cursor: 'nope'), throwsFormatException);
  });

  test('every catalog poster is a bundled asset path', () {
    for (final post in demoCatalog) {
      expect(post.posterAsset, startsWith('assets/posters/'));
    }
  });
}
