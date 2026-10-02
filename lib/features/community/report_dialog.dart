import 'package:flutter/material.dart';

import '../../localization/app_language.dart';

Future<(String, String)?> showContentReportDialog(
  BuildContext context, {
  required String title,
}) async {
  final controller = TextEditingController();
  var category = 'other';
  final report = await showDialog<(String, String)>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(dialogContext.tr(title)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: InputDecoration(
                labelText: dialogContext.tr('Report category'),
              ),
              items:
                  const {
                        'spam': 'Spam',
                        'harassment': 'Harassment',
                        'hate': 'Hate speech',
                        'violence': 'Violence',
                        'sexual': 'Sexual content',
                        'child_safety': 'Child safety',
                        'self_harm': 'Self-harm',
                        'scam': 'Scam or fraud',
                        'illegal': 'Illegal activity',
                        'other': 'Other concern',
                      }.entries
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.key,
                          child: Text(dialogContext.tr(item.value)),
                        ),
                      )
                      .toList(growable: false),
              onChanged: (value) =>
                  setDialogState(() => category = value ?? 'other'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLength: 1000,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: dialogContext.tr('Describe the concern'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(dialogContext.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () {
              final reason = controller.text.trim();
              if (reason.isNotEmpty) {
                Navigator.pop(dialogContext, (reason, category));
              }
            },
            child: Text(dialogContext.tr('Report')),
          ),
        ],
      ),
    ),
  );
  controller.dispose();
  return report;
}
