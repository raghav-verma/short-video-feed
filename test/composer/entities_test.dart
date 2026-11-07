import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:short_video_feed/composer/entities.dart';

void main() {
  group('EntityParser.parse', () {
    test('finds mentions and hashtags in order', () {
      final entities = EntityParser.parse('hi @layla.h meet #flutter and @omar_dev');
      expect(entities.map((e) => '${e.kind.name}:${e.value}'), [
        'mention:layla.h',
        'hashtag:flutter',
        'mention:omar_dev',
      ]);
      expect(entities.first.start, 3);
      expect(entities.first.end, 11);
    });

    test('an email address is not a mention', () {
      expect(EntityParser.parse('mail me at sara@example.com'), isEmpty);
    });

    test('a trailing dot is not part of the handle', () {
      final e = EntityParser.parse('thanks @layla.h.').single;
      expect(e.value, 'layla.h');
    });

    test('Arabic hashtags with harakat are one tag', () {
      final e = EntityParser.parse('مرحبا #فلاتر_العربية و #بَرمجة').map((e) => e.value);
      expect(e, ['فلاتر_العربية', 'بَرمجة']);
    });

    test('a # glued to a preceding letter is not a tag, as on other networks', () {
      // "و" (and) is written attached to the next word in Arabic.
      expect(EntityParser.parse('و#برمجة'), isEmpty);
    });

    test('a hashtag needs a letter', () {
      expect(EntityParser.parse('ranked #1 today'), isEmpty);
      expect(EntityParser.parse('#2026goals').single.value, '2026goals');
    });

    test('entities inside bidi isolates are still found', () {
      final text = 'مرحبا ${BidiIsolate.wrap('@layla.h')} ';
      final e = EntityParser.parse(text).single;
      expect(text.substring(e.start, e.end), '@layla.h');
    });
  });

  group('EntityParser.queryAt', () {
    test('returns the token being typed at the caret', () {
      const text = 'hello @la';
      expect(
        EntityParser.queryAt(text, text.length),
        const EntityQuery(kind: EntityKind.mention, start: 6, end: 9, query: 'la'),
      );
    });

    test('a bare sigil is a query with an empty string', () {
      expect(EntityParser.queryAt('#', 1)?.query, '');
    });

    test('works for Arabic hashtags', () {
      const text = 'مرحبا #فلا';
      expect(EntityParser.queryAt(text, text.length)?.query, 'فلا');
    });

    test('no query once a space ends the token', () {
      expect(EntityParser.queryAt('@layla ', 7), isNull);
    });

    test('no query in the middle of a word', () {
      expect(EntityParser.queryAt('sara@exa', 8), isNull);
    });

    test('no query right after an inserted (isolated) token', () {
      final text = BidiIsolate.wrap('@layla.h');
      expect(EntityParser.queryAt(text, text.length), isNull);
    });
  });

  group('firstStrongDirection', () {
    test('Latin first is LTR, Arabic first is RTL', () {
      expect(firstStrongDirection('Hello مرحبا'), TextDirection.ltr);
      expect(firstStrongDirection('مرحبا Hello'), TextDirection.rtl);
    });

    test('neutral-only text has no direction', () {
      expect(firstStrongDirection('123 @ #!'), isNull);
      expect(firstStrongDirection('٣٤٥'), isNull, reason: 'Arabic-Indic digits are weak');
    });

    test('skips isolated content, per UAX #9 P2', () {
      final text = '${BidiIsolate.wrap('@layla.h')} مرحبا';
      expect(firstStrongDirection(text), TextDirection.rtl);
    });
  });

  group('bidi isolation fixes @ placement in RTL text', () {
    // Lays out [text] as an RTL paragraph and returns the x of the '@' and of
    // the first letter of the handle. Works with the box glyphs of the test
    // font, because it checks positions, not pixels.
    ({double at, double handle}) layout(String text) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: const TextStyle(fontSize: 20)),
        textDirection: TextDirection.rtl,
      )..layout();
      double xOf(int offset) => painter
          .getBoxesForSelection(TextSelection(baseOffset: offset, extentOffset: offset + 1))
          .single
          .left;
      final at = text.indexOf('@');
      final x = (at: xOf(at), handle: xOf(at + 1));
      painter.dispose();
      return x;
    }

    test('without an isolate the @ is drawn to the right of the handle', () {
      final x = layout('مرحبا @raghav');
      expect(x.at, greaterThan(x.handle), reason: 'renders as "raghav@"');
    });

    test('with FSI/PDI the @ is drawn to the left of the handle', () {
      final x = layout('مرحبا ${BidiIsolate.wrap('@raghav')}');
      expect(x.at, lessThan(x.handle), reason: 'renders as "@raghav"');
    });
  });

  group('buildEntitySpans', () {
    test('styles entities and underlines the composing range', () {
      const mention = TextStyle(color: Color(0xFF0000FF));
      final spans = buildEntitySpans(
        'hi @ab cd',
        entityStyles: {EntityKind.mention: mention},
        composing: const TextRange(start: 7, end: 9),
      ).cast<TextSpan>();
      expect(spans.map((s) => s.text), ['hi ', '@ab', ' ', 'cd']);
      expect(spans[1].style, mention);
      expect(spans[3].style?.decoration, TextDecoration.underline);
    });

    test('isolates entities for read-only text', () {
      final spans = buildEntitySpans(
        '@ab',
        entityStyles: const {},
        isolateEntities: true,
      ).cast<TextSpan>();
      expect(spans.single.text, BidiIsolate.wrap('@ab'));
    });
  });
}
