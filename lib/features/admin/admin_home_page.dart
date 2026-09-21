import 'package:flutter/material.dart';

import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';
import 'admin_dashboard_page.dart';
import 'create_community_page.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key, required this.repository});

  final CommunityRepository repository;

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  Community? _community;

  @override
  Widget build(BuildContext context) {
    if (_community case final community?) {
      return AdminDashboardPage(
        community: community,
        repository: widget.repository,
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Wicchu')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.people_alt_rounded,
                size: 68,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 20),
              Text(
                context.tr('Bring your community together'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              Text(
                context.tr(
                  'Create an organized place for local news, jobs, events and conversations.',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: Text(context.tr('Create a community')),
                onPressed: _createCommunity,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createCommunity() async {
    final community = await Navigator.push<Community>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateCommunityPage(repository: widget.repository),
      ),
    );
    if (community != null) setState(() => _community = community);
  }
}
