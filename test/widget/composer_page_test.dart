import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:short_video_feed/composer/composer_page.dart';
import 'package:short_video_feed/composer/entities.dart';
import 'package:short_video_feed/composer/suggestions.dart';

import '../helpers/fakes.dart';

final _field = find.byKey(const Key('composer-field'));

EditableText _editable(WidgetTester tester) =>
    tester.widget<EditableText>(find.descendant(of: _field, matching: find.byType(EditableText)));

/// A home screen that opens the composer and keeps what it returns.
class _Launcher extends StatefulWidget {
  const _Launcher();

  @override
  State<_Launcher> createState() => _LauncherState();
}

class _LauncherState extends State<_Launcher> {
  PostDraft? result;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () async {
          final draft = await Navigator.of(context)
              .push<PostDraft>(MaterialPageRoute(builder: (_) => const ComposerPage()));
          setState(() => result = draft);
        },
        child: const Text('open'),
      ),
    ),
  );
}

void main() {
  testWidgets('typing @ suggests people; picking one inserts an isolated mention', (tester) async {
    await pumpApp(tester, home: const ComposerPage());
    await tester.enterText(_field, 'hi @la');
    await tester.pump();

    expect(find.text('ليلى حسن'), findsOneWidget);
    await tester.tap(find.byKey(const Key('suggestion-@layla.h')));
    await tester.pump();

    final value = _editable(tester).controller.value;
    expect(value.text, 'hi ${BidiIsolate.wrap('@layla.h')} ');
    expect(value.selection, TextSelection.collapsed(offset: value.text.length));
    expect(find.byKey(const Key('composer-suggestions')), findsNothing);
  });

  testWidgets('typing # suggests hashtags, including Arabic ones', (tester) async {
    await pumpApp(tester, home: const ComposerPage());
    await tester.enterText(_field, 'مرحبا #ف');
    await tester.pump();

    expect(find.byKey(const Key('suggestion-#فلاتر')), findsOneWidget);
    expect(find.byKey(const Key('suggestion-#flutter')), findsNothing);
  });

  testWidgets('the field direction follows its content in the English UI', (tester) async {
    await pumpApp(tester, home: const ComposerPage());
    expect(_editable(tester).textDirection, TextDirection.ltr, reason: 'empty: UI direction');

    await tester.enterText(_field, 'مرحبا');
    await tester.pump();
    expect(_editable(tester).textDirection, TextDirection.rtl);

    await tester.enterText(_field, '${BidiIsolate.wrap('@layla.h')} hello');
    await tester.pump();
    expect(
      _editable(tester).textDirection,
      TextDirection.ltr,
      reason: 'the isolated mention is skipped; "hello" decides',
    );
  });

  testWidgets('the Arabic UI mirrors the composer and defaults the field to RTL', (tester) async {
    await pumpApp(tester, home: const ComposerPage(), locale: const Locale('ar'));
    final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;

    expect(_editable(tester).textDirection, TextDirection.rtl);
    expect(tester.getCenter(find.byType(CloseButton)).dx, greaterThan(width / 2));
    expect(tester.getCenter(find.byKey(const Key('composer-post'))).dx, lessThan(width / 2));
    expect(find.text('نشر'), findsOneWidget);

    await tester.enterText(_field, 'hello');
    await tester.pump();
    expect(_editable(tester).textDirection, TextDirection.ltr);
  });

  testWidgets('Post returns plain text and the parsed entities', (tester) async {
    await pumpApp(tester, home: const _Launcher());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(_field, 'hi @la');
    await tester.pump();
    await tester.tap(find.byKey(const Key('suggestion-@layla.h')));
    await tester.pump();
    final controller = _editable(tester).controller;
    await tester.enterText(_field, '${controller.text}watch #hls');
    await tester.pump();

    await tester.tap(find.byKey(const Key('composer-post')));
    await tester.pumpAndSettle();

    final result = tester.state<_LauncherState>(find.byType(_Launcher)).result!;
    expect(result.text, 'hi @layla.h watch #hls');
    expect(result.mentions, ['layla.h']);
    expect(result.hashtags, ['hls']);
  });

  testWidgets('the counter ignores isolate marks and blocks posting over the limit', (
    tester,
  ) async {
    await pumpApp(tester, home: const ComposerPage());
    FilledButton post() => tester.widget<FilledButton>(find.byKey(const Key('composer-post')));
    expect(post().onPressed, isNull, reason: 'empty');

    await tester.enterText(_field, BidiIsolate.wrap('@ab'));
    await tester.pump();
    expect(find.text('3 of 280'), findsOneWidget);
    expect(post().onPressed, isNotNull);

    await tester.enterText(_field, 'x' * 281);
    await tester.pump();
    expect(find.text('281 of 280'), findsOneWidget);
    expect(post().onPressed, isNull);
  });
}
