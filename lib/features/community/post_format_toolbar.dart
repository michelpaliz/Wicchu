import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

/// Uses document attributes rather than inserting visible Markdown symbols.
class PostFormatToolbar extends StatelessWidget {
  const PostFormatToolbar({super.key, required this.controller});
  final quill.QuillController controller;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        quill.QuillToolbarToggleStyleButton(
          controller: controller,
          attribute: quill.Attribute.bold,
        ),
        quill.QuillToolbarToggleStyleButton(
          controller: controller,
          attribute: quill.Attribute.italic,
        ),
        quill.QuillToolbarToggleStyleButton(
          controller: controller,
          attribute: quill.Attribute.ul,
        ),
        quill.QuillToolbarToggleStyleButton(
          controller: controller,
          attribute: quill.Attribute.ol,
        ),
        quill.QuillToolbarLinkStyleButton(controller: controller),
        quill.QuillToolbarHistoryButton(controller: controller, isUndo: true),
        quill.QuillToolbarHistoryButton(controller: controller, isUndo: false),
      ],
    ),
  );
}
