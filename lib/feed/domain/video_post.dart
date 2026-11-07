import 'package:flutter/foundation.dart';

/// How the media is delivered. HLS gets an explicit format hint on Android so
/// ExoPlayer does not have to sniff the URL.
enum StreamFormat { hls, mp4 }

/// One item in the vertical feed.
@immutable
class VideoPost {
  const VideoPost({
    required this.id,
    required this.videoUrl,
    required this.format,
    required this.posterAsset,
    required this.authorHandle,
    required this.authorName,
    required this.caption,
    required this.likeCount,
  });

  /// Stable id. The controller pool keys players by id, not by list index, so
  /// a refresh or a page append never hands a player to the wrong post.
  final String id;
  final String videoUrl;
  final StreamFormat format;

  Uri get videoUri => Uri.parse(videoUrl);

  /// The stream's real first frame, extracted with ffmpeg and bundled.
  ///
  /// It is shown until the player reports moving frames. Because it is the
  /// same picture the decoder shows first, the poster-to-video swap has no
  /// visible jump. In production this would be a CDN thumbnail URL from the
  /// API; a bundled asset keeps the demo offline-safe for that part.
  final String posterAsset;
  final String authorHandle;
  final String authorName;
  final String caption;
  final int likeCount;

  VideoPost copyWith({String? id}) => VideoPost(
    id: id ?? this.id,
    videoUrl: videoUrl,
    format: format,
    posterAsset: posterAsset,
    authorHandle: authorHandle,
    authorName: authorName,
    caption: caption,
    likeCount: likeCount,
  );

  @override
  bool operator ==(Object other) => other is VideoPost && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'VideoPost($id)';
}
