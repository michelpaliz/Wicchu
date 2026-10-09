import 'package:wicchu/theme/wicchu_icons.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';
import '../../widgets/profile_accent_picker.dart';

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
  final _controllers = List.generate(3, (_) => TextEditingController());
  final _details = List.generate(4, (_) => TextEditingController());
  EditableMemberProfile? _initial;
  Timer? _usernameDelay;
  int _usernameGeneration = 0;
  bool? _usernameAvailable;
  bool _checkingUsername = false;
  String? _error;
  bool _loading = true;
  bool _saving = false;
  bool _allowPop = false;
  bool _confirmingLeave = false;
  String _accentColor = 'teal';

  @override
  void initState() {
    super.initState();
    for (final controller in _controllers) {
      controller.addListener(_changed);
    }
    for (var index = 0; index < _details.length; index++) {
      _details[index].addListener(index == 1 ? _usernameChanged : _changed);
    }
    _load();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  String get _normalizedUsername =>
      _details[1].text.trim().replaceFirst(RegExp(r'^@+'), '').toLowerCase();

  bool _validUsername(String value) =>
      RegExp(r'^[a-z0-9._]{3,30}$').hasMatch(value) &&
      !RegExp(r'^[._]|[._]$|[._]{2,}').hasMatch(value);

  void _usernameChanged() {
    if (!mounted || _loading) return;
    _usernameDelay?.cancel();
    final generation = ++_usernameGeneration;
    final value = _normalizedUsername;
    if (value == _initial?.userName.toLowerCase()) {
      setState(() {
        _checkingUsername = false;
        _usernameAvailable = true;
      });
      return;
    }
    if (!_validUsername(value)) {
      setState(() {
        _checkingUsername = false;
        _usernameAvailable = null;
      });
      return;
    }
    setState(() {
      _checkingUsername = true;
      _usernameAvailable = null;
    });
    _usernameDelay = Timer(const Duration(milliseconds: 350), () async {
      try {
        final available = await widget.repository.isUsernameAvailable(value);
        if (!mounted || generation != _usernameGeneration) return;
        setState(() {
          _checkingUsername = false;
          _usernameAvailable = available;
        });
        _form.currentState?.validate();
      } catch (error) {
        if (!mounted || generation != _usernameGeneration) return;
        setState(() {
          _checkingUsername = false;
          _usernameAvailable = null;
          _error = context.trError(error);
        });
      }
    });
  }

  bool get _dirty {
    final initial = _initial;
    if (initial == null) return false;
    final values = [
      initial.name,
      initial.userName,
      initial.bio,
      initial.location,
      initial.socialLinks.whatsapp,
      initial.socialLinks.facebook,
      initial.socialLinks.instagram,
    ];
    final current = [
      _details[0].text.trim(),
      _normalizedUsername,
      _details[2].text.trim(),
      _details[3].text.trim(),
      ..._controllers.map((controller) => controller.text.trim()),
    ];
    return _accentColor != initial.accentColor ||
        List.generate(
          values.length,
          (i) => current[i] != values[i],
        ).contains(true);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await widget.repository.getEditableProfile();
      if (!mounted) return;
      _initial = profile;
      _accentColor = profile.accentColor;
      final details = [
        profile.name,
        profile.userName,
        profile.bio,
        profile.location,
      ];
      for (var i = 0; i < 4; i++) {
        _details[i].text = details[i];
      }
      final values = [
        profile.socialLinks.whatsapp,
        profile.socialLinks.facebook,
        profile.socialLinks.instagram,
      ];
      for (var i = 0; i < values.length; i++) {
        _controllers[i].text = values[i];
      }
      _usernameAvailable = true;
    } catch (error) {
      if (mounted) _error = context.trError(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _usernameDelay?.cancel();
    for (final controller in [..._controllers, ..._details]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _leave() async {
    if (_saving || _confirmingLeave || _allowPop) return;
    if (_dirty) {
      _confirmingLeave = true;
      FocusScope.of(context).unfocus();
      bool? discard;
      try {
        discard = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            icon: Icon(
              WicchuIcons.notePencil,
              color: Theme.of(dialogContext).colorScheme.primary,
            ),
            title: Text(context.tr('Unsaved changes')),
            content: Text(
              context.tr(
                'Your profile changes have not been saved. If you leave now, they will be lost.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(dialogContext).colorScheme.error,
                ),
                child: Text(context.tr('Leave without saving')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(context.tr('Keep editing')),
              ),
            ],
          ),
        );
      } finally {
        _confirmingLeave = false;
      }
      if (discard != true) return;
    }
    if (!mounted) return;
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
      final initial = _initial!;
      final values = _controllers.map((c) => c.text.trim()).toList();
      await widget.repository.updateEditableProfile(
        EditableMemberProfile(
          name: _details[0].text.trim(),
          userName: _normalizedUsername,
          bio: _details[2].text.trim(),
          location: _details[3].text.trim(),
          socialLinks: SocialLinks(
            whatsapp: values[0].replaceAll(RegExp(r'[ ()-]'), ''),
            facebook: values[1].replaceFirst(RegExp(r'^@'), ''),
            instagram: values[2].replaceFirst(RegExp(r'^@'), ''),
            email: initial.socialLinks.email,
            showOnlineStatus: initial.socialLinks.showOnlineStatus,
          ),
          accentColor: _accentColor,
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
            child: Icon(WicchuIcons.user, color: colors.primary, size: 28),
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
    final label = ['WhatsApp', 'Facebook', 'Instagram'][i];
    final brandColor = [
      const Color(0xff25a95b),
      const Color(0xff1877f2),
      const Color(0xffc13584),
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
                WicchuIcons.chatCircle,
                WicchuIcons.facebookLogo,
                WicchuIcons.camera,
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
                        : TextInputType.url,
                    textInputAction: i == 2
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
                          ][i],
                          icon: i == 1 || i == 2
                              ? WicchuIcons.linkSimple
                              : null,
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
            icon: const Icon(WicchuIcons.caretLeft, size: 20),
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
                          if (i == 1) {
                            final normalized = value
                                .replaceFirst(RegExp(r'^@+'), '')
                                .toLowerCase();
                            final unchanged =
                                normalized == _initial?.userName.toLowerCase();
                            if (!unchanged && !_validUsername(normalized)) {
                              return context.tr(
                                'Use 3–30 letters, numbers, periods, or underscores.',
                              );
                            }
                            if (!unchanged && _usernameAvailable == false) {
                              return context.tr(
                                'This username is already taken.',
                              );
                            }
                          }
                          if (i == 1 && value.startsWith('@')) {
                            return context.tr(
                              'Use 3–30 letters, numbers, periods, or underscores.',
                            );
                          }
                          return null;
                        },
                        decoration:
                            _decoration(
                              hint: i == 2
                                  ? context.tr(
                                      'Tell us about yourself, your interests or what makes you unique…',
                                    )
                                  : i == 3
                                  ? context.tr('Add your location')
                                  : null,
                              icon: [
                                WicchuIcons.user,
                                WicchuIcons.at,
                                WicchuIcons.note,
                                WicchuIcons.mapPin,
                              ][i],
                            ).copyWith(
                              suffixIcon: i != 1
                                  ? null
                                  : _checkingUsername
                                  ? const Padding(
                                      padding: EdgeInsets.all(14),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : _usernameAvailable == true
                                  ? const Icon(
                                      WicchuIcons.checkCircleFill,
                                      color: Colors.green,
                                    )
                                  : _usernameAvailable == false
                                  ? Icon(
                                      WicchuIcons.xCircle,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                    )
                                  : null,
                            ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    const Divider(height: 32),
                    Text(
                      context.tr('Profile color'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.tr(
                        'Choose an accent color for your public profile.',
                      ),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    ProfileAccentPicker(
                      value: _accentColor,
                      labelBuilder: (value) =>
                          context.tr(profileAccentLabel(value)),
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _accentColor = value),
                    ),
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
                    for (var i = 0; i < 3; i++) _contactField(i),
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
                onPressed:
                    _saving ||
                        !_dirty ||
                        _checkingUsername ||
                        _usernameAvailable != true
                    ? null
                    : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(WicchuIcons.check, size: 20),
                label: Text(
                  context.tr(_saving ? 'Saving changes…' : 'Save changes'),
                ),
              ),
            ),
    ),
  );
}
