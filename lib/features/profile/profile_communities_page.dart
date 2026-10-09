import 'package:flutter/material.dart';
import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';
import '../../theme/wicchu_icons.dart';
import '../../widgets/explore_result_card.dart';
import '../community/community_avatar.dart';
import '../community/community_profile_page.dart';

class ProfileCommunitiesPage extends StatefulWidget {
  const ProfileCommunitiesPage({super.key, required this.repository});
  final CommunityRepository repository;
  @override
  State<ProfileCommunitiesPage> createState() => _ProfileCommunitiesPageState();
}

class _ProfileCommunitiesPageState extends State<ProfileCommunitiesPage> {
  late Future<List<Community>> _communities = widget.repository
      .listJoinedCommunities();
  Future<void> _refresh() async {
    final request = widget.repository.listJoinedCommunities();
    setState(() => _communities = request);
    try {
      await request;
    } catch (_) {
      /* The error state offers retry. */
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('Communities'))),
    body: FutureBuilder<List<Community>>(
      future: _communities,
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
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(WicchuIcons.arrowsClockwise),
                    label: Text(context.tr('Retry')),
                  ),
                ],
              ),
            ),
          );
        }
        final communities = snapshot.data ?? const <Community>[];
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: communities.isEmpty ? 1 : communities.length,
            itemBuilder: (context, index) {
              if (communities.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    context.tr('No communities found'),
                    textAlign: TextAlign.center,
                  ),
                );
              }
              final community = communities[index];
              return ExploreResultCard(
                margin: const EdgeInsets.only(bottom: 9),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 6,
                  ),
                  leading: CommunityAvatar(community: community, radius: 23),
                  title: Text(
                    community.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '${community.town.name} · ${context.trCount(community.memberCount, singular: community.isPublicProfile ? '{count} follower' : '{count} member', plural: community.isPublicProfile ? '{count} followers' : '{count} members')}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: const Icon(WicchuIcons.caretRight, size: 18),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CommunityProfilePage(
                          community: community,
                          repository: widget.repository,
                        ),
                      ),
                    );
                    if (mounted) await _refresh();
                  },
                ),
              );
            },
          ),
        );
      },
    ),
  );
}
