import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../profile/edit_profile_links.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../localization/app_language.dart';
import '../../domain/community_repository.dart';
import '../../domain/community_models.dart';

class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({super.key, required this.repository});
  final CommunityRepository repository;

  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  bool _postNotifications = true;
  bool _communityNotifications = true;
  bool _promotionNotifications = true;
  bool _locationDiscovery = true;
  bool _showOnlineStatus = true;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        SharedPreferences.getInstance(),
        widget.repository.getNotificationPreferences(),
        widget.repository.getMySocialLinks(),
      ]);
      final preferences = results[0] as SharedPreferences;
      final notifications = results[1] as NotificationPreferences;
      final socialLinks = results[2] as SocialLinks;
      if (!mounted) return;
      setState(() {
        _postNotifications = notifications.postActivity;
        _communityNotifications = notifications.communityActivity;
        _promotionNotifications = notifications.promotions;
        _locationDiscovery = preferences.getBool('location_discovery') ?? true;
        _showOnlineStatus = socialLinks.showOnlineStatus;
        _loaded = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loaded = true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.trError(error))));
    }
  }

  Future<void> _set(String key, bool value) async {
    try {
      await widget.repository.updateNotificationPreferences(
        postActivity: key == 'postActivity' ? value : null,
        communityActivity: key == 'communityActivity' ? value : null,
        promotions: key == 'promotions' ? value : null,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (key == 'postActivity') _postNotifications = !value;
        if (key == 'communityActivity') _communityNotifications = !value;
        if (key == 'promotions') _promotionNotifications = !value;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.trError(error))));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('Settings'))),
    body: !_loaded
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _settingsCard([
                _sectionHeader(
                  Icons.notifications_none,
                  'Notifications',
                  'Choose which activity you receive.',
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.article_outlined),
                  title: Text(context.tr('Post activity')),
                  subtitle: Text(
                    context.tr('Reactions and comments on your posts'),
                  ),
                  value: _postNotifications,
                  onChanged: (value) {
                    setState(() => _postNotifications = value);
                    _set('postActivity', value);
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.groups_outlined),
                  title: Text(context.tr('Community activity')),
                  subtitle: Text(
                    context.tr('Membership and moderation updates'),
                  ),
                  value: _communityNotifications,
                  onChanged: (value) {
                    setState(() => _communityNotifications = value);
                    _set('communityActivity', value);
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.campaign_outlined),
                  title: Text(context.tr('Promotions')),
                  subtitle: Text(context.tr('Promotion approval updates')),
                  value: _promotionNotifications,
                  onChanged: (value) {
                    setState(() => _promotionNotifications = value);
                    _set('promotions', value);
                  },
                ),
                const Divider(height: 20),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.alternate_email),
                  title: Text(context.tr('Social and contact links')),
                  subtitle: Text(
                    context.tr('WhatsApp, Facebook, Instagram and email'),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await editProfileLinks(context, widget.repository);
                    if (mounted) await _load();
                  },
                ),
              ]),
              const SizedBox(height: 16),
              _settingsCard([
                _sectionHeader(
                  Icons.shield_outlined,
                  'Privacy',
                  'Control your information and visibility.',
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.location_on_outlined),
                  title: Text(context.tr('Nearby discovery')),
                  subtitle: Text(
                    context.tr(
                      'Allow location use when you request nearby communities',
                    ),
                  ),
                  value: _locationDiscovery,
                  onChanged: (value) {
                    setState(() => _locationDiscovery = value);
                    _setLocationDiscovery(value);
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.visibility_outlined),
                  title: Text(context.tr('Show online status')),
                  subtitle: Text(
                    context.tr(
                      'Let members of your communities see when you are online',
                    ),
                  ),
                  value: _showOnlineStatus,
                  onChanged: _setOnlineVisibility,
                ),
                const Divider(height: 20),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.lock_outline),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(context.tr('Account security')),
                      content: Text(
                        context.tr(
                          'Authentication credentials are stored securely on this device.',
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(context.tr('Close')),
                        ),
                      ],
                    ),
                  ),
                  title: Text(context.tr('Account security')),
                  subtitle: Text(
                    context.tr(
                      'Authentication credentials are stored securely on this device.',
                    ),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.delete_outline),
                  trailing: const Icon(Icons.open_in_new, size: 20),
                  onTap: _openDataDeletion,
                  title: Text(context.tr('Data deletion')),
                  subtitle: Text(
                    context.tr(
                      'Visit hexora.dev/wicchu/data-deletion to request deletion.',
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              _settingsCard([
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: _headerIcon(Icons.info_outline),
                  title: Text(
                    context.tr('About the app'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: const Text('Wicchu'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showAboutDialog(
                    context: context,
                    applicationName: 'Wicchu',
                  ),
                ),
              ]),
            ],
          ),
  );

  Widget _headerIcon(IconData icon) => CircleAvatar(
    radius: 22,
    backgroundColor: Theme.of(
      context,
    ).colorScheme.primary.withValues(alpha: 0.1),
    child: Icon(icon, color: Theme.of(context).colorScheme.primary),
  );

  Widget _sectionHeader(IconData icon, String title, String subtitle) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            _headerIcon(icon),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr(title),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.tr(subtitle),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _settingsCard(List<Widget> children) => Material(
    color: Theme.of(context).colorScheme.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
      ),
    ),
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: children),
    ),
  );

  Future<void> _setLocationDiscovery(bool value) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (!await preferences.setBool('location_discovery', value)) {
        throw Exception('Could not save setting');
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _locationDiscovery = !value);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.trError(error))));
    }
  }

  Future<void> _openDataDeletion() async {
    try {
      if (!await launchUrl(
        Uri.parse('https://hexora.dev/wicchu/data-deletion'),
        mode: LaunchMode.externalApplication,
      )) {
        throw Exception('Unable to open link');
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'Visit hexora.dev/wicchu/data-deletion to request deletion.',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _setOnlineVisibility(bool value) async {
    final previous = _showOnlineStatus;
    setState(() => _showOnlineStatus = value);
    try {
      final current = await widget.repository.getMySocialLinks();
      await widget.repository.updateMySocialLinks(
        SocialLinks(
          whatsapp: current.whatsapp,
          facebook: current.facebook,
          instagram: current.instagram,
          email: current.email,
          showOnlineStatus: value,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _showOnlineStatus = previous);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.trError(error))));
    }
  }
}

