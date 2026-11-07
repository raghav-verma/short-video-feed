import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'locale_controller.g.dart';

/// The app locale. `null` follows the device; the toggle in the feed's app
/// bar switches between English and Arabic for the demo.
@Riverpod(keepAlive: true)
class AppLocale extends _$AppLocale {
  @override
  Locale? build() => null;

  void toggle(Locale current) {
    state = current.languageCode == 'ar' ? const Locale('en') : const Locale('ar');
  }
}
