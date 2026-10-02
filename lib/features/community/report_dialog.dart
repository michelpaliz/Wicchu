import 'package:flutter/material.dart';

import '../../localization/app_language.dart';

Future<(String, String)?> showContentReportDialog(
  BuildContext context, {
  required String title,
}) => showModalBottomSheet<(String, String)>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  constraints: const BoxConstraints(maxWidth: 640),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  ),
  clipBehavior: Clip.antiAlias,
  builder: (_) => _ReportSheet(title: title),
);

const _categories = <String, (String, IconData)>{
  'spam': ('Spam', Icons.block_outlined),
  'harassment': ('Harassment', Icons.people_outline),
  'scam': ('Scam or fraud', Icons.warning_amber_rounded),
  'other': ('Other concern', Icons.more_horiz),
  'hate': ('Hate speech', Icons.comments_disabled_outlined),
  'violence': ('Violence', Icons.shield_outlined),
  'sexual': ('Sexual content', Icons.hide_image_outlined),
  'child_safety': ('Child safety', Icons.child_care_outlined),
  'self_harm': ('Self-harm', Icons.health_and_safety_outlined),
  'illegal': ('Illegal activity', Icons.gavel_outlined),
};

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({required this.title});
  final String title;
  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  final _details = TextEditingController();
  String _category = 'spam';

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: colors.errorContainer,
                  foregroundColor: colors.error,
                  child: const Icon(Icons.outlined_flag, size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    context.tr(widget.title),
                    style: text.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              context.tr('Tell us what is wrong. Reports are confidential.'),
              style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            Text(
              context.tr('Report to'),
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: .07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.primary.withValues(alpha: .3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined, color: colors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.tr(
                        'Reports are routed to community moderators or Wicchu Safety as appropriate.',
                      ),
                      style: text.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              context.tr('Report category'),
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns =
                    constraints.maxWidth < 300 ||
                        MediaQuery.textScalerOf(context).scale(14) > 20
                    ? 1
                    : 2;
                final width =
                    (constraints.maxWidth - (columns - 1) * 8) / columns;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in _categories.entries)
                      SizedBox(
                        width: width,
                        child: Semantics(
                          selected: _category == item.key,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 52),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              foregroundColor: _category == item.key
                                  ? colors.primary
                                  : colors.onSurface,
                              backgroundColor: _category == item.key
                                  ? colors.primary.withValues(alpha: .09)
                                  : null,
                              side: BorderSide(
                                color: _category == item.key
                                    ? colors.primary
                                    : colors.outlineVariant,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () =>
                                setState(() => _category = item.key),
                            child: Row(
                              children: [
                                Icon(item.value.$2, size: 22),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(context.tr(item.value.$1)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            Text(
              context.tr('Additional details (optional)'),
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _details,
              maxLength: 500,
              minLines: 3,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: context.tr('Describe the concern'),
                filled: true,
                fillColor: colors.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(context.tr('Cancel')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.error,
                      foregroundColor: colors.onError,
                    ),
                    onPressed: () {
                      final details = _details.text.trim();
                      Navigator.pop(context, (
                        details.isEmpty
                            ? context.tr(_categories[_category]!.$1)
                            : details,
                        _category,
                      ));
                    },
                    icon: const Icon(Icons.send_outlined, size: 20),
                    label: Text(context.tr('Submit report')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
