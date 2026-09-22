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
          return Center(child: Text(context.tr('No open reports')));
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
