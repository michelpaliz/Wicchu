import 'package:flutter/material.dart';
import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';

Future<void> editProfileLinks(
  BuildContext context,
  CommunityRepository repository,
) async {
  final saved = await Navigator.push<bool>(
    context,
    MaterialPageRoute(builder: (_) => EditProfilePage(repository: repository)),
  );
  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.tr('Profile links saved'))));
  }
}

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key, required this.repository});
  final CommunityRepository repository;
  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _form = GlobalKey<FormState>();
  final _controllers = List.generate(4, (_) => TextEditingController());
  SocialLinks? _initial;
  String? _error;
  bool _loading = true;
  bool _saving = false;
  bool _allowPop = false;

  @override
  void initState() {
    super.initState();
    for (final controller in _controllers) {
      controller.addListener(_changed);
    }
    _load();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  bool get _dirty {
    final initial = _initial;
    if (initial == null) return false;
    final values = [
      initial.whatsapp,
      initial.facebook,
      initial.instagram,
      initial.email,
    ];
    return List.generate(
      4,
      (i) => _controllers[i].text.trim() != values[i],
    ).contains(true);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final links = await widget.repository.getMySocialLinks();
      if (!mounted) return;
      _initial = links;
      final values = [
        links.whatsapp,
        links.facebook,
        links.instagram,
        links.email,
      ];
      for (var i = 0; i < values.length; i++) {
        _controllers[i].text = values[i];
      }
    } catch (error) {
      if (mounted) _error = context.trError(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _leave() async {
    if (_saving) return;
    final discard =
        !_dirty ||
        await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: Text(context.tr('Discard changes?')),
                content: Text(
                  context.tr('Your profile changes have not been saved.'),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: Text(context.tr('Keep editing')),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: Text(context.tr('Discard')),
                  ),
                ],
              ),
            ) ==
            true;
    if (!discard || !mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  String? _validate(int index, String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return null;
    if (index == 0 && !RegExp(r'^\+?[0-9 ()-]{7,25}$').hasMatch(value)) {
      return context.tr('Enter a phone number with country code.');
    }
    if (index == 3 && !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) {
      return context.tr('Enter a valid email address.');
    }
    if (index == 1 || index == 2) {
      if (value.contains('://')) {
        final uri = Uri.tryParse(value);
        final domain = index == 1 ? 'facebook.com' : 'instagram.com';
        if (uri == null ||
            uri.scheme != 'https' ||
            !(uri.host == domain || uri.host.endsWith('.$domain'))) {
          return context.tr('Use a valid HTTPS profile link.');
        }
      } else if (!RegExp(r'^@?[a-zA-Z0-9._-]+$').hasMatch(value)) {
        return context.tr('Enter a username or profile link.');
      }
    }
    return null;
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final values = _controllers.map((c) => c.text.trim()).toList();
      await widget.repository.updateMySocialLinks(
        SocialLinks(
          whatsapp: values[0].replaceAll(RegExp(r'[ ()-]'), ''),
          facebook: values[1].replaceFirst(RegExp(r'^@'), ''),
          instagram: values[2].replaceFirst(RegExp(r'^@'), ''),
          email: values[3],
          showOnlineStatus: _initial!.showOnlineStatus,
        ),
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _allowPop = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context, true);
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = context.trError(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop || (!_dirty && !_saving),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _leave();
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Edit profile')),
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: _saving ? null : _leave,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _initial == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error ?? '', textAlign: TextAlign.center),
                  ),
                  FilledButton(
                    onPressed: _load,
                    child: Text(context.tr('Retry')),
                  ),
                ],
              ),
            )
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(20),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  Text(
                    context.tr('Social and contact links'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr(
                      'Choose how people can contact you from your profile. All fields are optional.',
                    ),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  for (var i = 0; i < 4; i++) ...[
                    TextFormField(
                      controller: _controllers[i],
                      enabled: !_saving,
                      keyboardType: i == 0
                          ? TextInputType.phone
                          : i == 3
                          ? TextInputType.emailAddress
                          : TextInputType.url,
                      textInputAction: i == 3
                          ? TextInputAction.done
                          : TextInputAction.next,
                      autocorrect: false,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: (value) => _validate(i, value),
                      decoration: InputDecoration(
                        labelText: [
                          'WhatsApp',
                          'Facebook',
                          'Instagram',
                          context.tr('Email'),
                        ][i],
                        hintText: [
                          '+34 600 123 456',
                          'https://facebook.com/username',
                          '@username',
                          'name@example.com',
                        ][i],
                        prefixIcon: Icon(
                          [
                            Icons.chat_outlined,
                            Icons.facebook,
                            Icons.camera_alt_outlined,
                            Icons.email_outlined,
                          ][i],
                        ),
                        helperText: i == 0
                            ? context.tr('Include your country code.')
                            : i == 1 || i == 2
                            ? context.tr('Username or HTTPS profile link')
                            : null,
                        helperMaxLines: 2,
                        errorMaxLines: 2,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  Text(
                    context.tr('Clear a field to remove it from your profile.'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
      bottomNavigationBar: _initial == null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: FilledButton.icon(
                onPressed: _saving || !_dirty ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check, size: 20),
                label: Text(
                  context.tr(_saving ? 'Saving changes…' : 'Save changes'),
                ),
              ),
            ),
    ),
  );
}
