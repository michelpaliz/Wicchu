import 'package:flutter/material.dart';

class PostFormatToolbar extends StatelessWidget {
  const PostFormatToolbar({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        IconButton(
          tooltip: 'Bold',
          onPressed: () => _wrap('**', '**', 'bold text'),
          icon: const Icon(Icons.format_bold),
        ),
        IconButton(
          tooltip: 'Italic',
          onPressed: () => _wrap('*', '*', 'italic text'),
          icon: const Icon(Icons.format_italic),
        ),
        IconButton(
          tooltip: 'Bulleted list',
          onPressed: () => _prefixLines((_) => '- '),
          icon: const Icon(Icons.format_list_bulleted),
        ),
        IconButton(
          tooltip: 'Numbered list',
          onPressed: () => _prefixLines((index) => '${index + 1}. '),
          icon: const Icon(Icons.format_list_numbered),
        ),
        IconButton(
          tooltip: 'Link',
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

  void _prefixLines(String Function(int index) prefix) {
    final selection = _selection;
    final selected = selection.isCollapsed
        ? 'List item'
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
    final href = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add link'),
        content: TextField(
          controller: url,
          keyboardType: TextInputType.url,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Web address'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, url.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    url.dispose();
    final uri = Uri.tryParse(href ?? '');
    if (uri == null || !{'http', 'https'}.contains(uri.scheme)) return;
    final selection = _selection;
    final label = selection.isCollapsed
        ? 'link text'
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
