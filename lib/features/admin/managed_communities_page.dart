import 'package:wicchu/theme/wicchu_icons.dart';
import 'package:flutter/material.dart';

import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';
import '../community/space_collection_list.dart';
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
          icon: const Icon(WicchuIcons.arrowsClockwise, size: 16),
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
            count == 0
                ? WicchuIcons.checkCircleFill
                : WicchuIcons.clipboardText,
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.tr('Spaces I manage')),
      actions: [
        TextButton.icon(
          onPressed: _create,
          icon: const Icon(WicchuIcons.plus, size: 20),
          label: Text(context.tr('Create')),
        ),
        const SizedBox(width: 8),
      ],
    ),
    body: FutureBuilder<List<Community>>(
      future: _communities,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(context.trError(snapshot.error!)),
                TextButton(
                  onPressed: _refresh,
                  child: Text(context.tr('Retry')),
                ),
              ],
            ),
          );
        }
        return SpaceCollectionList(
          spaces: snapshot.data ?? const [],
          onOpen: _open,
          onRefresh: _refresh,
          statusBuilder: _status,
        );
      },
    ),
  );
}
