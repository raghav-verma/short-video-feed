import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

final _pager = find.byKey(const Key('feed-pager'));

Future<void> swipeUp(WidgetTester tester) async {
  await tester.fling(_pager, const Offset(0, -500), 1500);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the first post plays and the next one is preloaded, paused', (tester) async {
    final players = await pumpApp(tester);
    await tester.pumpAndSettle();

    expect(players.created.map((c) => c.post.id.split('-').last), ['bbb_mux', 'bipbop_fmp4']);
    final first = players.created[0];
    final next = players.created[1];
    expect(first.value.isPlaying, isTrue);
    expect(next.value.isInitialized, isTrue);
    expect(next.value.isPlaying, isFalse);
    expect(find.byKey(Key('poster-${first.post.id}')), findsOneWidget);
  });

  testWidgets('swiping up moves playback to the next post and slides the window', (tester) async {
    final players = await pumpApp(tester);
    await tester.pumpAndSettle();
    final first = players.created[0];

    await swipeUp(tester);

    final second = players.created[1];
    expect(second.value.isPlaying, isTrue);
    expect(first.value.isPlaying, isFalse);
    expect(first.value.position, Duration.zero, reason: 'rewound for next time');
    expect(players.live, hasLength(3), reason: 'previous, current, next');

    await swipeUp(tester);
    expect(first.disposed, isTrue, reason: 'two pages back is outside the window');
    expect(players.live, hasLength(3));
  });

  testWidgets('scrolling near the end loads the next page until the feed ends', (tester) async {
    await pumpApp(tester); // 2 pages of 4 posts
    await tester.pumpAndSettle();

    for (var i = 0; i < 8; i++) {
      await swipeUp(tester);
    }
    expect(find.byKey(const Key('end-of-feed')), findsOneWidget);
  });

  testWidgets('opening the composer pauses the feed and closing it resumes', (tester) async {
    final players = await pumpApp(tester);
    await tester.pumpAndSettle();
    final first = players.created[0];

    await tester.tap(find.byKey(const Key('compose-button')));
    await tester.pumpAndSettle();
    expect(first.value.isPlaying, isFalse);

    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(first.value.isPlaying, isTrue);
  });

  testWidgets('backgrounding the app pauses playback', (tester) async {
    final players = await pumpApp(tester);
    await tester.pumpAndSettle();
    final first = players.created[0];

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    expect(first.value.isPlaying, isFalse);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(first.value.isPlaying, isTrue);
  });

  testWidgets('pull to refresh brings a new first post and a new player', (tester) async {
    final players = await pumpApp(tester);
    await tester.pumpAndSettle();
    final before = players.created[0];

    await tester.fling(_pager, const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(before.disposed, isTrue);
    final playing = players.live.where((c) => c.value.isPlaying).single;
    expect(playing.post.id, startsWith('e1-'), reason: 'second epoch of the demo feed');
  });

  testWidgets('in Arabic the caption block and action rail swap sides', (tester) async {
    await pumpApp(tester, locale: const Locale('ar'));
    await tester.pumpAndSettle();
    final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;

    expect(find.text('لك'), findsOneWidget);
    expect(tester.getCenter(find.byIcon(Icons.favorite).first).dx, lessThan(width / 2));
  });

  testWidgets('in English the action rail is on the right', (tester) async {
    await pumpApp(tester);
    await tester.pumpAndSettle();
    final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;

    expect(tester.getCenter(find.byIcon(Icons.favorite).first).dx, greaterThan(width / 2));
  });
}
