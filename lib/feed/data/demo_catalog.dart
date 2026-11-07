import '../domain/video_post.dart';

/// Public test streams that respond over HTTPS (checked 7 Nov 2026).
///
/// Six are HLS (MPEG-TS and fMP4 segments, H.264 + AAC, several ABR ladders)
/// and two are progressive MP4, so the pool is exercised on both kinds of
/// source. None of them are portrait, so the feed crops them with
/// `BoxFit.cover`, the same as a real feed does with landscape uploads.
///
/// Captions mix English and Arabic on purpose: they test mention/hashtag
/// parsing and bidi rendering in both UI locales.
const List<VideoPost> demoCatalog = [
  VideoPost(
    id: 'bbb_mux',
    videoUrl: 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
    format: StreamFormat.hls,
    posterAsset: 'assets/posters/bbb_mux.jpg',
    authorHandle: 'open_movies',
    authorName: 'Open Movies',
    caption: 'Big Buck Bunny over HLS, MPEG-TS segments. #hls #flutter @mux_streams',
    likeCount: 12400,
  ),
  VideoPost(
    id: 'bipbop_fmp4',
    videoUrl: 'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8',
    format: StreamFormat.hls,
    posterAsset: 'assets/posters/bipbop_fmp4.jpg',
    authorHandle: 'stream_lab',
    authorName: 'مختبر البث',
    caption: 'بث تجريبي بمقاطع fMP4 وعدة جودات #بث #فلاتر @stream_lab',
    likeCount: 3100,
  ),
  VideoPost(
    id: 'tos_usp',
    videoUrl: 'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8',
    format: StreamFormat.hls,
    posterAsset: 'assets/posters/tos_usp.jpg',
    authorHandle: 'open_movies',
    authorName: 'Open Movies',
    caption: 'Tears of Steel, packaged on the fly. #scifi #hls',
    likeCount: 870,
  ),
  VideoPost(
    id: 'bipbop_ts',
    videoUrl: 'https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8',
    format: StreamFormat.hls,
    posterAsset: 'assets/posters/bipbop_ts.jpg',
    authorHandle: 'test_cards',
    authorName: 'Test Cards',
    caption: 'The bipbop test card. The timecode makes rebuffering easy to spot. #testing',
    likeCount: 512,
  ),
  VideoPost(
    id: 'angel_one',
    videoUrl: 'https://storage.googleapis.com/shaka-demo-assets/angel-one-hls/hls.m3u8',
    format: StreamFormat.hls,
    posterAsset: 'assets/posters/angel_one.jpg',
    authorHandle: 'layla.h',
    authorName: 'ليلى حسن',
    caption: 'مثال للبث التكيفي مع عدة مسارات صوتية @omar_dev #برمجة',
    likeCount: 45200,
  ),
  VideoPost(
    id: 'dark_truths',
    videoUrl: 'https://storage.googleapis.com/shaka-demo-assets/bbb-dark-truths-hls/hls.m3u8',
    format: StreamFormat.hls,
    posterAsset: 'assets/posters/dark_truths.jpg',
    authorHandle: 'open_movies',
    authorName: 'Open Movies',
    caption: 'Dark Truths, an adaptive-bitrate ladder from 144p up. #abr @shaka_player',
    likeCount: 2300,
  ),
  VideoPost(
    id: 'butterfly',
    videoUrl: 'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
    format: StreamFormat.mp4,
    posterAsset: 'assets/posters/butterfly.jpg',
    authorHandle: 'omar_dev',
    authorName: 'عمر خالد',
    caption: 'فراشة في مقطع MP4 قصير بدون HLS #طبيعة @layla.h',
    likeCount: 980,
  ),
  VideoPost(
    id: 'bee',
    videoUrl: 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
    format: StreamFormat.mp4,
    posterAsset: 'assets/posters/bee.jpg',
    authorHandle: 'sara.codes',
    authorName: 'Sara Ahmed',
    caption: 'A bee at work. Progressive MP4, so the first frame needs the moov atom. #nature',
    likeCount: 15000,
  ),
];
