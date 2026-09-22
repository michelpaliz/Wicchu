import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    appBar: AppBar(title: const Text('Settings')),
    body: !_loaded
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Notifications',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Post activity'),
                subtitle: const Text('Reactions and comments on your posts'),
                value: _postNotifications,
                onChanged: (value) {
                  setState(() => _postNotifications = value);
                  _set('post_notifications', value);
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Community activity'),
                subtitle: const Text('Membership and moderation updates'),
                value: _communityNotifications,
                onChanged: (value) {
                  setState(() => _communityNotifications = value);
                  _set('community_notifications', value);
                },
              ),
              const Divider(height: 32),
              Text('Privacy', style: Theme.of(context).textTheme.titleLarge),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Nearby discovery'),
                subtitle: const Text(
                  'Allow location use when you request nearby communities',
                ),
                value: _locationDiscovery,
                onChanged: (value) {
                  setState(() => _locationDiscovery = value);
                  _set('location_discovery', value);
                },
              ),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.lock_outline),
                title: Text('Account security'),
                subtitle: Text(
                  'Authentication credentials are stored securely on this device.',
                ),
              ),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.delete_outline),
                title: Text('Data deletion'),
                subtitle: Text(
                  'Visit hexora.dev/wicchu/data-deletion to request deletion.',
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
    appBar: AppBar(title: const Text('Help')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        ExpansionTile(
          title: Text('How do I join a community?'),
          children: [
            ListTile(
              title: Text(
                'Open Explore, select a community, and tap Join. Private communities require administrator approval.',
              ),
            ),
          ],
        ),
        ExpansionTile(
          title: Text('How do I report a post?'),
          children: [
            ListTile(
              title: Text(
                'Tap the flag on a post, enter a reason, and submit it to the community moderators.',
              ),
            ),
          ],
        ),
        ExpansionTile(
          title: Text('How is my location used?'),
          children: [
            ListTile(
              title: Text(
                'Location is requested only when you choose nearby discovery and is sent to the server to find communities within the selected radius.',
              ),
            ),
          ],
        ),
        ListTile(
          leading: Icon(Icons.email_outlined),
          title: Text('Support'),
          subtitle: Text('Contact the Wicchu support team through hexora.dev.'),
        ),
      ],
    ),
  );
}
