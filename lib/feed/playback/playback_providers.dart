import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../app/app_config.dart';
import 'playback_metrics.dart';
import 'video_controller_pool.dart';

part 'playback_providers.g.dart';

/// Shared so the debug overlay and the profile-mode benchmark read the same
/// numbers the pool records.
@Riverpod(keepAlive: true)
PlaybackMetrics playbackMetrics(Ref ref) {
  final metrics = PlaybackMetrics();
  ref.onDispose(metrics.dispose);
  return metrics;
}

/// Overridden in widget tests with fake controllers.
@Riverpod(keepAlive: true)
VideoControllerFactory videoControllerFactory(Ref ref) => networkVideoController;

@Riverpod(keepAlive: true)
int preloadRadius(Ref ref) => AppConfig.preloadRadius;
