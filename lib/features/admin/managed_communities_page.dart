import 'package:flutter/material.dart';

import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';
import '../community/community_avatar.dart';
import 'admin_dashboard_page.dart';
import 'create_community_page.dart';

class ManagedCommunitiesPage extends StatefulWidget {
  const ManagedCommunitiesPage({
    super.key,
    required this.repository,
    required this.onCommunityCreated,
  });
  final CommunityRepository repository;
  final VoidCallback onCommunityCreated;

  @override
  State<ManagedCommunitiesPage> createState() => _ManagedCommunitiesPageState();
}

class _ManagedCommunitiesPageState extends State<ManagedCommunitiesPage> {
  late Future<List<Community>> _communities = widget.repository
      .listManagedCommunities();
  final _summaries = <String, Future<AdminAttentionSummary>>{};
  bool _showTip = true;

  Future<void> _refresh() async {
    setState(() {
      _summaries.clear();
      _communities = widget.repository.listManagedCommunities();
    });
    try {
      await _communities;
    } catch (_) {}
  }

  Future<void> _open(Community community) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminDashboardPage(
          community: community,
          repository: widget.repository,
        ),
      ),
    );
    if (mounted) await _refresh();
  }

  Future<void> _create() async {
    final community = await Navigator.push<Community>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateCommunityPage(repository: widget.repository),
      ),
    );
    if (!mounted || community == null) return;
    widget.onCommunityCreated();
    await _refresh();
    if (mounted) await _open(community);
  }

  Widget _status(Community community) => FutureBuilder<AdminAttentionSummary>(
    future: _summaries.putIfAbsent(
      community.id,
      () => widget.repository.getAdminAttention(community.id),
    ),
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return Text(
          context.tr('Checking pending work…'),
          style: Theme.of(context).textTheme.bodySmall,
        );
      }
      if (snapshot.hasError || !snapshot.hasData) {
        return TextButton.icon(
          onPressed: () => setState(() {
            _summaries.remove(community.id);
          }),
          icon: const Icon(Icons.refresh, size: 16),
          label: Text(context.tr('Retry status')),
        );
      }
      final summary = snapshot.data!;
      final count =
          summary.pendingPosts +
          summary.openReports +
          summary.pendingPromotions +
          (community.myRole == CommunityRole.owner ||
                  community.myRole == CommunityRole.admin
              ? summary.membershipRequests
              : 0);
      return Row(
        children: [
          Icon(
            count == 0 ? Icons.check_circle : Icons.pending_actions_outlined,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              count == 0
                  ? context.tr('All caught up')
                  : context.trCount(
                      count,
                      singular: '{count} pending action',
                      plural: '{count} pending actions',
                    ),
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Communities I manage'))),
      body: FutureBuilder<List<Community>>(
        future: _communities,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(context.trError(snapshot.error!)),
                  ),
                  OutlinedButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                    label: Text(context.tr('Retry')),
                  ),
                ],
              ),
            );
          }
          final communities = snapshot.data ?? const <Community>[];
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.trCount(
                              communities.length,
                              singular: '{count} community',
                              plural: '{count} communities',
                            ),
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            context.tr(
                              'Manage the communities you administer.',
                            ),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(96, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _create,
                      icon: const Icon(Icons.add),
                      label: Text(context.tr('Create')),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (communities.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      context.tr(
                        'You don’t manage any communities yet. Create one to get started.',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                for (final community in communities)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: colors.surface,
                      elevation: 2,
                      shadowColor: colors.shadow.withValues(alpha: 0.12),
                      surfaceTintColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _open(community),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 16,
                          ),
                          child: Row(
                            children: [
                              CommunityAvatar(community: community, radius: 34),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      community.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 20,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.groups_outlined,
                                          size: 18,
                                          color: colors.onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            context.trCount(
                                              community.memberCount,
                                              singular: '{count} member',
                                              plural: '{count} members',
                                            ),
                                            style: TextStyle(
                                              color: colors.onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    _status(community),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_showTip) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: colors.primary.withValues(
                            alpha: 0.09,
                          ),
                          child: Icon(
                            Icons.lightbulb_outline,
                            color: colors.primary,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr('Tip'),
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: colors.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                context.tr(
                                  'Keep your community active by reviewing posts and membership requests regularly.',
                                ),
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: colors.onSurfaceVariant,
                                      height: 1.4,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          style: IconButton.styleFrom(
                            foregroundColor: colors.primary,
                            visualDensity: VisualDensity.compact,
                          ),
                          tooltip: context.tr('Close'),
                          onPressed: () => setState(() => _showTip = false),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
