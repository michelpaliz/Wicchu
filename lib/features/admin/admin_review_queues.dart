import 'package:flutter/material.dart';
import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';

class ReportsQueuePage extends StatefulWidget {
  const ReportsQueuePage({
    super.key,
    required this.community,
    required this.repository,
  });
  final Community community;
  final CommunityRepository repository;
  @override
  State<ReportsQueuePage> createState() => _ReportsQueuePageState();
}

class _ReportsQueuePageState extends State<ReportsQueuePage> {
  late Future<List<CommunityReport>> items = widget.repository.listReports(
    widget.community.id,
  );
  void reload() => items = widget.repository.listReports(widget.community.id);
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('Reports'))),
    body: FutureBuilder<List<CommunityReport>>(
      future: items,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(context.trError(snapshot.error!)));
        }
        if (snapshot.data!.isEmpty) {
          return const _ReportsEmptyState();
        }
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [for (final item in snapshot.data!) _reportCard(item)],
        );
      },
    ),
  );

  Widget _reportCard(CommunityReport item) {
    final theme = Theme.of(context);
    final reporterName = item.reporterName?.trim().isNotEmpty == true
        ? item.reporterName!
        : context.tr('Wicchu member');
    final authorName = item.targetAuthorName?.trim().isNotEmpty == true
        ? item.targetAuthorName!
        : context.tr('Wicchu member');
    final date = MaterialLocalizations.of(
      context,
    ).formatMediumDate(item.createdAt.toLocal());
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundImage: item.reporterAvatarUrl?.isNotEmpty == true
                      ? NetworkImage(item.reporterAvatarUrl!)
                      : null,
                  child: item.reporterAvatarUrl?.isNotEmpty == true
                      ? null
                      : const Icon(Icons.person_outline, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('Reported by {name}', {
                          'name': reporterName,
                        }),
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(date, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                Chip(label: Text(context.tr(_categoryLabel(item.category)))),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr(_targetTitle(item.targetType)),
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(authorName, style: theme.textTheme.titleSmall),
                  if (item.targetText?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 8),
                    Text(item.targetText!),
                  ] else if (item.targetType !=
                      ModerationTargetType.member) ...[
                    const SizedBox(height: 8),
                    Text(
                      context.tr('Reported content is no longer available.'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  if (item.targetMediaCount > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.perm_media_outlined, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          context.tr('{count} media attachments', {
                            'count': '${item.targetMediaCount}',
                          }),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              context.tr('Report reason'),
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Text(item.reason),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => decide(item, false),
                  child: Text(context.tr('Dismiss')),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => decide(item, true),
                  child: Text(context.tr(_resolveLabel(item.targetType))),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> decide(CommunityReport item, bool resolve) async {
    try {
      await widget.repository.decideReport(
        widget.community.id,
        item.id,
        resolve: resolve,
      );
      if (mounted) setState(reload);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    }
  }

  String _categoryLabel(String category) => switch (category) {
    'spam' => 'Spam',
    'harassment' => 'Harassment',
    'hate' => 'Hate speech',
    'violence' => 'Violence',
    'sexual' => 'Sexual content',
    'child_safety' => 'Child safety',
    'self_harm' => 'Self-harm',
    'scam' => 'Scam or fraud',
    'illegal' => 'Illegal activity',
    _ => 'Other concern',
  };

  String _targetTitle(ModerationTargetType type) => switch (type) {
    ModerationTargetType.comment => 'Reported comment',
    ModerationTargetType.member => 'Reported member',
    ModerationTargetType.post => 'Reported post',
  };

  String _resolveLabel(ModerationTargetType type) => switch (type) {
    ModerationTargetType.comment => 'Remove comment',
    ModerationTargetType.member => 'Restrict member',
    ModerationTargetType.post => 'Remove post',
  };
}

class _ReportsEmptyState extends StatelessWidget {
  const _ReportsEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            28,
            24,
            28,
            24 + MediaQuery.paddingOf(context).bottom,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  (constraints.maxHeight -
                          48 -
                          MediaQuery.paddingOf(context).bottom)
                      .clamp(0, double.infinity),
            ),
            child: Align(
              alignment: const Alignment(0, -.35),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ExcludeSemantics(
                      child: SizedBox(
                        width: 220,
                        height: 190,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned(
                              bottom: 0,
                              child: Container(
                                width: 156,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: colors.primary.withValues(alpha: .07),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                              ),
                            ),
                            Container(
                              width: 170,
                              height: 170,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    colors.primary.withValues(alpha: .12),
                                    colors.primary.withValues(alpha: .04),
                                  ],
                                ),
                              ),
                              child: Icon(
                                Icons.verified_user_outlined,
                                size: 110,
                                color: colors.primary,
                              ),
                            ),
                            for (final mark in [
                              (12.0, 34.0, .8),
                              (2.0, 60.0, .25),
                              (194.0, 30.0, -.8),
                              (202.0, 56.0, -.3),
                            ])
                              Positioned(
                                left: mark.$1,
                                top: mark.$2,
                                child: Transform.rotate(
                                  angle: mark.$3,
                                  child: Container(
                                    width: 14,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: colors.primary.withValues(
                                        alpha: .8,
                                      ),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      context.tr('Everything is in order'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.tr(
                        'There are no open reports that need your attention.',
                      ),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      context.tr(
                        'New reports will appear here for you to review.',
                      ),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class MembershipRequestsPage extends StatefulWidget {
  const MembershipRequestsPage({
    super.key,
    required this.community,
    required this.repository,
  });
  final Community community;
  final CommunityRepository repository;
  @override
  State<MembershipRequestsPage> createState() => _MembershipRequestsPageState();
}

class _MembershipRequestsPageState extends State<MembershipRequestsPage> {
  late Future<List<MembershipRequest>> items = widget.repository
      .listMembershipRequests(widget.community.id);
  void reload() =>
      items = widget.repository.listMembershipRequests(widget.community.id);
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('Membership requests'))),
    body: FutureBuilder<List<MembershipRequest>>(
      future: items,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(context.trError(snapshot.error!)));
        }
        if (snapshot.data!.isEmpty) {
          return Center(child: Text(context.tr('No membership requests')));
        }
        return ListView(
          children: [
            for (final item in snapshot.data!)
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text(item.userName),
                trailing: Wrap(
                  children: [
                    TextButton(
                      onPressed: () => decide(item, false),
                      child: Text(context.tr('Reject')),
                    ),
                    FilledButton(
                      onPressed: () => decide(item, true),
                      child: Text(context.tr('Approve')),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    ),
  );
  Future<void> decide(MembershipRequest item, bool approve) async {
    try {
      await widget.repository.decideMembershipRequest(
        widget.community.id,
        item.userId,
        approve: approve,
      );
      if (mounted) setState(reload);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    }
  }
}
