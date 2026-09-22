import 'package:flutter/material.dart';

import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';

class PromotionReviewPage extends StatefulWidget {
  const PromotionReviewPage({
    super.key,
    required this.community,
    required this.repository,
  });

  final Community community;
  final CommunityRepository repository;

  @override
  State<PromotionReviewPage> createState() => _PromotionReviewPageState();
}

class _PromotionReviewPageState extends State<PromotionReviewPage> {
  late Future<List<PromotionCampaign>> _campaigns = _load();
  final _saving = <String>{};

  Future<List<PromotionCampaign>> _load() =>
      widget.repository.listPendingPromotions(widget.community.id);

  void _reload() => setState(() => _campaigns = _load());

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('Promotion requests'))),
    body: FutureBuilder<List<PromotionCampaign>>(
      future: _campaigns,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(context.trError(snapshot.error!)));
        }
        final campaigns = snapshot.data ?? const [];
        if (campaigns.isEmpty) {
          return Center(child: Text(context.tr('No promotion requests.')));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: campaigns.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final campaign = campaigns[index];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.campaign_outlined),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.tr('Free local promotion'),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Text(
                          context.tr('{count} days', {
                            'count': '${campaign.durationDays}',
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FutureBuilder<CommunityPost>(
                      future: widget.repository.getPost(campaign.postId),
                      builder: (context, snapshot) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (snapshot.hasData)
                            Text(
                              snapshot.data!.text,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                            )
                          else if (snapshot.connectionState ==
                              ConnectionState.waiting)
                            const LinearProgressIndicator(),
                          const SizedBox(height: 4),
                          Text(
                            '${context.tr('Post ID')}: ${campaign.postId}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: _saving.contains(campaign.id)
                              ? null
                              : () => _review(campaign, approve: false),
                          child: Text(context.tr('Reject')),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _saving.contains(campaign.id)
                              ? null
                              : () => _review(campaign, approve: true),
                          child: Text(context.tr('Approve')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ),
  );

  Future<void> _review(
    PromotionCampaign campaign, {
    required bool approve,
  }) async {
    String? reason;
    if (!approve) {
      final controller = TextEditingController();
      reason = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(dialogContext.tr('Reject promotion')),
          content: TextField(
            controller: controller,
            maxLength: 1000,
            decoration: InputDecoration(labelText: dialogContext.tr('Reason')),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(dialogContext.tr('Cancel')),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: Text(dialogContext.tr('Reject')),
            ),
          ],
        ),
      );
      controller.dispose();
      if (reason == null) return;
    }
    setState(() => _saving.add(campaign.id));
    try {
      await widget.repository.reviewPromotion(
        widget.community.id,
        campaign.id,
        approve: approve,
        reason: reason,
      );
      if (mounted) _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    } finally {
      if (mounted) setState(() => _saving.remove(campaign.id));
    }
  }
}
