import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:markdown/markdown.dart' as md;
import 'package:markdown_quill/markdown_quill.dart';

import '../../localization/app_language.dart';
import 'post_format_toolbar.dart';

/// Keeps visual editing separate from the Markdown API contract.
class PostTextController extends quill.QuillController {
  PostTextController(this.originalText)
    : super(
        document: originalText.isEmpty
            ? quill.Document()
            : quill.Document.fromDelta(
                MarkdownToDelta(
                  markdownDocument: md.Document(
                    encodeHtml: false,
                    extensionSet: md.ExtensionSet.gitHubFlavored,
                  ),
                ).convert(originalText),
              ),
        selection: const TextSelection.collapsed(offset: 0),
      ) {
    _originalDelta = jsonEncode(document.toDelta().toJson());
  }

  final String originalText;
  late final String _originalDelta;

  String get text {
    final delta = document.toDelta();
    // Editing another field must not rewrite a post's existing Markdown.
    if (jsonEncode(delta.toJson()) == _originalDelta) return originalText;
    if (document.toPlainText().trim().isEmpty) return '';
    return DeltaToMarkdown().convert(delta).trimRight();
  }

  void insertMention(String userId, String name) {
    final offset = selection.baseOffset.clamp(0, document.length - 1);
    final label = '@$name';
    document.insert(offset, '$label ');
    formatText(
      offset,
      label.length,
      quill.LinkAttribute('wicchu://user/$userId'),
    );
    updateSelection(
      TextSelection.collapsed(offset: offset + label.length + 1),
      quill.ChangeSource.local,
    );
  }
}

class PostRichTextEditor extends StatelessWidget {
  const PostRichTextEditor({super.key, required this.controller});
  final PostTextController controller;

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
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: PostFormatToolbar(controller: controller),
            ),
            Divider(
              height: 1,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.12),
            ),
            quill.QuillEditor.basic(
              controller: controller,
              config: quill.QuillEditorConfig(
                minHeight: 150,
                maxHeight: 320,
                padding: const EdgeInsets.all(18),
                placeholder: context.tr('What would you like to share?'),
                textCapitalization: TextCapitalization.sentences,
                embedBuilders: const [_PostImageEmbed()],
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
      errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
    );
  }
}
