import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../composer/entities.dart';
import '../../composer/entity_text.dart';
import '../../l10n/generated/app_localizations.dart';
import '../domain/video_post.dart';

/// Author, caption and actions over the video.
///
/// Everything is positioned with directional values (`AlignmentDirectional`,
/// `EdgeInsetsDirectional`, `PositionedDirectional`), so in Arabic the text
/// block moves to the right and the action rail to the left with no
/// per-locale code.
class PostOverlay extends StatelessWidget {
  const PostOverlay({super.key, required this.post});

  final VideoPost post;

  static const double _railWidth = 72;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final compact = NumberFormat.compact(locale: locale);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final topInset = MediaQuery.paddingOf(context).top;
    const textStyle = TextStyle(color: Colors.white, fontSize: 15, height: 1.3);

    return Stack(
      children: [
        // Keeps the status bar and the transparent app bar readable over
        // bright video.
        Align(
          alignment: Alignment.topCenter,
          child: IgnorePointer(
            child: SizedBox(
              height: topInset + kToolbarHeight + 48,
              width: double.infinity,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x8C000000), Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
        ),
        const Align(
          alignment: Alignment.bottomCenter,
          child: IgnorePointer(
            child: SizedBox(
              height: 280,
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xB3000000)],
                  ),
                ),
              ),
            ),
          ),
        ),
        Align(
          alignment: AlignmentDirectional.bottomStart,
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(16, 0, _railWidth + 8, 20 + bottomInset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(radius: 16, child: Text(post.authorName.characters.first)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        post.authorName,
                        style: textStyle.copyWith(fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        BidiIsolate.wrap('@${post.authorHandle}'),
                        style: textStyle.copyWith(color: Colors.white70, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                EntityText(post.caption, style: textStyle, maxLines: 3),
              ],
            ),
          ),
        ),
        PositionedDirectional(
          end: 8,
          bottom: 20 + bottomInset,
          width: _railWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RailButton(
                icon: Icons.favorite,
                label: compact.format(post.likeCount),
                tooltip: l10n.likeCountSemantics(post.likeCount),
              ),
              _RailButton(
                icon: Icons.mode_comment_rounded,
                label: l10n.comments,
                tooltip: l10n.comments,
              ),
              _RailButton(icon: Icons.share, label: l10n.share, tooltip: l10n.share),
            ],
          ),
        ),
      ],
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({required this.icon, required this.label, required this.tooltip});

  final IconData icon;
  final String label;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Tooltip(
        message: tooltip,
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
