@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:short_video_feed/composer/composer_page.dart';
import 'package:short_video_feed/composer/entities.dart';
import 'package:short_video_feed/feed/data/demo_catalog.dart';
import 'package:short_video_feed/feed/data/feed_repository.dart';

import '../helpers/fakes.dart';

/// Same screens in English and Arabic. The test font draws glyphs as boxes,
/// so these lock the layout (what is mirrored, what is not), not the type.
/// Bidi order inside a line is covered by entities_test.dart.
void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(390, 844);
    view.devicePixelRatio = 1;
  });

  tearDown(() => TestWidgetsFlutterBinding.instance.platformDispatcher.views.first.reset());

  Future<void> loadImages(WidgetTester tester) async {
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        await precacheImage((element.widget as Image).image, element);
      }
    });
    await tester.pumpAndSettle();
  }

  for (final locale in const [Locale('en'), Locale('ar')]) {
    testWidgets('feed post, ${locale.languageCode}', (tester) async {
      // Players never finish initialising, so the first-frame poster shows.
      await pumpApp(
        tester,
        locale: locale,
        holdInit: true,
        // The bipbop test card first: a bright first frame shows the poster layer.
        repository: DemoFeedRepository(
          latency: Duration.zero,
          catalog: [demoCatalog[3], ...demoCatalog.where((p) => p != demoCatalog[3])],
        ),
      );
      await tester.pumpAndSettle();
      await loadImages(tester);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/feed_post_${locale.languageCode}.png'),
      );
      // Let the pool's 20 s init timeout fire after the tree is gone.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 21));
    });

    testWidgets('composer with suggestions, ${locale.languageCode}', (tester) async {
      await pumpApp(tester, locale: locale, home: const ComposerPage());
      final mention = BidiIsolate.wrap('@layla.h');
      final text = locale.languageCode == 'ar'
          ? 'شاهدوا البث مع $mention و #فل'
          : 'Watching the stream with $mention #fl';
      await tester.enterText(find.byKey(const Key('composer-field')), text);
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/composer_${locale.languageCode}.png'),
      );
    });
  }
}
