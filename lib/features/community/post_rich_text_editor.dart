import 'package:wicchu/theme/wicchu_icons.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:markdown/markdown.dart' as md;
import 'package:markdown_quill/markdown_quill.dart';

import '../../localization/app_language.dart';
import 'post_format_toolbar.dart';
import '../../widgets/facebook_post_embed.dart';
import '../../widgets/youtube_post_embed.dart';

final _youtubeIframePattern = RegExp(
  r'''<iframe\b[^>]*\bsrc=["']([^"']+)["'][^>]*>.*?</iframe>''',
  caseSensitive: false,
  dotAll: true,
);

String normalizeYoutubeIframeText(String value) =>
    value.replaceAllMapped(_youtubeIframePattern, (match) => match.group(1)!);

/// Keeps visual editing separate from the Markdown API contract.
class PostTextController extends ChangeNotifier {
  PostTextController(this.originalText) {
    final normalizedText = normalizeYoutubeIframeText(originalText);
    final document = normalizedText.isEmpty
        ? quill.Document()
        : quill.Document.fromDelta(
            MarkdownToDelta(
              markdownDocument: md.Document(
                encodeHtml: false,
                extensionSet: md.ExtensionSet.gitHubFlavored,
              ),
            ).convert(normalizedText),
          );
    quillController = quill.QuillController.basic()
      ..document = document
      ..updateSelection(
        const TextSelection.collapsed(offset: 0),
        quill.ChangeSource.local,
      );
    quillController.addListener(_normalizeYoutubeIframes);
    quillController.addListener(notifyListeners);
    _originalDelta = jsonEncode(quillController.document.toDelta().toJson());
  }

  static const maxCharacters = 2000;

  /// Quill requires a final newline that is not part of the user's content.
  int get characterCount {
    final plainText = document.toPlainText();
    final content = plainText.endsWith('\n')
        ? plainText.substring(0, plainText.length - 1)
        : plainText;
    return content.characters.length;
  }

  bool get exceedsCharacterLimit => characterCount > maxCharacters;

  final String originalText;
  late final quill.QuillController quillController;
  late final String _originalDelta;

  quill.Document get document => quillController.document;
  TextSelection get selection => quillController.selection;

  String get text {
    final delta = document.toDelta();
    // Editing another field must not rewrite a post's existing Markdown.
    if (jsonEncode(delta.toJson()) == _originalDelta) {
      return normalizeYoutubeIframeText(originalText);
    }
    if (document.toPlainText().trim().isEmpty) return '';
    return DeltaToMarkdown().convert(delta).trimRight();
  }

  void insertMention(String userId, String name) {
    final offset = selection.baseOffset.clamp(0, document.length - 1);
    final label = '@$name';
    document.insert(offset, '$label ');
    quillController.formatText(
      offset,
      label.length,
      quill.LinkAttribute('wicchu://user/$userId'),
    );
    quillController.updateSelection(
      TextSelection.collapsed(offset: offset + label.length + 1),
      quill.ChangeSource.local,
    );
  }

  void replaceText(
    int index,
    int len,
    Object? data,
    TextSelection? textSelection, {
    bool ignoreFocus = false,
  }) => quillController.replaceText(
    index,
    len,
    data,
    textSelection,
    ignoreFocus: ignoreFocus,
  );

  void formatText(int index, int len, quill.Attribute attribute) =>
      quillController.formatText(index, len, attribute);

  void updateSelection(TextSelection value, quill.ChangeSource source) =>
      quillController.updateSelection(value, source);

  quill.Style getSelectionStyle() => quillController.getSelectionStyle();

  void _normalizeYoutubeIframes() {
    final plainText = quillController.document.toPlainText();
    final normalized = normalizeYoutubeIframeText(plainText);
    if (normalized == plainText) return;
    final contentLength = quillController.document.length - 1;
    quillController.replaceText(
      0,
      contentLength,
      normalized,
      TextSelection.collapsed(offset: normalized.length),
      ignoreFocus: true,
    );
  }

  void clear() => quillController.clear();

  @override
  void dispose() {
    quillController.removeListener(_normalizeYoutubeIframes);
    quillController.removeListener(notifyListeners);
    quillController.dispose();
    super.dispose();
  }
}

class PostRichTextEditor extends StatefulWidget {
  const PostRichTextEditor({super.key, required this.controller});
  final PostTextController controller;

  @override
  State<PostRichTextEditor> createState() => _PostRichTextEditorState();
}

class _PostRichTextEditorState extends State<PostRichTextEditor> {
  // QuillEditor.basic creates new nodes when omitted. Keep these alive
  // while validity/selection changes rebuild the enclosing form.
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  PostTextController get controller => widget.controller;

  Widget _videoPreview(BuildContext context) {
    final youtube = extractYoutubePostLinks(controller.text).firstOrNull;
    final facebook = extractFacebookPostLinks(controller.text).firstOrNull;
    final video = youtube != null
        ? YoutubePostEmbed(link: youtube)
        : facebook != null
        ? FacebookPostEmbed(link: facebook)
        : null;
    if (video == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: video,
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Localizations.override(
    context: context,
    delegates: const [quill.FlutterQuillLocalizations.delegate],
    child: Builder(
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.12),
          ),
        ),
        child: Column(
          children: [
            quill.QuillEditor.basic(
              controller: controller.quillController,
              focusNode: _focusNode,
              scrollController: _scrollController,
              config: quill.QuillEditorConfig(
                minHeight: 130,
                maxHeight: 320,
                padding: const EdgeInsets.all(12),
                placeholder: context.tr('What would you like to share?'),
                customStyleBuilder: (attribute) {
                  if (attribute.key == 'link' &&
                      attribute.value.toString().startsWith('wicchu://user/')) {
                    final primary = Theme.of(context).colorScheme.primary;
                    return TextStyle(
                      color: primary,
                      backgroundColor: primary.withValues(alpha: .1),
                      decoration: TextDecoration.none,
                      fontWeight: FontWeight.w500,
                    );
                  }
                  return const TextStyle();
                },
                textCapitalization: TextCapitalization.sentences,
                embedBuilders: const [_PostImageEmbed()],
              ),
            ),
            ListenableBuilder(
              listenable: controller,
              builder: (context, _) => _videoPreview(context),
            ),
            Divider(
              height: 1,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.12),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
              child: PostFormatToolbar(controller: controller.quillController),
            ),
            ListenableBuilder(
              listenable: controller.quillController,
              builder: (context, _) => Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: controller.exceedsCharacterLimit
                          ? Text(
                              context.tr('Use at most {count} characters.', {
                                'count': '${PostTextController.maxCharacters}',
                              }),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${controller.characterCount}/${PostTextController.maxCharacters}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: controller.exceedsCharacterLimit
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Legacy Markdown images remain visible when editing existing posts.
class _PostImageEmbed extends quill.EmbedBuilder {
  const _PostImageEmbed();
  @override
  String get key => 'image';

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final url = embedContext.node.value.data.toString();
    return Image.network(
      url,
      height: 160,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => const Icon(WicchuIcons.imageBroken),
    );
  }
}