class HelpPage extends StatefulWidget {
  const HelpPage({super.key});

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  final _search = TextEditingController();
  String _query = '';
  bool _openingSupport = false;

  static const _questions = [
    (
      icon: Icons.groups_outlined,
      title: 'How do I join a community?',
      answer:
          'Open Explore, select a community, and tap Join. Private communities require administrator approval.',
    ),
    (
      icon: Icons.shield_outlined,
      title: 'How do I report a post?',
      answer:
          'Open the post’s options menu, select Report, enter a reason, and submit it to the community moderators.',
    ),
    (
      icon: Icons.location_on_outlined,
      title: 'How is my location used?',
      answer:
          'Location is requested only when you choose nearby discovery and is sent to the server to find communities within the selected radius.',
    ),
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _normalize(String text) {
    var result = text.toLowerCase();
    const accents = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ü': 'u',
    };
    accents.forEach(
      (accent, letter) => result = result.replaceAll(accent, letter),
    );
    return result;
  }

  Future<void> _openSupport() async {
    if (_openingSupport) return;
    setState(() => _openingSupport = true);
    try {
      final opened = await launchUrl(
        Uri.parse('https://hexora.dev'),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw Exception('Could not open the support website.');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                'Could not open the support website. Please visit hexora.dev.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _openingSupport = false);
    }
  }

  Widget _icon(IconData icon, {double size = 44}) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.09),
      shape: BoxShape.circle,
    ),
    child: Icon(
      icon,
      color: Theme.of(context).colorScheme.primary,
      size: size * 0.5,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final query = _normalize(_query.trim());
    final questions = _questions
        .where(
          (item) => _normalize(
            '${context.tr(item.title)} ${context.tr(item.answer)}',
          ).contains(query),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Help'))),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('How can we help you?'),
                        style: text.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.tr('Find answers about Wicchu.'),
                        style: text.bodyLarge?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ExcludeSemantics(
                  child: _icon(Icons.question_answer_outlined, size: 64),
                ),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _search,
              onChanged: (value) => setState(() => _query = value),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: context.tr('Search help…'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: context.tr('Clear search'),
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                      ),
                filled: true,
                fillColor: colors.onSurface.withValues(alpha: 0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              context.tr('Frequently asked questions'),
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Material(
              color: colors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(
                  color: colors.onSurface.withValues(alpha: 0.07),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: questions.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        context.tr(
                          'No answers found. Try another search or contact support.',
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        for (var i = 0; i < questions.length; i++) ...[
                          ExpansionTile(
                            key: ValueKey(questions[i].title),
                            leading: _icon(questions[i].icon, size: 36),
                            title: Text(context.tr(questions[i].title)),
                            shape: const Border(),
                            collapsedShape: const Border(),
                            childrenPadding: const EdgeInsets.fromLTRB(
                              16,
                              0,
                              16,
                              20,
                            ),
                            children: [
                              Text(
                                context.tr(questions[i].answer),
                                style: text.bodyMedium?.copyWith(
                                  height: 1.45,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          if (i < questions.length - 1)
                            Divider(
                              height: 1,
                              indent: 68,
                              endIndent: 16,
                              color: colors.onSurface.withValues(alpha: 0.07),
                            ),
                        ],
                      ],
                    ),
            ),
            const SizedBox(height: 24),
            Text(
              context.tr('Need more help?'),
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _icon(Icons.mail_outline, size: 48),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('Contact the support team'),
                              style: text.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              context.tr(
                                'Can’t find the answer? Contact the Wicchu team through hexora.dev.',
                              ),
                              style: text.bodyMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: _openingSupport ? null : _openSupport,
                      icon: _openingSupport
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.open_in_new, size: 20),
                      label: Text(context.tr('Contact support')),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Material(
              color: colors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(18),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _openingSupport ? null : _openSupport,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _icon(Icons.lightbulb_outline, size: 36),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('Tip'),
                              style: text.titleSmall?.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              context.tr(
                                'Find more information on our website: hexora.dev.',
                              ),
                              style: text.bodyMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
