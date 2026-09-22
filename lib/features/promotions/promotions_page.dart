import 'package:flutter/material.dart';

import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';

class PromotionsPage extends StatefulWidget {
  const PromotionsPage({super.key, required this.repository});

  final CommunityRepository repository;

  @override
  State<PromotionsPage> createState() => _PromotionsPageState();
}

class _PromotionData {
  const _PromotionData(this.eligibility, this.campaigns, this.posts);
  final PromotionEligibility eligibility;
  final List<PromotionCampaign> campaigns;
  final List<CommunityPost> posts;
}

class _PromotionsPageState extends State<PromotionsPage> {
  late Future<_PromotionData> _data = _load();
  bool _submitting = false;

  Future<_PromotionData> _load() async {
    final results = await Future.wait([
      widget.repository.getPromotionEligibility(),
      widget.repository.listMyPromotions(),
      widget.repository.listMyPosts(),
    ]);
    return _PromotionData(
      results[0] as PromotionEligibility,
      results[1] as List<PromotionCampaign>,
      results[2] as List<CommunityPost>,
    );
  }

  void _reload() => setState(() => _data = _load());

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('Promote locally'))),
    body: FutureBuilder<_PromotionData>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: FilledButton.icon(
              onPressed: _reload,
              icon: const Icon(Icons.refresh),
              label: Text(context.trError(snapshot.error!)),
            ),
          );
        }
        final data = snapshot.data!;
        return RefreshIndicator(
          onRefresh: () async {
            _reload();
            await _data;
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              _TrialCard(eligibility: data.eligibility),
              const SizedBox(height: 16),
              if (data.eligibility.eligible &&
                  data.eligibility.activeCampaignId == null)
                FilledButton.icon(
                  onPressed: _submitting || data.posts.isEmpty
                      ? null
                      : () => _startPromotion(data),
                  icon: const Icon(Icons.campaign_outlined),
                  label: Text(context.tr('Promote a post for free')),
                ),
              if (data.posts.isEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  context.tr('Publish a post before creating a promotion.'),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 28),
              Text(
                context.tr('Your promotions'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              if (data.campaigns.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      context.tr('You have not promoted a post yet.'),
                    ),
                  ),
                )
              else
                for (final campaign in data.campaigns)
                  _CampaignCard(
                    campaign: campaign,
                    onCancel:
                        campaign.status == PromotionStatus.pending ||
                            campaign.status == PromotionStatus.active
                        ? () => _cancel(campaign.id)
                        : null,
                  ),
            ],
          ),
        );
      },
    ),
  );

  Future<void> _startPromotion(_PromotionData data) async {
    var postId = data.posts.first.id;
    var duration = data.eligibility.maxCampaignDays;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.tr('Promote locally')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(context.tr('Choose one of your published posts.')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: postId,
                isExpanded: true,
                items: [
                  for (final post in data.posts)
                    DropdownMenuItem(
                      value: post.id,
                      child: Text(
                        post.text.replaceAll('\n', ' '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => setDialogState(() => postId = value!),
                decoration: InputDecoration(labelText: context.tr('Post')),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: duration,
                items: [
                  for (
                    var day = 1;
                    day <= data.eligibility.maxCampaignDays;
                    day++
                  )
                    DropdownMenuItem(
                      value: day,
                      child: Text(
                        context.tr('{count} days', {'count': '$day'}),
                      ),
                    ),
                ],
                onChanged: (value) => setDialogState(() => duration = value!),
                decoration: InputDecoration(labelText: context.tr('Duration')),
              ),
              const SizedBox(height: 12),
              Text(
                context.tr(
                  'Every promotion is marked Sponsored and requires community approval. No payment is required during the pilot.',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.tr('Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(context.tr('Submit for approval')),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    setState(() => _submitting = true);
    try {
      await widget.repository.createPromotion(postId, durationDays: duration);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Promotion submitted for approval.')),
          ),
        );
        _reload();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _cancel(String id) async {
    try {
      await widget.repository.cancelPromotion(id);
      if (mounted) _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    }
  }
}

class _TrialCard extends StatelessWidget {
  const _TrialCard({required this.eligibility});
  final PromotionEligibility eligibility;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.primaryContainer,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.storefront_outlined, size: 38),
          const SizedBox(height: 12),
          Text(
            context.tr('Your first month is free'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            context.tr(
              'Help local people discover your business, event, service or useful announcement.',
            ),
          ),
          const SizedBox(height: 12),
          Text(context.tr('• One active promotion at a time')),
          Text(context.tr('• Up to 7 days per promotion')),
          Text(context.tr('• One town during your free month')),
          Text(context.tr('• No automatic charge afterward')),
          if (eligibility.expiresAt case final expiresAt?) ...[
            const SizedBox(height: 12),
            Text(
              '${context.tr('Trial ends')}: ${MaterialLocalizations.of(context).formatMediumDate(expiresAt.toLocal())}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
          if (!eligibility.eligible) ...[
            const SizedBox(height: 12),
            Text(
              context.tr('Your free promotion month has ended.'),
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _CampaignCard extends StatelessWidget {
  const _CampaignCard({required this.campaign, this.onCancel});
  final PromotionCampaign campaign;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Chip(label: Text(context.tr(campaign.status.name))),
              const Spacer(),
              Text(
                context.tr('{count} days', {
                  'count': '${campaign.durationDays}',
                }),
              ),
            ],
          ),
          Text('${context.tr('Post')}: ${campaign.postId}'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: context.tr('Impressions'),
                  value: campaign.impressionCount,
                ),
              ),
              Expanded(
                child: _Metric(
                  label: context.tr('Post opens'),
                  value: campaign.clickCount,
                ),
              ),
            ],
          ),
          if (campaign.rejectionReason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(campaign.rejectionReason),
          ],
          if (onCancel != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onCancel,
                child: Text(context.tr('Cancel promotion')),
              ),
            ),
        ],
      ),
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text('$value', style: Theme.of(context).textTheme.headlineSmall),
      Text(label),
    ],
  );
}
