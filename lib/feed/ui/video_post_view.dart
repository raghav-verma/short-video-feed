import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../l10n/generated/app_localizations.dart';
import '../domain/video_post.dart';
import '../playback/video_controller_pool.dart';
import 'post_overlay.dart';

/// One full-screen page of the feed.
///
/// Layers, bottom to top: the video (once its player is initialised), the
/// first-frame poster (faded out once frames are moving), buffering and
/// error states, a tap target for pause, and the caption overlay.
class VideoPostView extends StatelessWidget {
  const VideoPostView({super.key, required this.post, required this.pool});

  final VideoPost post;
  final VideoControllerPool pool;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: pool,
      builder: (context, _) {
        final slot = pool.slotFor(post.id);
        final isActive = pool.activePostId == post.id;
        final ready = slot != null && slot.isReady;
        final showingVideo = slot?.showingVideo ?? false;
        return Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Colors.black),
            if (ready) _VideoSurface(controller: slot.controller),
            IgnorePointer(
              child: AnimatedOpacity(
                key: Key('poster-${post.id}'),
                opacity: showingVideo ? 0 : 1,
                duration: const Duration(milliseconds: 120),
                child: Image.asset(post.posterAsset, fit: BoxFit.cover, gaplessPlayback: true),
              ),
            ),
            if (isActive && ready) _BufferingIndicator(controller: slot.controller),
            if (slot?.status == SlotStatus.failed)
              _VideoError(onRetry: () => pool.retry(post.id))
            else
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: isActive ? pool.toggleUserPause : null,
              ),
            if (isActive && pool.userPaused)
              const IgnorePointer(
                child: Center(
                  child: Icon(Icons.play_arrow_rounded, size: 88, color: Colors.white70),
                ),
              ),
            PostOverlay(post: post),
          ],
        );
      },
    );
  }
}

/// Crops to fill, like the poster, so the poster-to-video swap lines up.
class _VideoSurface extends StatelessWidget {
  const _VideoSurface({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final size = controller.value.size;
    if (size.isEmpty) return VideoPlayer(controller);
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(width: size.width, height: size.height, child: VideoPlayer(controller)),
    );
  }
}

class _BufferingIndicator extends StatelessWidget {
  const _BufferingIndicator({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) => value.isBuffering && value.isPlaying
          ? const IgnorePointer(
              child: Center(
                child: SizedBox.square(
                  dimension: 36,
                  child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white70),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

class _VideoError extends StatelessWidget {
  const _VideoError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ColoredBox(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 40),
            const SizedBox(height: 12),
            Text(l10n.videoError, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: Text(l10n.retry)),
          ],
        ),
      ),
    );
  }
}
