import 'package:wicchu/theme/wicchu_icons.dart';
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
          attribute: quill.Attribute.ul,
        ),
        quill.QuillToolbarLinkStyleButton(controller: controller),
        PopupMenuButton<_SecondaryAction>(
          tooltip: 'More formatting',
          icon: const Icon(WicchuIcons.dotsThree),
          onSelected: (action) => switch (action) {
            _SecondaryAction.italic => controller.formatSelection(
              quill.Attribute.italic,
            ),
            _SecondaryAction.numberedList => controller.formatSelection(
              quill.Attribute.ol,
            ),
            _SecondaryAction.undo => controller.undo(),
            _SecondaryAction.redo => controller.redo(),
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: _SecondaryAction.italic,
              child: ListTile(
                leading: Icon(WicchuIcons.textItalic),
                title: Text('Italic'),
              ),
            ),
            PopupMenuItem(
              value: _SecondaryAction.numberedList,
              child: ListTile(
                leading: Icon(WicchuIcons.listNumbers),
                title: Text('Numbered list'),
              ),
            ),
            PopupMenuItem(
              value: _SecondaryAction.undo,
              child: ListTile(
                leading: Icon(WicchuIcons.arrowArcLeft),
                title: Text('Undo'),
              ),
            ),
            PopupMenuItem(
              value: _SecondaryAction.redo,
              child: ListTile(
                leading: Icon(WicchuIcons.arrowArcRight),
                title: Text('Redo'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

enum _SecondaryAction { italic, numberedList, undo, redo }
