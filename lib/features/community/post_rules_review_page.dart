import 'package:flutter/material.dart';

import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';

/// Explicit rules review before entering the community post composer.
class PostRulesReviewPage extends StatefulWidget {
  const PostRulesReviewPage({
    super.key,
    required this.community,
    required this.repository,
  });
  final Community community;
  final CommunityRepository repository;

  @override
  State<PostRulesReviewPage> createState() => _PostRulesReviewPageState();
}

class _PostRulesReviewPageState extends State<PostRulesReviewPage> {
  late Future<CommunityRules> _rules = widget.repository.listRules(
    widget.community.id,
  );
  bool _saving = false;

  Future<void> _continue(CommunityRules rules) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      if (rules.acceptanceRequired) {
        await widget.repository.acceptRules(
          widget.community.id,
          rules.rulesVersion,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('Community rules'))),
    body: FutureBuilder<CommunityRules>(
      future: _rules,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.trError(snapshot.error!),
                    textAlign: TextAlign.center,
                  ),
                  TextButton(
                    onPressed: () => setState(
                      () => _rules = widget.repository.listRules(
                        widget.community.id,
                      ),
                    ),
                    child: Text(context.tr('Retry')),
                  ),
                ],
              ),
            ),
          );
        }
        final rules = snapshot.data!;
        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    widget.community.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr(
                      rules.rules.isEmpty
                          ? 'No community rules have been added yet.'
                          : 'Before posting, read and agree to the community rules.',
                    ),
                  ),
                  const SizedBox(height: 20),
                  for (final (index, rule) in rules.rules.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(radius: 17, child: Text('${index + 1}')),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  rule.title,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                if (rule.description.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    rule.description,
                                    style: const TextStyle(height: 1.5),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : () => _continue(rules),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_forward),
                    label: Text(
                      context.tr(
                        rules.rules.isEmpty ? 'Continue' : 'Agree and continue',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
