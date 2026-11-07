import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../feed/ui/feed_page.dart';
import '../l10n/generated/app_localizations.dart';
import 'locale_controller.dart';
import 'route_observer.dart';

class ShortVideoApp extends ConsumerWidget {
  const ShortVideoApp({super.key, this.home = const FeedPage()});

  final Widget home;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      // null follows the device locale; Arabic switches the whole tree to RTL.
      locale: ref.watch(appLocaleProvider),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: buildTheme(),
      navigatorObservers: [feedRouteObserver],
      home: home,
    );
  }
}

ThemeData buildTheme() => ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF3D7BFF),
    brightness: Brightness.dark,
  ),
);
