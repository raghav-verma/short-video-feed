import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import 'entities.dart';
import 'entity_editing_controller.dart';
import 'suggestions.dart';

/// Post composer with @mention and #hashtag suggestions.
///
/// RTL handling:
///  * Layout uses directional insets and alignment, so it mirrors in Arabic.
///  * The field's text direction follows its content (first strong
///    character), not the UI locale. Typing Arabic in the English UI flips
///    the field to RTL, so the caret sits at the visual end of the line
///    rather than on the wrong side.
///  * Picked suggestions go in as bidi-isolated atomic tokens; see
///    [EntityEditingController].
class ComposerPage extends StatefulWidget {
  const ComposerPage({super.key, this.initialText = ''});

  static const int maxLength = 280;

  final String initialText;

  @override
  State<ComposerPage> createState() => _ComposerPageState();
}

class _ComposerPageState extends State<ComposerPage> {
  late final EntityEditingController _controller = EntityEditingController(
    text: widget.initialText,
  );
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  void _select(EntityQuery query, String token) {
    _controller.insertEntity(query, token);
    _focusNode.requestFocus();
  }

  void _submit() {
    Navigator.of(context).pop(PostDraft.fromEditorText(_controller.text));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final length = _controller.plainText.characters.length;
    final tooLong = length > ComposerPage.maxLength;
    final canPost = _controller.plainText.trim().isNotEmpty && !tooLong;
    final query = _controller.activeQuery;

    return Scaffold(
      appBar: AppBar(
        leading: CloseButton(onPressed: () => Navigator.of(context).maybePop()),
        title: Text(l10n.newPost),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 12),
            child: FilledButton(
              key: const Key('composer-post'),
              onPressed: canPost ? _submit : null,
              child: Text(l10n.postAction),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(radius: 18, child: Icon(Icons.person, size: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      key: const Key('composer-field'),
                      controller: _controller,
                      focusNode: _focusNode,
                      autofocus: true,
                      minLines: 3,
                      maxLines: 8,
                      keyboardType: TextInputType.multiline,
                      // dir="auto": the content decides, the UI is the fallback.
                      textDirection:
                          firstStrongDirection(_controller.text) ?? Directionality.of(context),
                      textAlign: TextAlign.start,
                      style: theme.textTheme.bodyLarge,
                      decoration: InputDecoration(
                        hintText: l10n.composerHint,
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 4),
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Text(
                  l10n.characterCount(length, ComposerPage.maxLength),
                  key: const Key('composer-count'),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: tooLong ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: query == null
                  ? const SizedBox.shrink()
                  : _SuggestionList(query: query, onSelected: _select),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionList extends StatelessWidget {
  const _SuggestionList({required this.query, required this.onSelected});

  final EntityQuery query;
  final void Function(EntityQuery query, String token) onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final List<Widget> tiles;
    final String header;
    switch (query.kind) {
      case EntityKind.mention:
        header = l10n.mentionSuggestions;
        tiles = [
          for (final user in SuggestionSource.users(query.query))
            ListTile(
              key: Key('suggestion-@${user.handle}'),
              leading: CircleAvatar(child: Text(user.displayName.characters.first)),
              title: Text(user.displayName, textDirection: firstStrongDirection(user.displayName)),
              // Isolated so the @ stays attached on the left in the RTL UI.
              subtitle: Text(BidiIsolate.wrap('@${user.handle}')),
              onTap: () => onSelected(query, '@${user.handle}'),
            ),
        ];
      case EntityKind.hashtag:
        header = l10n.hashtagSuggestions;
        tiles = [
          for (final tag in SuggestionSource.hashtags(query.query))
            ListTile(
              key: Key('suggestion-#$tag'),
              leading: const Icon(Icons.tag),
              title: Text(BidiIsolate.wrap('#$tag')),
              onTap: () => onSelected(query, '#$tag'),
            ),
        ];
    }
    if (tiles.isEmpty) return const SizedBox.shrink();
    return ListView(
      key: const Key('composer-suggestions'),
      padding: EdgeInsets.zero,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 4),
          child: Text(header, style: theme.textTheme.labelLarge),
        ),
        ...tiles,
      ],
    );
  }
}
