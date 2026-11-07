import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:short_video_feed/composer/entities.dart';
import 'package:short_video_feed/composer/entity_editing_controller.dart';

const fsi = BidiIsolate.fsi;
const pdi = BidiIsolate.pdi;

TextEditingValue caretAt(String text, int offset) => TextEditingValue(
  text: text,
  selection: TextSelection.collapsed(offset: offset),
);

void main() {
  group('insertEntity', () {
    test('replaces the query with an isolated token and puts the caret after it', () {
      final controller = EntityEditingController()..value = caretAt('hi @la', 6);
      controller.insertEntity(controller.activeQuery!, '@layla.h');

      expect(controller.text, 'hi $fsi@layla.h$pdi ');
      expect(controller.selection, const TextSelection.collapsed(offset: 14));
      expect(controller.plainText, 'hi @layla.h ');
      expect(controller.activeQuery, isNull);
    });

    test('works the same in Arabic text, using logical offsets', () {
      const before = 'مرحبا #فل';
      final controller = EntityEditingController()..value = caretAt(before, before.length);
      controller.insertEntity(controller.activeQuery!, '#فلاتر');

      expect(controller.text, 'مرحبا $fsi#فلاتر$pdi ');
      expect(controller.selection.baseOffset, controller.text.length);
    });

    test('inserting in the middle keeps the text after the caret', () {
      final controller = EntityEditingController()..value = caretAt('a @l b', 4);
      controller.insertEntity(controller.activeQuery!, '@layla.h');
      expect(controller.plainText, 'a @layla.h  b');
    });
  });

  group('atomic tokens', () {
    final token = '$fsi@layla.h$pdi';
    final text = 'hi $token ok';
    final tokenStart = 3;
    final tokenEnd = 3 + token.length;

    test('backspace right after a token removes the whole token', () {
      final old = caretAt(text, tokenEnd);
      // What the framework sends for a backspace: one code unit (the PDI) gone.
      final next = caretAt(text.replaceRange(tokenEnd - 1, tokenEnd, ''), tokenEnd - 1);

      final result = EntityEditingController.applyAtomicRules(old, next);
      expect(result.text, 'hi  ok');
      expect(result.selection, TextSelection.collapsed(offset: tokenStart));
    });

    test('also applies while the IME is composing, and clears the composing range', () {
      final old = caretAt(text, tokenEnd);
      final next = caretAt(
        text.replaceRange(tokenEnd - 2, tokenEnd, ''),
        tokenEnd - 2,
      ).copyWith(composing: const TextRange(start: 4, end: 10));

      final result = EntityEditingController.applyAtomicRules(old, next);
      expect(result.text, 'hi  ok');
      expect(result.composing, TextRange.empty);
    });

    test('deleting ordinary text is untouched', () {
      final old = caretAt(text, text.length);
      final next = caretAt(text.substring(0, text.length - 1), text.length - 1);
      expect(EntityEditingController.applyAtomicRules(old, next), next);
    });

    test('a caret moving forward into a token jumps to its end', () {
      final old = caretAt(text, tokenStart);
      final next = caretAt(text, tokenStart + 1);
      expect(EntityEditingController.applyAtomicRules(old, next).selection.baseOffset, tokenEnd);
    });

    test('a caret moving backward into a token jumps to its start', () {
      final old = caretAt(text, tokenEnd);
      final next = caretAt(text, tokenEnd - 1);
      expect(EntityEditingController.applyAtomicRules(old, next).selection.baseOffset, tokenStart);
    });

    test('after a text change, a caret inside a token snaps to the nearer edge', () {
      final old = caretAt('$text!', 0);
      TextEditingValue apply(int caret) =>
          EntityEditingController.applyAtomicRules(old, caretAt(text, caret));
      expect(apply(tokenStart + 1).selection.baseOffset, tokenStart);
      expect(apply(tokenEnd - 1).selection.baseOffset, tokenEnd);
    });

    test('the selection is left alone while composing', () {
      final old = caretAt(text, tokenStart);
      final next = caretAt(
        text,
        tokenStart + 1,
      ).copyWith(composing: const TextRange(start: 0, end: 2));
      expect(EntityEditingController.applyAtomicRules(old, next), next);
    });

    test('a typed (not inserted) mention is ordinary text', () {
      const typed = 'hi @layla ok';
      final old = caretAt(typed, 9);
      final next = caretAt('hi @layl ok', 8);
      expect(EntityEditingController.applyAtomicRules(old, next), next);
    });
  });
}
