import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/community_input_limits.dart';
import '../../domain/community_models.dart';
import '../../localization/app_language.dart';
import '../../widgets/profile_link_button.dart';

class OfficialLinksPage extends StatefulWidget {
  const OfficialLinksPage({
    super.key,
    required this.links,
    required this.onChanged,
  });

  final List<CommunityLink> links;
  final ValueChanged<List<CommunityLink>> onChanged;

  @override
  State<OfficialLinksPage> createState() => _OfficialLinksPageState();
}

class _OfficialLinksPageState extends State<OfficialLinksPage> {
  late final _links = [...widget.links];

  void _notify() => widget.onChanged(List.unmodifiable(_links));

  Future<void> _edit({int? index}) async {
    final link = await Navigator.push<CommunityLink>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            OfficialLinkEditor(link: index == null ? null : _links[index]),
      ),
    );
    if (!mounted || link == null) return;
    setState(() {
      if (index == null) {
        _links.add(link);
      } else {
        _links[index] = link;
      }
    });
    _notify();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('Official links'))),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            context.tr(
              'Add a website, social network, contact page, or another official link.',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('Finish by saving changes in settings.'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          for (final (index, link) in _links.indexed)
            Card(
              child: ListTile(
                leading: const Icon(Icons.link),
                title: Text(link.label),
                subtitle: Text(
                  link.url,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => _edit(index: index),
                trailing: IconButton(
                  tooltip: context.tr('Remove'),
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    setState(() => _links.removeAt(index));
                    _notify();
                  },
                ),
              ),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _links.length >= 10 ? null : () => _edit(),
            icon: const Icon(Icons.add_link),
            label: Text(context.tr('Add link')),
          ),
        ],
      ),
    ),
  );
}

class OfficialLinkEditor extends StatefulWidget {
  const OfficialLinkEditor({super.key, this.link});
  final CommunityLink? link;

  @override
  State<OfficialLinkEditor> createState() => OfficialLinkEditorState();
}

