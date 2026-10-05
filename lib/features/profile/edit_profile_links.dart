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
    ).showSnackBar(SnackBar(content: Text(context.tr('Profile saved'))));
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
  final _details = List.generate(4, (_) => TextEditingController());
  List<String>? _initialDetails;
  SocialLinks? _initial;
  String? _error;
  bool _loading = true;
  bool _saving = false;
  bool _allowPop = false;

  @override
  void initState() {
    super.initState();
    for (final controller in [..._controllers, ..._details]) {
      controller.addListener(_changed);
    }
    _load();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  bool get _detailsDirty =>
      _initialDetails != null &&
      List.generate(
        4,
        (i) => _details[i].text.trim() != _initialDetails![i],
      ).contains(true);

  bool get _dirty => _detailsDirty || _linksDirty;

  bool get _linksDirty {
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
      final profile = await widget.repository.getProfile();
      final member = await widget.repository.getMemberProfile(profile.id);
      final links = await widget.repository.getMySocialLinks();
      if (!mounted) return;
      _initialDetails = [
        profile.name,
        profile.userName,
        member.bio ?? '',
        profile.location ?? member.location ?? '',
      ];
      for (var i = 0; i < 4; i++) {
        _details[i].text = _initialDetails![i];
      }
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
    for (final controller in [..._controllers, ..._details]) {
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
      if (_detailsDirty) {
        final details = _details.map((c) => c.text.trim()).toList();
        await widget.repository.updateProfile(
          name: details[0],
          userName: details[1],
          bio: details[2],
          location: details[3],
        );
        _initialDetails = details;
      }
      final values = _controllers.map((c) => c.text.trim()).toList();
      if (_linksDirty) {
        await widget.repository.updateMySocialLinks(
          SocialLinks(
            whatsapp: values[0].replaceAll(RegExp(r'[ ()-]'), ''),
            facebook: values[1].replaceFirst(RegExp(r'^@'), ''),
            instagram: values[2].replaceFirst(RegExp(r'^@'), ''),
            email: values[3],
            showOnlineStatus: _initial!.showOnlineStatus,
          ),
        );
      }
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

  InputDecoration _decoration({String? hint, IconData? icon}) {
    final colors = Theme.of(context).colorScheme;
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: colors.onSurface.withValues(alpha: 0.035),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      prefixIcon: icon == null ? null : Icon(icon, size: 22),
      hintStyle: TextStyle(color: colors.onSurfaceVariant, fontSize: 14),
      counterStyle: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colors.primary, width: 1.5),
      ),
      errorMaxLines: 3,
    );
  }

  Widget _introduction() {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 22),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.person_outline, color: colors.primary, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Your profile, your community'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr(
                    'This information will be visible to other Wicchu users.',
                  ),
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactField(int i) {
    final colors = Theme.of(context).colorScheme;
    final label = ['WhatsApp', 'Facebook', 'Instagram', context.tr('Email')][i];
    final brandColor = [
      const Color(0xff25a95b),
      const Color(0xff1877f2),
      const Color(0xffc13584),
      colors.primary,
    ][i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: brandColor,
              gradient: i == 2
                  ? const LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [
                        Color(0xff833ab4),
                        Color(0xffe1306c),
                        Color(0xfffcaf45),
                      ],
                    )
                  : null,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              [
                Icons.chat_outlined,
                Icons.facebook,
                Icons.camera_alt_outlined,
                Icons.email_outlined,
              ][i],
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.onSurface.withValues(alpha: 0.025),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    key: ValueKey('profile-link-$i'),
                    controller: _controllers[i],
                    enabled: !_saving,
                    style: const TextStyle(fontSize: 14),
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
                    decoration:
                        _decoration(
                          hint: [
                            '+34 600 123 456',
                            'https://facebook.com/username',
                            '@username',
                            'name@example.com',
                          ][i],
                          icon: i == 1 || i == 2 ? Icons.link : null,
                        ).copyWith(
                          helperText: i == 0
                              ? context.tr('Include your country code.')
                              : null,
                          helperMaxLines: 2,
                          helperStyle: TextStyle(
                            fontSize: 11,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop || (!_dirty && !_saving),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _leave();
    },
    child: Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          context.tr('Edit profile'),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        leading: Padding(
          padding: const EdgeInsets.all(7),
          child: IconButton.filledTonal(
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.07),
              foregroundColor: Theme.of(context).colorScheme.primary,
            ),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: _saving ? null : _leave,
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          ),
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _introduction(),
                    Text(
                      context.tr('Personal information'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr('Tell us a little about yourself.'),
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 18),
                    for (var i = 0; i < 4; i++) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 10, bottom: 6),
                        child: Text(
                          context.tr(
                            ['Name', 'Username', 'Bio', 'Location'][i],
                          ),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      TextFormField(
                        style: const TextStyle(fontSize: 15),
                        key: ValueKey('profile-detail-$i'),
                        controller: _details[i],
                        enabled: !_saving,
                        maxLength: [80, 30, 500, 120][i],
                        minLines: i == 2 ? 3 : 1,
                        maxLines: i == 2 ? 5 : 1,
                        textCapitalization: i == 1
                            ? TextCapitalization.none
                            : TextCapitalization.sentences,
                        autocorrect: i != 1,
                        validator: (raw) {
                          final value = (raw ?? '').trim();
                          if (i < 2 && value.isEmpty) {
                            return context.tr('This field is required.');
                          }
                          if (i == 1 &&
                              !RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(value)) {
                            return context.tr(
                              'Use letters, numbers, dots, underscores or hyphens.',
                            );
                          }
                          return null;
                        },
                        decoration: _decoration(
                          hint: i == 2
                              ? context.tr(
                                  'Tell us about yourself, your interests or what makes you unique…',
                                )
                              : i == 3
                              ? context.tr('Add your location')
                              : null,
                          icon: [
                            Icons.person_outline,
                            Icons.alternate_email,
                            Icons.notes_outlined,
                            Icons.location_on_outlined,
                          ][i],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    const Divider(height: 32),
                    Text(
                      context.tr('Social and contact links'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
                    for (var i = 0; i < 4; i++) _contactField(i),
                    Text(
                      context.tr(
                        'Clear a field to remove it from your profile.',
                      ),
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
            ),
      bottomNavigationBar: _initial == null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
