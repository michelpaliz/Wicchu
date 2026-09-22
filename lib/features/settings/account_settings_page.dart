import 'package:flutter/material.dart';
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
      ]);
      final preferences = results[0] as SharedPreferences;
      final notifications = results[1] as NotificationPreferences;
      if (!mounted) return;
      setState(() {
        _postNotifications = notifications.postActivity;
        _communityNotifications = notifications.communityActivity;
        _promotionNotifications = notifications.promotions;
        _locationDiscovery = preferences.getBool('location_discovery') ?? true;
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
              Text(
                context.tr('Notifications'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
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
                title: Text(context.tr('Community activity')),
                subtitle: Text(context.tr('Membership and moderation updates')),
                value: _communityNotifications,
                onChanged: (value) {
                  setState(() => _communityNotifications = value);
                  _set('communityActivity', value);
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.tr('Promotions')),
                subtitle: Text(context.tr('Promotion approval updates')),
                value: _promotionNotifications,
                onChanged: (value) {
                  setState(() => _promotionNotifications = value);
                  _set('promotions', value);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.alternate_email),
                title: Text(context.tr('Social and contact links')),
                subtitle: Text(context.tr('WhatsApp, Facebook, Instagram and email')),
                trailing: const Icon(Icons.chevron_right),
                onTap: _editSocialLinks,
              ),
              const Divider(height: 32),
              Text(
                context.tr('Privacy'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.tr('Nearby discovery')),
                subtitle: Text(
                  context.tr(
                    'Allow location use when you request nearby communities',
                  ),
                ),
                value: _locationDiscovery,
                onChanged: (value) {
                  setState(() => _locationDiscovery = value);
                  _set('location_discovery', value);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.lock_outline),
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
                title: Text(context.tr('Data deletion')),
                subtitle: Text(
                  context.tr(
                    'Visit hexora.dev/wicchu/data-deletion to request deletion.',
                  ),
                ),
              ),
            ],
          ),
  );

  Future<void> _editSocialLinks() async {
    try {
      final current = await widget.repository.getMySocialLinks();
      if (!mounted) return;
      final whatsapp = TextEditingController(text: current.whatsapp);
      final facebook = TextEditingController(text: current.facebook);
      final instagram = TextEditingController(text: current.instagram);
      final email = TextEditingController(text: current.email);
      final links = await showDialog<SocialLinks>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(dialogContext.tr('Social and contact links')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: whatsapp, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'WhatsApp')),
                TextField(controller: facebook, decoration: const InputDecoration(labelText: 'Facebook')),
                TextField(controller: instagram, decoration: const InputDecoration(labelText: 'Instagram')),
                TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(dialogContext.tr('Cancel'))),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, SocialLinks(
                whatsapp: whatsapp.text.trim(),
                facebook: facebook.text.trim(),
                instagram: instagram.text.trim(),
                email: email.text.trim(),
              )),
              child: Text(dialogContext.tr('Save')),
            ),
          ],
        ),
      );
      whatsapp.dispose();
      facebook.dispose();
      instagram.dispose();
      email.dispose();
      if (links == null) return;
      await widget.repository.updateMySocialLinks(links);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Profile links saved'))));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.trError(error))));
    }
  }
}

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('Help'))),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ExpansionTile(
          title: Text(context.tr('How do I join a community?')),
          children: [
            ListTile(
              title: Text(
                context.tr(
                  'Open Explore, select a community, and tap Join. Private communities require administrator approval.',
                ),
              ),
            ),
          ],
        ),
        ExpansionTile(
          title: Text(context.tr('How do I report a post?')),
          children: [
            ListTile(
              title: Text(
                context.tr(
                  'Tap the flag on a post, enter a reason, and submit it to the community moderators.',
                ),
              ),
            ),
          ],
        ),
        ExpansionTile(
          title: Text(context.tr('How is my location used?')),
          children: [
            ListTile(
              title: Text(
                context.tr(
                  'Location is requested only when you choose nearby discovery and is sent to the server to find communities within the selected radius.',
                ),
              ),
            ),
          ],
        ),
        ListTile(
          leading: Icon(Icons.email_outlined),
          title: Text(context.tr('Support')),
          subtitle: Text(
            context.tr('Contact the Wicchu support team through hexora.dev.'),
          ),
        ),
      ],
    ),
  );
}
