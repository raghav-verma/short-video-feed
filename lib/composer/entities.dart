import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

enum EntityKind { mention, hashtag }

/// A mention or hashtag inside a string. Offsets are UTF-16 code units and
/// cover the sigil (`@` or `#`) and the name, but not any bidi isolate marks
/// around them.
@immutable
class TextEntity {
  const TextEntity({
    required this.kind,
    required this.start,
    required this.end,
    required this.value,
  });

  final EntityKind kind;
  final int start;
  final int end;

  /// The name without the sigil: `layla.h`, `فلاتر`.
  final String value;

  @override
  bool operator ==(Object other) =>
      other is TextEntity &&
      other.kind == kind &&
      other.start == start &&
      other.end == end &&
      other.value == value;

  @override
  int get hashCode => Object.hash(kind, start, end, value);

  @override
  String toString() => 'TextEntity($kind, $start-$end, $value)';
}

/// An `@` or `#` token being typed at the caret, for the suggestion list.
@immutable
class EntityQuery {
  const EntityQuery({
    required this.kind,
    required this.start,
    required this.end,
    required this.query,
  });

  final EntityKind kind;

  /// Offset of the sigil.
  final int start;

  /// The caret offset.
  final int end;

  /// What follows the sigil so far; may be empty.
  final String query;

  @override
  bool operator ==(Object other) =>
      other is EntityQuery &&
      other.kind == kind &&
      other.start == start &&
      other.end == end &&
      other.query == query;

  @override
  int get hashCode => Object.hash(kind, start, end, query);

  @override
  String toString() => 'EntityQuery($kind, $start-$end, "$query")';
}

/// Unicode bidi isolates (UAX #9, section 2.7).
///
/// An inserted mention is wrapped as FSI + `@name` + PDI. Without the
/// isolate, `@raghav` inside Arabic text renders as `raghav@`: the `@` is a
/// neutral character between a right-to-left word and a left-to-right one,
/// so it takes the paragraph's RTL direction and lands on the wrong side.
/// FSI picks the direction from the token's own first strong character, so
/// the same wrapper is right for `@name`, `#flutter` and `#فلاتر`.
abstract final class BidiIsolate {
  static const String lri = '\u2066';
  static const String rli = '\u2067';
  static const String fsi = '\u2068';
  static const String pdi = '\u2069';

  static final RegExp _controls = RegExp('[\u2066-\u2069]');

  static String wrap(String token) => '$fsi$token$pdi';

  /// Removes isolate marks, for example before sending text to a server.
  static String strip(String text) => text.replaceAll(_controls, '');

  static bool isControl(int codeUnit) => codeUnit >= 0x2066 && codeUnit <= 0x2069;
}

/// Finds mentions and hashtags.
abstract final class EntityParser {
  // `@` must not follow a letter, digit, `_` or another `@`, so emails such
  // as a@b.com are not mentions. Handles are ASCII, may contain dots but do
  // not end with one.
  static final RegExp _mention = RegExp(
    r'(?<![\p{L}\p{N}_@])@([A-Za-z0-9_](?:[A-Za-z0-9_.]*[A-Za-z0-9_])?)',
    unicode: true,
  );

  // Hashtags accept any script (Arabic letters plus combining marks such as
  // harakat) but need at least one letter, so "#1" is not a tag.
  static final RegExp _hashtag = RegExp(
    r'(?<![\p{L}\p{N}_&#])#([\p{L}\p{M}\p{N}_]*[\p{L}\p{M}][\p{L}\p{M}\p{N}_]*)',
    unicode: true,
  );

  static final RegExp _mentionQuery = RegExp(r'^[A-Za-z0-9_.]*$');
  static final RegExp _hashtagQuery = RegExp(r'^[\p{L}\p{M}\p{N}_]*$', unicode: true);

  static List<TextEntity> parse(String text) {
    final entities = <TextEntity>[
      for (final m in _mention.allMatches(text))
        TextEntity(kind: EntityKind.mention, start: m.start, end: m.end, value: m.group(1)!),
      for (final m in _hashtag.allMatches(text))
        TextEntity(kind: EntityKind.hashtag, start: m.start, end: m.end, value: m.group(1)!),
    ]..sort((a, b) => a.start.compareTo(b.start));
    return entities;
  }

