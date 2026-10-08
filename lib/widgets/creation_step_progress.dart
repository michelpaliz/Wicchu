import 'package:flutter/material.dart';
import '../localization/app_language.dart';

/// Shared progress header for the post and space creation flows.
class CreationStepProgress extends StatelessWidget {
  const CreationStepProgress({super.key, required this.step, this.total = 4})
    : assert(step >= 0 && step < total);

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('Step {current} of {total}', {
            'current': '${step + 1}',
            'total': '$total',
          }),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: (step + 1) / total,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    ),
  );
}
