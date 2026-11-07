import 'package:flutter/foundation.dart';

import 'entities.dart';

@immutable
class UserSuggestion {
  const UserSuggestion(this.handle, this.displayName);

  final String handle;
  final String displayName;
}

/// Fake people and hashtags for the composer's suggestion list. Display names
/// mix Arabic and Latin so the list is checked in both directions.
const List<UserSuggestion> demoUsers = [
  UserSuggestion('layla.h', 'ليلى حسن'),
  UserSuggestion('omar_dev', 'عمر خالد'),
  UserSuggestion('sara.codes', 'Sara Ahmed'),
  UserSuggestion('stream_lab', 'مختبر البث'),
  UserSuggestion('mux_streams', 'Mux Test Streams'),
  UserSuggestion('shaka_player', 'Shaka Player'),
  UserSuggestion('open_movies', 'Open Movies'),
  UserSuggestion('yusuf', 'يوسف'),
  UserSuggestion('mina_k', 'Mina K'),
];

const List<String> trendingHashtags = [
  'flutter',
  'fluttercommunity',
  'hls',
  'video',
  'فلاتر',
  'فيديو',
  'برمجة',
  'بث',
];

abstract final class SuggestionSource {
  static const int limit = 6;

  static List<UserSuggestion> users(String query) {
    final q = query.toLowerCase();
    return demoUsers
        .where(
          (u) =>
              u.handle.toLowerCase().startsWith(q) ||
              u.displayName.toLowerCase().split(' ').any((part) => part.startsWith(q)),
        )
        .take(limit)
        .toList();
  }

  static List<String> hashtags(String query) {
    final q = query.toLowerCase();
    return trendingHashtags.where((t) => t.toLowerCase().startsWith(q)).take(limit).toList();
  }
}

/// What the composer returns when the user taps Post.
@immutable
class PostDraft {
  const PostDraft({required this.text, required this.mentions, required this.hashtags});

  /// Parses [rawText] from the editor. Isolate marks are stripped; a server
  /// should store plain text and the client re-isolates entities when it
  /// renders them (see `EntityText`).
  factory PostDraft.fromEditorText(String rawText) {
    final text = BidiIsolate.strip(rawText).trim();
    final entities = EntityParser.parse(text);
    return PostDraft(
      text: text,
      mentions: [
        for (final e in entities)
          if (e.kind == EntityKind.mention) e.value,
      ],
      hashtags: [
        for (final e in entities)
          if (e.kind == EntityKind.hashtag) e.value,
      ],
    );
  }

  final String text;
  final List<String> mentions;
  final List<String> hashtags;
}
