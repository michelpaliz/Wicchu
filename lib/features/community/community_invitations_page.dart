import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';

class CommunityInvitationsPage extends StatefulWidget {
  const CommunityInvitationsPage({super.key, required this.community, required this.repository});
  final Community community;
  final CommunityRepository repository;

  @override
  State<CommunityInvitationsPage> createState() => _CommunityInvitationsPageState();
}

class _CommunityInvitationsPageState extends State<CommunityInvitationsPage> {
  final _email = TextEditingController();
  late Future<List<CommunityInvitation>> _items = _load();
  bool _sending = false;

  Future<List<CommunityInvitation>> _load() =>
      widget.repository.listCommunityInvitations(widget.community.id);

  @override
  void dispose() { _email.dispose(); super.dispose(); }

  Future<void> _invite() async {
    if (_email.text.trim().isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final invitation = await widget.repository.createCommunityInvitation(
        widget.community.id, _email.text.trim(),
      );
      _email.clear();
      if (!mounted) return;
      setState(() => _items = _load());
      final url = invitation.invitationUrl;
      if (url != null) {
        await SharePlus.instance.share(ShareParams(
          subject: context.tr('Join {community} on Wicchu', {'community': widget.community.name}),
          text: '${context.tr('Join {community} on Wicchu:', {'community': widget.community.name})} $url',
        ));
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.trError(error))));
    } finally { if (mounted) setState(() => _sending = false); }
  }

  Future<void> _shareLink() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final invitation = await widget.repository.createCommunityInvitationLink(widget.community.id);
      if (!mounted) return;
      setState(() => _items = _load());
      final url = invitation.invitationUrl;
      if (url != null) {
        await SharePlus.instance.share(ShareParams(
          subject: context.tr('Join {community} on Wicchu', {'community': widget.community.name}),
          text: '${context.tr('Join {community} on Wicchu:', {'community': widget.community.name})} $url',
        ));
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.trError(error))));
    } finally { if (mounted) setState(() => _sending = false); }
  }

  Future<void> _revoke(CommunityInvitation invitation) async {
    try {
      await widget.repository.revokeCommunityInvitation(widget.community.id, invitation.id);
      if (mounted) setState(() => _items = _load());
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.trError(error))));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('Invitations'))),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      Text(context.tr('Invite people'), style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      Text(context.tr('Invitations expire after 14 days. Invited members join directly.')),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: _sending ? null : _shareLink,
        icon: const Icon(Icons.link),
        label: Text(context.tr('Create and share invitation link')),
      ),
      const SizedBox(height: 24),
      Text(context.tr('Or invite a specific person by email'), style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 16),
      TextField(
        controller: _email, keyboardType: TextInputType.emailAddress,
        decoration: InputDecoration(labelText: context.tr('Email address'), border: const OutlineInputBorder()),
        onSubmitted: (_) => _invite(),
      ),
      const SizedBox(height: 12),
      FilledButton.icon(onPressed: _sending ? null : _invite, icon: const Icon(Icons.send_outlined), label: Text(context.tr('Send invitation'))),
      const SizedBox(height: 28),
      Text(context.tr('Invitation history'), style: Theme.of(context).textTheme.titleLarge),
      FutureBuilder<List<CommunityInvitation>>(
        future: _items,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
          if (snapshot.hasError) return ListTile(title: Text(context.trError(snapshot.error!)), trailing: IconButton(icon: const Icon(Icons.refresh), onPressed: () => setState(() => _items = _load())));
          final items = snapshot.data ?? const [];
          if (items.isEmpty) return ListTile(title: Text(context.tr('No invitations yet')));
          return Column(children: items.map((item) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(item.isLink ? Icons.link : Icons.mail_outline),
            title: Text(item.isLink ? context.tr('Shareable invitation link') : (item.email ?? context.tr('Invitation'))),
            subtitle: Text(context.tr(item.status)),
            trailing: item.status == 'pending' ? IconButton(tooltip: context.tr('Revoke'), icon: const Icon(Icons.cancel_outlined), onPressed: () => _revoke(item)) : null,
          )).toList());
        },
      ),
    ]),
  );
}

class CommunityInvitationLinkPage extends StatefulWidget {
  const CommunityInvitationLinkPage({super.key, required this.token, required this.repository});
  final String token;
  final CommunityRepository repository;

  @override
  State<CommunityInvitationLinkPage> createState() => _CommunityInvitationLinkPageState();
}

class _CommunityInvitationLinkPageState extends State<CommunityInvitationLinkPage> {
  late final Future<CommunityInvitation> _invitation = widget.repository.getCommunityInvitationLink(widget.token);
  bool _responding = false;

  Future<void> _respond(bool accept) async {
    if (_responding) return;
    setState(() => _responding = true);
    try {
      await widget.repository.respondToCommunityInvitationLink(widget.token, accept: accept);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.tr(accept ? 'You joined the community.' : 'Invitation declined.')),
      ));
      Navigator.pop(context, accept);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.trError(error))));
    } finally { if (mounted) setState(() => _responding = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('Community invitation'))),
    body: FutureBuilder<CommunityInvitation>(
      future: _invitation,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) {
          return Center(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(context.trError(snapshot.error!), textAlign: TextAlign.center),
        ));
        }
        final invitation = snapshot.data!;
        return Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const CircleAvatar(radius: 38, child: Icon(Icons.groups_outlined, size: 38)),
              const SizedBox(height: 18),
              Text(invitation.communityName ?? context.tr('Community'), style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(context.tr('You were invited to join this community.'), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: _responding ? null : () => _respond(false), child: Text(context.tr('Decline')))),
                const SizedBox(width: 12),
                Expanded(child: FilledButton(onPressed: _responding ? null : () => _respond(true), child: Text(context.tr('Join')))),
              ]),
            ]),
          ),
        ));
      },
    ),
  );
}

class MyCommunityInvitationsPage extends StatefulWidget {
  const MyCommunityInvitationsPage({super.key, required this.repository});
  final CommunityRepository repository;
  @override
  State<MyCommunityInvitationsPage> createState() => _MyCommunityInvitationsPageState();
}

class _MyCommunityInvitationsPageState extends State<MyCommunityInvitationsPage> {
  late Future<List<CommunityInvitation>> _items = widget.repository.listMyCommunityInvitations();

  Future<void> _respond(CommunityInvitation invitation, bool accept) async {
    try {
      await widget.repository.respondToCommunityInvitation(invitation.id, accept: accept);
      if (mounted) setState(() => _items = widget.repository.listMyCommunityInvitations());
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.trError(error))));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('Invitations'))),
    body: FutureBuilder<List<CommunityInvitation>>(
      future: _items,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text(context.trError(snapshot.error!)));
        final items = snapshot.data ?? const [];
        if (items.isEmpty) return Center(child: Text(context.tr('No pending invitations')));
        return ListView.separated(
          padding: const EdgeInsets.all(20), itemCount: items.length, separatorBuilder: (_, _) => const Divider(),
          itemBuilder: (context, index) {
            final item = items[index];
            return ListTile(
              contentPadding: EdgeInsets.zero, leading: const CircleAvatar(child: Icon(Icons.groups_outlined)),
              title: Text(item.communityName ?? context.tr('Community')),
              subtitle: Text(context.tr('You were invited to join this community.')),
              trailing: Wrap(spacing: 4, children: [
                TextButton(onPressed: () => _respond(item, false), child: Text(context.tr('Decline'))),
                FilledButton(onPressed: () => _respond(item, true), child: Text(context.tr('Accept'))),
              ]),
            );
          },
        );
      },
    ),
  );
}