class OfficialLinkEditorState extends State<OfficialLinkEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _label = TextEditingController(text: widget.link?.label ?? '');
  late final _url = TextEditingController(text: widget.link?.url ?? '');
  late String _selected = widget.link == null
      ? 'other'
      : profileLinkNetwork(widget.link!.url);

  @override
  void initState() {
    super.initState();
    _label.addListener(_changed);
    _url.addListener(_changed);
  }

  void _changed() => setState(() {});

  String get _normalizedUrl {
    final value = _url.text.trim();
    if (value.isEmpty) return '';
    if ((_selected == 'telegram' ||
            _label.text.trim().toLowerCase() == 'telegram') &&
        !value.contains('://')) {
      if (value.startsWith('t.me/') || value.startsWith('telegram.me/')) {
        return 'https://$value';
      }
      if (!value.contains('/') &&
          !value.contains('.') &&
          !value.contains(':')) {
        return 'https://t.me/${value.replaceFirst(RegExp(r'^@'), '')}';
      }
    }
    return value;
  }

  bool get _validUrl {
    final parsed = Uri.tryParse(_normalizedUrl);
    return parsed != null &&
        parsed.scheme == 'https' &&
        parsed.host.isNotEmpty &&
        !parsed.host.contains(RegExp(r'\s')) &&
        parsed.userInfo.isEmpty &&
        _normalizedUrl.length <= CommunityInputLimits.linkUrl &&
        !(parsed.host == 't.me' &&
            parsed.pathSegments.where((part) => part.isNotEmpty).isEmpty);
  }

  @override
  void dispose() {
    _label.removeListener(_changed);
    _url.removeListener(_changed);
    _label.dispose();
    _url.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      CommunityLink(label: _label.text.trim(), url: _normalizedUrl),
    );
  }

  (String, IconData, Color) _network(String network) => switch (network) {
    'telegram' => ('Telegram', Icons.send_outlined, const Color(0xFF0088CC)),
    'instagram' => (
      'Instagram',
      Icons.camera_alt_outlined,
      const Color(0xFFC13584),
    ),
    'facebook' => ('Facebook', Icons.facebook, const Color(0xFF1877F2)),
    'whatsapp' => ('WhatsApp', Icons.chat_outlined, const Color(0xFF128C7E)),
    'youtube' => (
      'YouTube',
      Icons.play_circle_outline,
      const Color(0xFFCC0000),
    ),
    'other' => (
      context.tr('Other'),
      Icons.more_horiz,
      Theme.of(context).colorScheme.primary,
    ),
    _ => (
      context.tr('Website'),
      Icons.language,
      Theme.of(context).colorScheme.primary,
    ),
  };

  void _select(String network) {
    setState(() => _selected = network);
    _label.text = network == 'other' ? '' : _network(network).$1;
    if (_url.text.isEmpty ||
        {
          'https://',
          'https://t.me/',
          'https://www.instagram.com/',
        }.contains(_url.text)) {
      _url.text = switch (network) {
        'telegram' => 'https://t.me/',
        'instagram' => 'https://www.instagram.com/',
        'website' => 'https://',
        _ => '',
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final network = _network(profileLinkNetwork(_normalizedUrl));
    Widget heading(String title, String description) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr(title),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            context.tr(description),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
    InputDecoration decoration(String hint) => InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: colors.onSurface.withValues(alpha: .04),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr(
            widget.link == null ? 'Add official link' : 'Edit official link',
          ),
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: Text(context.tr('Save')),
            ),
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              Text(
                context.tr(
                  'Add links to your social networks, website or other official channels.',
                ),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  spacing: 8,
                  children: [
                    for (final key in [
                      'telegram',
                      'website',
                      'instagram',
                      'other',
                    ])
                      ChoiceChip(
                        avatar: Icon(
                          _network(key).$2,
                          size: 20,
                          color: _selected == key
                              ? colors.primary
                              : colors.onSurfaceVariant,
                        ),
                        label: Text(_network(key).$1),
                        labelStyle: TextStyle(
                          color: _selected == key
                              ? colors.primary
                              : colors.onSurface,
                        ),
                        checkmarkColor: colors.primary,
                        selected: _selected == key,
                        showCheckmark: true,
                        selectedColor: colors.primary.withValues(alpha: .08),
                        backgroundColor: colors.surface,
                        side: BorderSide(
                          color: _selected == key
                              ? colors.primary
                              : colors.onSurface.withValues(alpha: .10),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 12,
                        ),
                        onSelected: (_) => _select(key),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: .05),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: colors.primary, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.tr(
                          'Official links appear in the profile so people can find you easily.',
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              heading(
                'Label',
                'Name shown on the profile (e.g. Telegram, Website, Facebook).',
              ),
              TextFormField(
                controller: _label,
                maxLength: CommunityInputLimits.linkLabel,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                textInputAction: TextInputAction.next,
                decoration: decoration(context.tr('Label')),
                validator: (value) => value == null || value.trim().isEmpty
                    ? context.tr('Required')
                    : null,
              ),
              const SizedBox(height: 12),
              heading('Link', 'Enter the full URL of your link.'),
              TextFormField(
                controller: _url,
                maxLength: CommunityInputLimits.linkUrl,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                keyboardType: TextInputType.url,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _save(),
                decoration: decoration('https://').copyWith(
                  prefixIcon: const Icon(Icons.link),
                  suffixIcon: _url.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: context.tr('Clear link'),
                          icon: const Icon(Icons.close),
                          onPressed: _url.clear,
                        ),
                ),
                validator: (_) => _validUrl
                    ? null
                    : context.tr('Use a valid HTTPS profile link.'),
              ),
              if (_validUrl) ...[
                const SizedBox(height: 8),
                Container(
                  key: const ValueKey('official-link-preview'),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: .05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: network.$3,
                        foregroundColor: Colors.white,
                        child: Icon(network.$2, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _normalizedUrl.replaceFirst('https://', ''),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              context.tr('Shown as a {network} link.', {
                                'network': network.$1,
                              }),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
