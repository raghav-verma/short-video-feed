// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Short Video Feed';

  @override
  String get feedTitle => 'For you';

  @override
  String get newPost => 'New post';

  @override
  String get composerHint => 'Write a caption. Use @ to mention someone and # for hashtags.';

  @override
  String get postAction => 'Post';

  @override
  String get closeAction => 'Close';

  @override
  String characterCount(int count, int max) {
    return '$count of $max';
  }

  @override
  String mentionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mentions',
      one: '1 mention',
      zero: 'no mentions',
    );
    return '$_temp0';
  }

  @override
  String hashtagCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hashtags',
      one: '1 hashtag',
      zero: 'no hashtags',
    );
    return '$_temp0';
  }

  @override
  String postedSummary(String mentions, String hashtags) {
    return 'Posted with $mentions and $hashtags';
  }

  @override
  String get mentionSuggestions => 'People';

  @override
  String get hashtagSuggestions => 'Hashtags';

  @override
  String get loadingMore => 'Loading more…';

  @override
  String get endOfFeed => 'You\'re all caught up';

  @override
  String get feedLoadError => 'Couldn\'t load the feed';

  @override
  String get videoError => 'This video can\'t be played right now';

  @override
  String get retry => 'Retry';

  @override
  String get language => 'Language';

  @override
  String get playbackStats => 'Playback stats';

  @override
  String get follow => 'Follow';

  @override
  String get likes => 'Likes';

  @override
  String get comments => 'Comments';

  @override
  String get share => 'Share';

  @override
  String get paused => 'Paused';

  @override
  String likeCountSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count likes',
      one: '1 like',
    );
    return '$_temp0';
  }
}
