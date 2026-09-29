import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/community_input_limits.dart';
import '../../domain/community_models.dart';
import '../../localization/app_language.dart';

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
            _OfficialLinkEditor(link: index == null ? null : _links[index]),
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

class _OfficialLinkEditor extends StatefulWidget {
  const _OfficialLinkEditor({this.link});
  final CommunityLink? link;

  @override
  State<_OfficialLinkEditor> createState() => _OfficialLinkEditorState();
}

class _OfficialLinkEditorState extends State<_OfficialLinkEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _label = TextEditingController(text: widget.link?.label ?? '');
  late final _url = TextEditingController(text: widget.link?.url ?? '');

  String get _normalizedUrl {
    final value = _url.text.trim();
    if (_label.text.trim().toLowerCase() == 'telegram' &&
        !value.contains('://')) {
      return 'https://t.me/${value.replaceFirst(RegExp(r'^@'), '')}';
    }
    return value;
  }

  @override
  void dispose() {
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        context.tr(
          widget.link == null ? 'Add official link' : 'Edit official link',
        ),
      ),
    ),
    body: SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.send_outlined, size: 18),
                  label: const Text('Telegram'),
                  onPressed: () {
                    _label.text = 'Telegram';
                    if (_url.text.trim().isEmpty) _url.text = 'https://t.me/';
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.language, size: 18),
                  label: Text(context.tr('Website')),
                  onPressed: () {
                    _label.text = context.tr('Website');
                    if (_url.text.trim().isEmpty) _url.text = 'https://';
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: Text(context.tr('Other')),
                  onPressed: () {
                    _label.clear();
                    _url.clear();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _label,
              maxLength: CommunityInputLimits.linkLabel,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: context.tr('Label'),
                hintText: context.tr('Telegram, website, Facebook, or other'),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? context.tr('Required')
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _url,
              maxLength: CommunityInputLimits.linkUrl,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              keyboardType: TextInputType.url,
              autocorrect: false,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _save(),
              decoration: const InputDecoration(
                labelText: 'HTTPS URL',
                hintText: 'https://',
              ),
              validator: (_) {
                final parsed = Uri.tryParse(_normalizedUrl);
                if (parsed == null ||
                    parsed.scheme != 'https' ||
                    parsed.host.isEmpty ||
                    (parsed.host == 't.me' &&
                        parsed.pathSegments
                            .where((part) => part.isNotEmpty)
                            .isEmpty)) {
                  return context.tr('Use a valid HTTPS profile link.');
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: Text(context.tr('Save')),
            ),
          ],
        ),
      ),
    ),
  );
}