  /// The `@`/`#` token that ends at [caret], if the user is typing one.
  static EntityQuery? queryAt(String text, int caret) {
    if (caret <= 0 || caret > text.length) return null;
    for (var i = caret - 1; i >= 0; i--) {
      final unit = text.codeUnitAt(i);
      if (_isBoundary(unit)) return null;
      final isMention = unit == 0x40; // @
      final isHashtag = unit == 0x23; // #
      if (!isMention && !isHashtag) continue;
      if (i > 0 && !_isBoundary(text.codeUnitAt(i - 1))) return null;
      final query = text.substring(i + 1, caret);
      final kind = isMention ? EntityKind.mention : EntityKind.hashtag;
      final valid = isMention ? _mentionQuery.hasMatch(query) : _hashtagQuery.hasMatch(query);
      return valid ? EntityQuery(kind: kind, start: i, end: caret, query: query) : null;
    }
    return null;
  }

  static bool _isBoundary(int unit) =>
      unit == 0x20 || unit == 0x0A || unit == 0x09 || unit == 0xA0 || BidiIsolate.isControl(unit);
}

/// Paragraph direction from the first strong character, skipping anything
/// inside isolates (UAX #9 rules P2 and P3). This is what HTML's `dir="auto"`
/// does. Returns null when the text has no strong character yet, so callers
/// can fall back to the UI direction.
TextDirection? firstStrongDirection(String text) {
  var depth = 0;
  for (final rune in text.runes) {
    if (rune >= 0x2066 && rune <= 0x2068) {
      depth++;
    } else if (rune == 0x2069) {
      if (depth > 0) depth--;
    } else if (depth == 0) {
      if (_isStrongRtl(rune)) return TextDirection.rtl;
      if (_isStrongLtr(rune)) return TextDirection.ltr;
    }
  }
  return null;
}

bool _isStrongRtl(int r) {
  // Arabic-Indic digits are weak (AN/EN) and harakat are non-spacing marks.
  if ((r >= 0x0660 && r <= 0x0669) || (r >= 0x06F0 && r <= 0x06F9)) return false;
  if ((r >= 0x064B && r <= 0x065F) || r == 0x0670) return false;
  return (r >= 0x0590 && r <= 0x08FF) || // Hebrew, Arabic, Syriac, Thaana, NKo, Arabic ext.
      (r >= 0xFB1D && r <= 0xFDFF) || // Hebrew + Arabic presentation forms A
      (r >= 0xFE70 && r <= 0xFEFF); // Arabic presentation forms B
}

final RegExp _letter = RegExp(r'\p{L}', unicode: true);

bool _isStrongLtr(int r) => !_isStrongRtl(r) && _letter.hasMatch(String.fromCharCode(r));

/// Splits [text] into styled spans: entities get [entityStyles], and the IME
/// composing range (if any) is underlined, as `TextEditingController` does.
///
/// With [isolateEntities] each entity is wrapped in FSI/PDI. That changes the
/// string, so it is only for read-only text such as captions, never for an
/// editable field where offsets must match the controller.
List<InlineSpan> buildEntitySpans(
  String text, {
  required Map<EntityKind, TextStyle> entityStyles,
  TextRange composing = TextRange.empty,
  bool isolateEntities = false,
}) {
  final entities = EntityParser.parse(text);
  final cuts = <int>{
    0,
    text.length,
    for (final e in entities) ...[e.start, e.end],
    if (composing.isValid && !composing.isCollapsed) ...[composing.start, composing.end],
  }.where((c) => c >= 0 && c <= text.length).toList()..sort();

  final spans = <InlineSpan>[];
  for (var i = 0; i + 1 < cuts.length; i++) {
    final start = cuts[i];
    final end = cuts[i + 1];
    if (start == end) continue;
    TextEntity? entity;
    for (final e in entities) {
      if (e.start <= start && end <= e.end) {
        entity = e;
        break;
      }
    }
    var style = entity == null ? null : entityStyles[entity.kind];
    if (composing.isValid && composing.start <= start && end <= composing.end) {
      style = (style ?? const TextStyle()).merge(
        const TextStyle(decoration: TextDecoration.underline),
      );
    }
    var segment = text.substring(start, end);
    if (isolateEntities && entity != null) {
      segment = BidiIsolate.wrap(segment);
    }
    spans.add(TextSpan(text: segment, style: style));
  }
  return spans;
}
