/// Build-time configuration, read from `--dart-define` or
/// `--dart-define-from-file`. Nothing here is a secret that ships in git:
/// keys default to empty, and empty means the integration is switched off.
abstract final class AppConfig {
  /// Players kept on each side of the active page. 1 = previous, current,
  /// next. 0 turns preloading off, which is the benchmark baseline.
  static const int preloadRadius = int.fromEnvironment('PRELOAD_RADIUS', defaultValue: 1);

  /// Show the playback stats overlay on launch.
  static const bool showPlaybackHud = bool.fromEnvironment('SHOW_PLAYBACK_HUD');

  /// Sentry DSN. Empty = crash reporting off.
  static const String sentryDsn = String.fromEnvironment('SENTRY_DSN');

  /// Amplitude API key. Empty = analytics off.
  static const String amplitudeApiKey = String.fromEnvironment('AMPLITUDE_API_KEY');
}
