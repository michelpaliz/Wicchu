import 'package:flutter/material.dart';

import '../../localization/app_language.dart';

class PostFormatToolbar extends StatelessWidget {
  const PostFormatToolbar({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        IconButton(
          tooltip: context.tr('Bold'),
          onPressed: () => _wrap('**', '**', context.tr('bold text')),
          icon: const Icon(Icons.format_bold),
        ),
        IconButton(
          tooltip: context.tr('Italic'),
          onPressed: () => _wrap('*', '*', context.tr('italic text')),
          icon: const Icon(Icons.format_italic),
        ),
        IconButton(
          tooltip: context.tr('Bulleted list'),
          onPressed: () =>
              _prefixLines((_) => '- ', placeholder: context.tr('List item')),
          icon: const Icon(Icons.format_list_bulleted),
        ),
        IconButton(
          tooltip: context.tr('Numbered list'),
          onPressed: () => _prefixLines(
            (index) => '${index + 1}. ',
            placeholder: context.tr('List item'),
          ),
          icon: const Icon(Icons.format_list_numbered),
        ),
        IconButton(
          tooltip: context.tr('Link'),
          onPressed: () => _insertLink(context),
          icon: const Icon(Icons.link),
        ),
      ],
    ),
  );

  TextSelection get _selection {
    final selection = controller.selection;
    if (!selection.isValid) {
      return TextSelection.collapsed(offset: controller.text.length);
    }
    return selection;
  }

  void _wrap(String before, String after, String placeholder) {
    final selection = _selection;
    final selected = selection.isCollapsed
        ? placeholder
        : controller.text.substring(selection.start, selection.end);
    final replacement = '$before$selected$after';
    controller.value = controller.value
        .replaced(selection, replacement)
        .copyWith(
          selection: TextSelection(
            baseOffset: selection.start + before.length,
            extentOffset: selection.start + before.length + selected.length,
          ),
        );
  }

  void _prefixLines(
    String Function(int index) prefix, {
    required String placeholder,
  }) {
    final selection = _selection;
    final selected = selection.isCollapsed
        ? placeholder
        : controller.text.substring(selection.start, selection.end);
    final replacement = selected
        .split('\n')
        .indexed
        .map((entry) => '${prefix(entry.$1)}${entry.$2}')
        .join('\n');
    controller.value = controller.value
        .replaced(selection, replacement)
        .copyWith(
          selection: TextSelection.collapsed(
            offset: selection.start + replacement.length,
          ),
        );
  }

  Future<void> _insertLink(BuildContext context) async {
    final url = TextEditingController(text: 'https://');
    final defaultLinkText = context.tr('link text');
    final href = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Add link')),
        content: TextField(
          controller: url,
          keyboardType: TextInputType.url,
          autofocus: true,
          decoration: InputDecoration(labelText: context.tr('Web address')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, url.text.trim()),
            child: Text(context.tr('Add')),
          ),
        ],
      ),
    );
    url.dispose();
    final uri = Uri.tryParse(href ?? '');
    if (uri == null || !{'http', 'https'}.contains(uri.scheme)) return;
    final selection = _selection;
    final label = selection.isCollapsed
        ? defaultLinkText
        : controller.text.substring(selection.start, selection.end);
    final replacement = '[$label]($uri)';
    controller.value = controller.value
        .replaced(selection, replacement)
        .copyWith(
          selection: TextSelection.collapsed(
            offset: selection.start + replacement.length,
          ),
        );
  }
}
