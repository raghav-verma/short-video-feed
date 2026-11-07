// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playback_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Shared so the debug overlay and the profile-mode benchmark read the same
/// numbers the pool records.

@ProviderFor(playbackMetrics)
final playbackMetricsProvider = PlaybackMetricsProvider._();

/// Shared so the debug overlay and the profile-mode benchmark read the same
/// numbers the pool records.

final class PlaybackMetricsProvider
    extends
        $FunctionalProvider<PlaybackMetrics, PlaybackMetrics, PlaybackMetrics>
    with $Provider<PlaybackMetrics> {
  /// Shared so the debug overlay and the profile-mode benchmark read the same
  /// numbers the pool records.
  PlaybackMetricsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'playbackMetricsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$playbackMetricsHash();

  @$internal
  @override
  $ProviderElement<PlaybackMetrics> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PlaybackMetrics create(Ref ref) {
    return playbackMetrics(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PlaybackMetrics value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PlaybackMetrics>(value),
    );
  }
}

String _$playbackMetricsHash() => r'6cdc8550f3c16d58632e5d365347f99c14074af2';

/// Overridden in widget tests with fake controllers.

@ProviderFor(videoControllerFactory)
final videoControllerFactoryProvider = VideoControllerFactoryProvider._();

/// Overridden in widget tests with fake controllers.

final class VideoControllerFactoryProvider
    extends
        $FunctionalProvider<
          VideoControllerFactory,
          VideoControllerFactory,
          VideoControllerFactory
        >
    with $Provider<VideoControllerFactory> {
  /// Overridden in widget tests with fake controllers.
  VideoControllerFactoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'videoControllerFactoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$videoControllerFactoryHash();

  @$internal
  @override
  $ProviderElement<VideoControllerFactory> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  VideoControllerFactory create(Ref ref) {
    return videoControllerFactory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VideoControllerFactory value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VideoControllerFactory>(value),
    );
  }
}

String _$videoControllerFactoryHash() =>
    r'9a4c3616a0d5314c06f0ad8bee55a2da33e79f1e';

@ProviderFor(preloadRadius)
final preloadRadiusProvider = PreloadRadiusProvider._();

final class PreloadRadiusProvider extends $FunctionalProvider<int, int, int>
    with $Provider<int> {
  PreloadRadiusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'preloadRadiusProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$preloadRadiusHash();

  @$internal
  @override
  $ProviderElement<int> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  int create(Ref ref) {
    return preloadRadius(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$preloadRadiusHash() => r'a155c9a01d0150224970bdecbfe50cdd3c0d0649';
