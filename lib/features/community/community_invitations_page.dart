import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';

class CommunityInvitationsPage extends StatefulWidget {
  const CommunityInvitationsPage({
    super.key,
    required this.community,
    required this.repository,
  });
  final Community community;
  final CommunityRepository repository;

  @override
  State<CommunityInvitationsPage> createState() =>
      _CommunityInvitationsPageState();
}

class _CommunityInvitationsPageState extends State<CommunityInvitationsPage> {
  final _email = TextEditingController();
  final _form = GlobalKey<FormState>();
  final Map<String, CommunityInvitation> _created = {};
  late Future<List<CommunityInvitation>> _items = _load();
  String? _busy;
  bool _showTip = true;

  Future<List<CommunityInvitation>> _load() async {
    final items = await widget.repository.listCommunityInvitations(
      widget.community.id,
    );
    return items;
  }

  void _reload() => setState(() {
    _items = _load();
  });
  bool _active(CommunityInvitation item) =>
      item.status == 'pending' && item.expiresAt.isAfter(DateTime.now());
  String? _url(CommunityInvitation item) =>
      item.invitationUrl ?? _created[item.id]?.invitationUrl;
  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _error(Object error) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.trError(error))));
    }
  }

  Future<void> _share(CommunityInvitation item) async {
    final url = _url(item);
    if (url == null || !_active(item)) return;
    await SharePlus.instance.share(
      ShareParams(
        subject: context.tr('Join {community} on Wicchu', {
          'community': widget.community.name,
        }),
        text:
            '${context.tr('Join {community} on Wicchu:', {'community': widget.community.name})} $url',
      ),
    );
  }

  Future<void> _shareExisting(CommunityInvitation item) async {
    if (_busy != null) return;
    setState(() => _busy = item.id);
    try {
      await _share(item);
    } catch (error) {
      _error(error);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _copy(CommunityInvitation item) async {
    final url = _url(item);
    if (url == null || !_active(item)) return;
    try {
      await Clipboard.setData(ClipboardData(text: url));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.tr('Link copied'))));
      }
    } catch (error) {
      _error(error);
    }
  }

  Future<void> _invite() async {
    if (_busy != null || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = 'email');
    try {
      final invitation = await widget.repository.createCommunityInvitation(
        widget.community.id,
        _email.text.trim(),
      );
      if (!mounted) return;
      _created[invitation.id] = invitation;
      _email.clear();
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Invitation created.'))),
      );
      // Preserve the existing share flow for email-specific invitation links.
      if (_url(invitation) != null) await _share(invitation);
    } catch (error) {
      _error(error);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _shareLink([CommunityInvitation? current]) async {
    if (_busy != null) return;
    setState(() => _busy = 'link');
    try {
      final invitation =
          current != null && _active(current) && _url(current) != null
          ? current
          : await widget.repository.createCommunityInvitationLink(
              widget.community.id,
            );
      if (!mounted) return;
      _created[invitation.id] = invitation;
      _reload();
      if (_url(invitation) != null) {
        await _share(invitation);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                'The invitation link is unavailable. Please try again.',
              ),
            ),
          ),
        );
      }
    } catch (error) {
      _error(error);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _revoke(CommunityInvitation item) async {
    if (_busy != null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('Revoke invitation?')),
        content: Text(
          context.tr('This invitation will no longer allow people to join.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.tr('Revoke')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = item.id);
    try {
      await widget.repository.revokeCommunityInvitation(
        widget.community.id,
        item.id,
      );
      _created.remove(item.id);
      if (mounted) _reload();
    } catch (error) {
      _error(error);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  String _date(DateTime date) =>
      MaterialLocalizations.of(context).formatShortDate(date.toLocal());
  Widget _icon(IconData icon) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Icon(icon, color: Theme.of(context).colorScheme.primary),
  );
  Widget _card(Widget child) => Card(
    margin: EdgeInsets.zero,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  );
  Widget _spinner() => const SizedBox.square(
    dimension: 18,
    child: CircularProgressIndicator(strokeWidth: 2),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('Invitations'))),
    body: FutureBuilder<List<CommunityInvitation>>(
      future: _items,
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <CommunityInvitation>[];
        final active = items.where(_active).toList();
        final history = items.where((i) => !_active(i)).toList();
        final current = active
            .where((i) => i.isLink && _url(i) != null)
            .firstOrNull;
        final ready =
            snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError;
        final colors = Theme.of(context).colorScheme;
        return ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            24 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: _icon(Icons.groups_outlined),
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('Invite people to {community}', {
                'community': widget.community.name,
              }),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr(
                'Share a link or invite by email. Invitations expire after 14 days.',
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            _card(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      _icon(Icons.link),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('Invitation link'),
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              context.tr(
                                'Invite several people with one link.',
                              ),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      if (current != null)
                        PopupMenuButton<String>(
                          enabled: _busy == null,
                          tooltip: context.tr('Link options'),
                          onSelected: (action) {
                            if (action == 'new') _shareLink();
                            if (action == 'revoke') _revoke(current);
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'new',
                              child: Text(context.tr('Create new link')),
                            ),
                            PopupMenuItem(
                              value: 'revoke',
                              child: Text(context.tr('Revoke')),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _busy != null || !ready
                        ? null
                        : () => _shareLink(current),
                    icon: _busy == 'link'
                        ? _spinner()
                        : const Icon(Icons.share_outlined),
                    label: Text(
                      context.tr(
                        current == null
                            ? 'Create and share invitation link'
                            : 'Share link',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.schedule, color: colors.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            current == null
                                ? context.tr(
                                    'Create a link when you are ready to invite people.',
                                  )
                                : context.tr('Expires on {date}', {
                                    'date': _date(current.expiresAt),
                                  }),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              context.tr('Invite by email'),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _card(
              Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _email,
                      enabled: _busy == null,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.send,
                      autofillHints: const [AutofillHints.email],
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: context.tr('Email address'),
                        prefixIcon: Icon(
                          Icons.mail_outline,
                          color: colors.primary,
                        ),
                      ),
                      validator: (value) =>
                          RegExp(
                            r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                          ).hasMatch(value?.trim() ?? '')
                          ? null
                          : context.tr('Enter a valid email address.'),
                      onFieldSubmitted: (_) => _invite(),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.primary.withValues(alpha: .10),
                        foregroundColor: colors.primary,
                      ),
                      onPressed: _busy == null ? _invite : null,
                      icon: _busy == 'email'
                          ? _spinner()
                          : const Icon(Icons.send_outlined),
                      label: Text(context.tr('Send invitation')),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr('Active invitations'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (ready)
                  Chip(
                    label: Text('${active.length}'),
                    side: BorderSide.none,
                    backgroundColor: colors.primary.withValues(alpha: .10),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(child: CircularProgressIndicator())
            else if (snapshot.hasError)
              _card(
                Column(
                  children: [
                    Text(context.trError(snapshot.error!)),
                    TextButton(
                      onPressed: _reload,
                      child: Text(context.tr('Retry')),
                    ),
                  ],
                ),
              )
            else ...[
              if (active.isEmpty)
                _card(Text(context.tr('No active invitations.'))),
              for (final item in active)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _invitationCard(item),
                ),
              if (history.isNotEmpty)
                ExpansionTile(
                  title: Text(context.tr('Invitation history')),
                  children: [
                    for (final item in history)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _invitationCard(item),
                      ),
                  ],
                ),
            ],
            if (_showTip) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb_outline, color: colors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('Tip'),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.tr(
                              'Share the link with your neighbors, on social media or via WhatsApp.',
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: context.tr('Close'),
                      onPressed: () => setState(() => _showTip = false),
                      icon: const Icon(Icons.close, size: 18),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    ),
  );

  Widget _invitationCard(CommunityInvitation item) {
    final active = _active(item);
    final state = item.status == 'pending' && !active
        ? 'Expired'
        : active
        ? (item.isLink ? 'Active invitation' : 'Pending')
        : item.status;
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _icon(item.isLink ? Icons.link : Icons.mail_outline),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.isLink
                          ? context.tr('Invitation link')
                          : item.email ?? context.tr('Invitation'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${context.tr(state)} · ${context.tr('Expires on {date}', {'date': _date(item.expiresAt)})}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr('Created on {date}', {
                        'date': _date(item.createdAt),
                      }),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (active)
                PopupMenuButton<String>(
                  enabled: _busy == null,
                  tooltip: context.tr('Invitation options'),
                  onSelected: (_) => _revoke(item),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'revoke',
                      child: Text(context.tr('Revoke')),
                    ),
                  ],
                ),
            ],
          ),
          if (active && _url(item) != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy == null
                        ? () => _shareExisting(item)
                        : null,
                    icon: _busy == item.id
                        ? _spinner()
                        : const Icon(Icons.share_outlined, size: 18),
                    label: Text(context.tr('Share')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy == null ? () => _copy(item) : null,
                    icon: const Icon(Icons.copy_outlined, size: 18),
                    label: Text(context.tr('Copy')),
                  ),
                ),
              ],
            ),
          ] else if (active && item.isLink) ...[
            const SizedBox(height: 8),
            Text(
              context.tr(
                'This link is not available to copy. Create a new link to share.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class CommunityInvitationLinkPage extends StatefulWidget {
  const CommunityInvitationLinkPage({
    super.key,
    required this.token,
    required this.repository,
  });
  final String token;
  final CommunityRepository repository;

  @override
  State<CommunityInvitationLinkPage> createState() =>
      _CommunityInvitationLinkPageState();
}

class _CommunityInvitationLinkPageState
    extends State<CommunityInvitationLinkPage> {
  late final Future<CommunityInvitation> _invitation = widget.repository
      .getCommunityInvitationLink(widget.token);
  bool _responding = false;

  Future<void> _respond(bool accept) async {
    if (_responding) return;
    setState(() => _responding = true);
    try {
      await widget.repository.respondToCommunityInvitationLink(
        widget.token,
        accept: accept,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              accept ? 'You joined the community.' : 'Invitation declined.',
            ),
          ),
        ),
      );
      Navigator.pop(context, accept);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    } finally {
      if (mounted) setState(() => _responding = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('Community invitation'))),
    body: FutureBuilder<CommunityInvitation>(
      future: _invitation,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                context.trError(snapshot.error!),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final invitation = snapshot.data!;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircleAvatar(
                    radius: 38,
                    child: Icon(Icons.groups_outlined, size: 38),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    invitation.communityName ?? context.tr('Community'),
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr('You were invited to join this community.'),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _responding ? null : () => _respond(false),
                          child: Text(context.tr('Decline')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _responding ? null : () => _respond(true),
                          child: Text(context.tr('Join')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

class MyCommunityInvitationsPage extends StatefulWidget {
  const MyCommunityInvitationsPage({super.key, required this.repository});
  final CommunityRepository repository;
  @override
  State<MyCommunityInvitationsPage> createState() =>
      _MyCommunityInvitationsPageState();
}

class _MyCommunityInvitationsPageState
    extends State<MyCommunityInvitationsPage> {
  late Future<List<CommunityInvitation>> _items = widget.repository
      .listMyCommunityInvitations();

  Future<void> _respond(CommunityInvitation invitation, bool accept) async {
    try {
      await widget.repository.respondToCommunityInvitation(
        invitation.id,
        accept: accept,
      );
      if (mounted) {
        setState(() => _items = widget.repository.listMyCommunityInvitations());
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        context.tr('Invitations'),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    body: FutureBuilder<List<CommunityInvitation>>(
      future: _items,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(context.trError(snapshot.error!)));
        }
        final items = snapshot.data ?? const [];
        if (items.isEmpty) {
          return const _InvitationsEmptyState();
        }
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: items.length,
          separatorBuilder: (_, _) => const Divider(),
          itemBuilder: (context, index) {
            final item = items[index];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(child: Icon(Icons.groups_outlined)),
              title: Text(item.communityName ?? context.tr('Community')),
              subtitle: Text(
                context.tr('You were invited to join this community.'),
              ),
              trailing: Wrap(
                spacing: 4,
                children: [
                  TextButton(
                    onPressed: () => _respond(item, false),
                    child: Text(context.tr('Decline')),
                  ),
                  FilledButton(
                    onPressed: () => _respond(item, true),
                    child: Text(context.tr('Accept')),
                  ),
                ],
              ),
            );
          },
        );
      },
    ),
  );
}

class _InvitationsEmptyState extends StatelessWidget {
  const _InvitationsEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 32, 28, 80),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ExcludeSemantics(
                    child: SizedBox(
                      width: 220,
                      height: 180,
                      child: CustomPaint(
                        painter: _InvitationIllustration(
                          colors.primary,
                          colors.surface,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    context.tr('You have no invitations'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Text(
                      context.tr(
                        'When someone invites you to a community, the invitation will appear here.',
                      ),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        height: 1.4,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InvitationIllustration extends CustomPainter {
  const _InvitationIllustration(this.primary, this.surface);
  final Color primary;
  final Color surface;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 220, size.height / 180);
    final soft = Paint()..color = primary.withValues(alpha: .07);
    canvas.drawCircle(const Offset(108, 85), 78, soft);
    canvas.drawOval(const Rect.fromLTWH(35, 161, 158, 14), soft);
    final envelope = Path()
      ..moveTo(52, 89)
      ..lineTo(107, 42)
      ..quadraticBezierTo(112, 38, 117, 42)
      ..lineTo(170, 89)
      ..close();
    canvas.drawPath(envelope, Paint()..color = primary.withValues(alpha: .55));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(52, 86, 118, 79),
        const Radius.circular(8),
      ),
      Paint()
        ..color = Color.alphaBlend(primary.withValues(alpha: .28), surface),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(64, 50, 95, 99),
        const Radius.circular(8),
      ),
      Paint()..color = surface,
    );
    final stroke = Paint()
      ..color = primary.withValues(alpha: .2)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(80, 77), const Offset(113, 77), stroke);
    canvas.drawLine(const Offset(80, 93), const Offset(126, 93), stroke);
    final flap = Path()
      ..moveTo(52, 88)
      ..lineTo(108, 126)
      ..quadraticBezierTo(112, 129, 117, 126)
      ..lineTo(170, 88)
      ..lineTo(170, 157)
      ..quadraticBezierTo(170, 165, 162, 165)
      ..lineTo(60, 165)
      ..quadraticBezierTo(52, 165, 52, 157)
      ..close();
    canvas.drawPath(
      flap,
      Paint()
        ..color = Color.alphaBlend(primary.withValues(alpha: .28), surface),
    );
    final seam = Paint()
      ..color = primary.withValues(alpha: .18)
      ..strokeWidth = 1.5;
    canvas.drawLine(const Offset(55, 162), const Offset(96, 119), seam);
    canvas.drawLine(const Offset(167, 162), const Offset(128, 119), seam);
    canvas.drawCircle(const Offset(144, 71), 19, Paint()..color = primary);
    canvas.drawPath(
      Path()
        ..moveTo(135, 71)
        ..lineTo(142, 78)
        ..lineTo(154, 64),
      Paint()
        ..color = surface
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    final accent = Paint()
      ..color = primary
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(183, 60), const Offset(192, 50), accent);
    canvas.drawLine(const Offset(189, 76), const Offset(202, 74), accent);
    canvas.drawLine(const Offset(36, 76), const Offset(43, 80), accent);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_InvitationIllustration oldDelegate) =>
      primary != oldDelegate.primary || surface != oldDelegate.surface;
}
