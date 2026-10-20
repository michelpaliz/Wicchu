import 'package:flutter/material.dart';

import '../domain/community_models.dart';

/// Shared read-only presentation for rules, previews and posting review.
class CommunityRulesList extends StatelessWidget {
  const CommunityRulesList({super.key, required this.rules});
  final List<CommunityRule> rules;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        for (final (index, rule) in rules.indexed) ...[
          if (index > 0) Divider(color: theme.dividerColor),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${index + 1}'.padLeft(2, '0'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rule.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (rule.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          rule.description,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
