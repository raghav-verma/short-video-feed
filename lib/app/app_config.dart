/// Build-time switches, read from `--dart-define`. None of these are
/// secrets. If a key is ever added (crash reporting, analytics), pass it with
/// `--dart-define-from-file` pointing at a gitignored `dart_defines*.json`.
abstract final class AppConfig {
  /// Players kept on each side of the active page. 1 = previous, current,
  /// next. 0 turns preloading off, which is the benchmark baseline.
  static const int preloadRadius = int.fromEnvironment('PRELOAD_RADIUS', defaultValue: 1);

  /// Show the playback stats overlay on launch.
  static const bool showPlaybackHud = bool.fromEnvironment('SHOW_PLAYBACK_HUD');
}
