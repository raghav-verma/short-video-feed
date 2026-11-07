import 'package:flutter/material.dart';

import 'entities.dart';
import 'entity_editing_controller.dart';

/// Read-only text with highlighted mentions and hashtags.
///
/// The paragraph direction comes from the content (like `dir="auto"`), so an
/// Arabic caption reads right-to-left inside the English UI and vice versa.
/// Each entity is wrapped in a bidi isolate so `@handle` keeps its `@` on
/// the left inside Arabic text.
class EntityText extends StatelessWidget {
  const EntityText(this.text, {super.key, this.style, this.maxLines});

  final String text;
  final TextStyle? style;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text.rich(
      TextSpan(
        style: style,
        children: buildEntitySpans(
          text,
          entityStyles: entityStylesFor(scheme),
          isolateEntities: true,
        ),
      ),
      textDirection: firstStrongDirection(text) ?? Directionality.of(context),
      textAlign: TextAlign.start,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
    );
  }
}
