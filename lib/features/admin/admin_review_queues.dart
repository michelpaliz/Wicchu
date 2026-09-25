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
          children: [
            for (final item in snapshot.data!)
              Card(
                child: ListTile(
                  title: Text(item.reason),
                  subtitle: Text(
                    context.tr('Post {id}', {'id': item.targetId}),
                  ),
                  trailing: Wrap(
                    children: [
                      TextButton(
                        onPressed: () => decide(item, false),
                        child: Text(context.tr('Dismiss')),
                      ),
                      FilledButton(
                        onPressed: () => decide(item, true),
                        child: Text(context.tr('Remove post')),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
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
