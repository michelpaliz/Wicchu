import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../localization/app_language.dart';

class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({super.key});

  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  bool _postNotifications = true;
  bool _communityNotifications = true;
  bool _locationDiscovery = true;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _postNotifications = preferences.getBool('post_notifications') ?? true;
      _communityNotifications =
          preferences.getBool('community_notifications') ?? true;
      _locationDiscovery = preferences.getBool('location_discovery') ?? true;
      _loaded = true;
    });
  }

  Future<void> _set(String key, bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(key, value);
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
                  _set('post_notifications', value);
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.tr('Community activity')),
                subtitle: Text(context.tr('Membership and moderation updates')),
                value: _communityNotifications,
                onChanged: (value) {
                  setState(() => _communityNotifications = value);
                  _set('community_notifications', value);
                },
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
