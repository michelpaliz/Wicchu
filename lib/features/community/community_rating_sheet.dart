import 'package:flutter/material.dart';

import '../../domain/community_models.dart';
import '../../localization/app_language.dart';
import '../../theme/wicchu_icons.dart';

class CommunityRatingSheet extends StatefulWidget {
  const CommunityRatingSheet({
    super.key,
    required this.isPage,
    required this.onSubmit,
    this.current,
    this.initialHelpful,
  });

  final bool isPage;
  final CommunitySurveyResponse? current;
  final bool? initialHelpful;
  final Future<CommunityHelpfulness> Function(List<bool> answers) onSubmit;

  @override
  State<CommunityRatingSheet> createState() => _CommunityRatingSheetState();
}

class _CommunityRatingSheetState extends State<CommunityRatingSheet> {
  bool? _binary(String? value) => switch (value) {
    'yes' => true,
    'no' => false,
    _ => null,
  };

  late final List<bool?> _answers = [
    widget.initialHelpful ?? widget.current?.helpful,
    _binary(widget.current?.locallyRelevant),
    _binary(widget.current?.safeParticipation),
    _binary(widget.current?.wellOrganized),
    widget.current?.recommend,
  ];
  bool _saving = false;
  String? _error;

  Future<void> _submit() async {
    if (_saving || _answers.contains(null)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await widget.onSubmit(_answers.cast<bool>());
      if (mounted) {
        setState(() => _saving = false);
        Navigator.pop(context, result);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = context.trError(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final answered = _answers.whereType<bool>().length;
    final questions = [
      widget.isPage ? 'Is this page useful?' : 'Is this community useful?',
      'Is the information relevant locally?',
      'Do you feel safe participating?',
      'Is it well organized?',
      'Would you recommend it to others?',
    ];
    return PopScope(
      canPop: !_saving,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .82,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.tr(
                          widget.isPage
                              ? 'Rate this page'
                              : 'Rate this community',
                        ),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: context.tr('Close'),
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      icon: const Icon(WicchuIcons.x),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('Your feedback helps us improve.'),
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.tr('{count} of 5 answered', {
                        'count': '$answered',
                      }),
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: answered / 5,
                      minHeight: 4,
                      semanticsLabel: context.tr('{count} of 5 answered', {
                        'count': '$answered',
                      }),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  itemCount: questions.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final choices = SegmentedButton<bool>(
                      key: ValueKey('rating-answer-$index'),
                      emptySelectionAllowed: true,
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(
                          value: true,
                          label: Text(context.tr('Yes')),
                        ),
                        ButtonSegment(
                          value: false,
                          label: Text(context.tr('No')),
                        ),
                      ],
                      selected: {if (_answers[index] != null) _answers[index]!},
                      onSelectionChanged: _saving
                          ? null
                          : (values) => setState(
                              () => _answers[index] = values.firstOrNull,
                            ),
                    );
                    return Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final label = Text(
                              context.tr(questions[index]),
                              style: theme.textTheme.bodyMedium,
                            );
                            if (constraints.maxWidth < 300 ||
                                MediaQuery.textScalerOf(context).scale(14) >
                                    18) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  label,
                                  const SizedBox(height: 8),
                                  choices,
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(child: label),
                                const SizedBox(width: 12),
                                choices,
                              ],
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          _error!,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: _saving
                              ? null
                              : () => Navigator.pop(context),
                          child: Text(context.tr('Cancel')),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            key: const ValueKey('rating-submit'),
                            onPressed: answered == 5 && !_saving
                                ? _submit
                                : null,
                            child: _saving
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(context.tr('Send rating')),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
