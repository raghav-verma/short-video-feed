// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'locale_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app locale. `null` follows the device; the toggle in the feed's app
/// bar switches between English and Arabic for the demo.

@ProviderFor(AppLocale)
final appLocaleProvider = AppLocaleProvider._();

/// The app locale. `null` follows the device; the toggle in the feed's app
/// bar switches between English and Arabic for the demo.
final class AppLocaleProvider extends $NotifierProvider<AppLocale, Locale?> {
  /// The app locale. `null` follows the device; the toggle in the feed's app
  /// bar switches between English and Arabic for the demo.
  AppLocaleProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appLocaleProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appLocaleHash();

  @$internal
  @override
  AppLocale create() => AppLocale();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Locale? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Locale?>(value),
    );
  }
}

String _$appLocaleHash() => r'93cd30f506c19efa502c3063b559c022f47aa307';

/// The app locale. `null` follows the device; the toggle in the feed's app
/// bar switches between English and Arabic for the demo.

abstract class _$AppLocale extends $Notifier<Locale?> {
  Locale? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<Locale?, Locale?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Locale?, Locale?>,
              Locale?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
