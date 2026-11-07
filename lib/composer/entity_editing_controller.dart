import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'entities.dart';

/// A [TextEditingController] for the post composer.
///
/// * Highlights mentions and hashtags while keeping the IME's composing
///   underline.
/// * [insertEntity] replaces the `@que` being typed with an isolated token
///   (FSI + `@name` + PDI + space) and puts the caret right after it, using
///   logical offsets, so it behaves the same in LTR and RTL text.
/// * Inserted tokens are atomic: the caret never stops inside one, and a
///   deletion that cuts into one removes the whole token. Without this the
///   invisible isolate marks would cost extra arrow-key presses and a
///   backspace could leave half a mention behind.
class EntityEditingController extends TextEditingController {
  EntityEditingController({super.text});

  static final RegExp _atomicToken = RegExp('\u2068[@#][^\u2066-\u2069\\s]+\u2069');

  /// Ranges of tokens inserted from suggestions, isolate marks included.
  static List<TextRange> atomicRanges(String text) => [
    for (final m in _atomicToken.allMatches(text)) TextRange(start: m.start, end: m.end),
  ];

  /// The `@`/`#` token being typed at a collapsed caret, if any.
  EntityQuery? get activeQuery {
    final selection = value.selection;
    if (!selection.isValid || !selection.isCollapsed) return null;
    return EntityParser.queryAt(text, selection.baseOffset);
  }

  /// Text as it should be sent to a server: isolate marks removed.
  String get plainText => BidiIsolate.strip(text);

  /// Replaces [query] with [token] (for example `@layla.h` or `#فلاتر`).
  void insertEntity(EntityQuery query, String token) {
    final replacement = '${BidiIsolate.wrap(token)} ';
    final updated = text.replaceRange(query.start, query.end, replacement);
    value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: query.start + replacement.length),
    );
  }

  @override
  set value(TextEditingValue newValue) {
    super.value = applyAtomicRules(value, newValue);
  }

  /// The atomic-token rules, as a pure function so they can be unit tested.
  @visibleForTesting
  static TextEditingValue applyAtomicRules(TextEditingValue old, TextEditingValue next) {
    final oldRanges = atomicRanges(old.text);

    // Rule 1: a deletion that cuts into a token removes the whole token. This
    // also runs while the IME is composing, because a keyboard such as Gboard
    // may put the word before the caret into a composing region when you
    // backspace into it. The composing region is cleared so the IME resyncs.
    if (oldRanges.isNotEmpty && next.text.length < old.text.length) {
      final deleted = _pureDeletion(old.text, next.text);
      if (deleted != null) {
        var start = deleted.start;
        var end = deleted.end;
        for (final r in oldRanges) {
          if (r.start < end && r.end > start) {
            start = math.min(start, r.start);
            end = math.max(end, r.end);
          }
        }
        if (start != deleted.start || end != deleted.end) {
          return TextEditingValue(
            text: old.text.replaceRange(start, end, ''),
            selection: TextSelection.collapsed(offset: start),
          );
        }
      }
    }

    // Rule 2: a collapsed caret never rests inside a token. Do not touch the
    // selection while the IME is composing.
    final selection = next.selection;
    if (!selection.isValid || !selection.isCollapsed || next.isComposingRangeValid) {
      return next;
    }
    final caret = selection.baseOffset;
    for (final r in atomicRanges(next.text)) {
      if (caret <= r.start || caret >= r.end) continue;
      final int target;
      final sameText = old.text == next.text && old.selection.isValid;
      if (sameText && old.selection.baseOffset <= r.start) {
        target = r.end; // moving forward through the token
      } else if (sameText && old.selection.baseOffset >= r.end) {
        target = r.start; // moving backward through the token
      } else {
        target = (caret - r.start) <= (r.end - caret) ? r.start : r.end;
      }
      return next.copyWith(
        selection: TextSelection.collapsed(offset: target, affinity: selection.affinity),
      );
    }
    return next;
  }

  /// If [next] is [old] with one contiguous range removed and nothing added,
  /// returns that range in [old]'s offsets.
  static TextRange? _pureDeletion(String old, String next) {
    var prefix = 0;
    while (prefix < next.length && old.codeUnitAt(prefix) == next.codeUnitAt(prefix)) {
      prefix++;
    }
    var suffix = 0;
    while (suffix < next.length - prefix &&
        old.codeUnitAt(old.length - 1 - suffix) == next.codeUnitAt(next.length - 1 - suffix)) {
      suffix++;
    }
    if (prefix + suffix != next.length) return null;
    return TextRange(start: prefix, end: old.length - suffix);
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return TextSpan(
      style: style,
      children: buildEntitySpans(
        text,
        entityStyles: entityStylesFor(scheme),
        composing: withComposing && value.isComposingRangeValid ? value.composing : TextRange.empty,
      ),
    );
  }
}

Map<EntityKind, TextStyle> entityStylesFor(ColorScheme scheme) => {
  EntityKind.mention: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600),
  EntityKind.hashtag: TextStyle(color: scheme.tertiary, fontWeight: FontWeight.w600),
};
