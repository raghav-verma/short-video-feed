// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'خلاصة الفيديو القصير';

  @override
  String get feedTitle => 'لك';

  @override
  String get newPost => 'منشور جديد';

  @override
  String get composerHint => 'اكتب وصفًا. استخدم @ للإشارة إلى شخص و# للوسوم.';

  @override
  String get postAction => 'نشر';

  @override
  String get closeAction => 'إغلاق';

  @override
  String characterCount(int count, int max) {
    return '$count من $max';
  }

  @override
  String mentionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count إشارة',
      many: '$count إشارة',
      few: '$count إشارات',
      two: 'إشارتان',
      one: 'إشارة واحدة',
      zero: 'بلا إشارات',
    );
    return '$_temp0';
  }

  @override
  String hashtagCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count وسم',
      many: '$count وسمًا',
      few: '$count وسوم',
      two: 'وسمان',
      one: 'وسم واحد',
      zero: 'بلا وسوم',
    );
    return '$_temp0';
  }

  @override
  String postedSummary(String mentions, String hashtags) {
    return 'تم النشر: $mentions، $hashtags';
  }

  @override
  String get mentionSuggestions => 'أشخاص';

  @override
  String get hashtagSuggestions => 'وسوم';

  @override
  String get loadingMore => 'جارٍ تحميل المزيد…';

  @override
  String get endOfFeed => 'لقد شاهدت كل شيء';

  @override
  String get feedLoadError => 'تعذّر تحميل الخلاصة';

  @override
  String get videoError => 'يتعذّر تشغيل هذا الفيديو الآن';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get language => 'اللغة';

  @override
  String get playbackStats => 'إحصاءات التشغيل';

  @override
  String get follow => 'متابعة';

  @override
  String get likes => 'إعجابات';

  @override
  String get comments => 'تعليقات';

  @override
  String get share => 'مشاركة';

  @override
  String get paused => 'متوقف مؤقتًا';

  @override
  String likeCountSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count إعجاب',
      many: '$count إعجابًا',
      few: '$count إعجابات',
      two: 'إعجابان',
      one: 'إعجاب واحد',
      zero: 'لا إعجابات',
    );
    return '$_temp0';
  }
}
