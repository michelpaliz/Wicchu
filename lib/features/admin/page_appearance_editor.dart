import 'package:flutter/material.dart';
import '../../domain/community_models.dart';

import '../../localization/app_language.dart';
import '../../theme/wicchu_icons.dart';
import '../../widgets/community_header_border.dart';
import '../../widgets/profile_accent_picker.dart';
import '../../widgets/profile_top_bar_glow.dart';

enum PageAppearanceSection {
  color('Profile color'),
  neon('Top bar glow'),
  border('Decorative border');

  const PageAppearanceSection(this.title);
  final String title;
}

typedef PageAppearanceDraft = ({
  String accent,
  bool neon,
  bool border,
  NeonBorderAnimation animation,
  double duration,
});

/// Edits the parent's appearance draft; persistence stays in page settings.
class PageAppearanceEditor extends StatefulWidget {
  const PageAppearanceEditor({
    super.key,
    required this.section,
    required this.value,
  });
  final PageAppearanceSection section;
  final PageAppearanceDraft value;

  @override
  State<PageAppearanceEditor> createState() => _PageAppearanceEditorState();
}

class _PageAppearanceEditorState extends State<PageAppearanceEditor> {
  late PageAppearanceDraft _draft = widget.value;

  Future<void> _chooseColor() async {
    final result = await Navigator.push<PageAppearanceDraft>(
      context,
      MaterialPageRoute(
        builder: (_) => PageAppearanceEditor(
          section: PageAppearanceSection.color,
          value: _draft,
        ),
      ),
    );
    if (result != null && mounted) setState(() => _draft = result);
  }

  @override
  Widget build(BuildContext context) {
    final section = widget.section;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr(section.title))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            context.tr(switch (section) {
              PageAppearanceSection.color =>
                'Choose the color used by your page header and borders.',
              PageAppearanceSection.neon =>
                'Add a glow to the bottom edge of the top bar using your selected color.',
              PageAppearanceSection.border =>
                'Outline the edge between the cover and page information. It uses your profile color without a glow.',
            }),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          Text(
            context.tr('Preview'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 12),
          _AppearancePreview(value: _draft),
          const SizedBox(height: 24),
          if (section == PageAppearanceSection.color) ...[
            Text(
              context.tr(profileAccentLabel(_draft.accent)),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ProfileAccentPicker(
              value: _draft.accent,
              labelBuilder: (key) => context.tr(profileAccentLabel(key)),
              onChanged: (accent) => setState(
                () => _draft = (
                  accent: accent,
                  neon: _draft.neon,
                  border: _draft.border,
                  animation: _draft.animation,
                  duration: _draft.duration,
                ),
              ),
            ),
          ] else if (section == PageAppearanceSection.neon) ...[
            NeonBorderStudio(
              accentColor: _draft.accent,
              enabled: _draft.neon,
              animation: _draft.animation,
              durationSeconds: _draft.duration,
              previewTitle: '',
              previewSubtitle: '',
              showPreview: false,
              toggleTitle: 'Top bar glow',
              toggleSubtitle:
                  'Add a glow to the bottom edge of the top bar using your selected color.',
              onEnabledChanged: (value) => setState(
                () => _draft = (
                  accent: _draft.accent,
                  neon: value,
                  border: _draft.border,
                  animation: _draft.animation,
                  duration: _draft.duration,
                ),
              ),
              onAnimationChanged: (value) => setState(
                () => _draft = (
                  accent: _draft.accent,
                  neon: _draft.neon,
                  border: _draft.border,
                  animation: value,
                  duration: _draft.duration,
                ),
              ),
              onDurationChanged: (value) => setState(
                () => _draft = (
                  accent: _draft.accent,
                  neon: _draft.neon,
                  border: _draft.border,
                  animation: _draft.animation,
                  duration: value,
                ),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.tr('Profile color')),
              subtitle: Text(context.tr(profileAccentLabel(_draft.accent))),
              trailing: const Icon(WicchuIcons.caretRight),
              onTap: _chooseColor,
            ),
          ] else ...[
            SwitchListTile.adaptive(
              key: const ValueKey('header-border-toggle'),
              contentPadding: EdgeInsets.zero,
              title: Text(context.tr('Decorative border')),
              value: _draft.border,
              onChanged: (value) => setState(
                () => _draft = (
                  accent: _draft.accent,
                  neon: _draft.neon,
                  border: value,
                  animation: _draft.animation,
                  duration: _draft.duration,
                ),
              ),
            ),
            Text(context.tr('Uses the existing header color.')),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.tr('Save your changes from page settings.'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, _draft),
                child: Text(context.tr('Apply')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppearancePreview extends StatelessWidget {
  const _AppearancePreview({required this.value});
  final PageAppearanceDraft value;

  @override
  Widget build(BuildContext context) {
    final accent = profileAccentColor(value.accent);
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Column(
            children: [
              SizedBox(
                height: 40,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ColoredBox(color: accent.withValues(alpha: .12)),
                    ),
                    const Center(child: Icon(WicchuIcons.dotsThree)),
                    if (value.neon)
                      Positioned.fill(
                        child: ProfileTopBarGlow(
                          accent: value.accent,
                          animation: value.animation,
                          durationSeconds: value.duration,
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(
                height: 110,
                child: Stack(
                  children: [
                    Positioned.fill(
                      bottom: CommunityHeaderGeometry.overlap,
                      child: ColoredBox(color: accent.withValues(alpha: .18)),
                    ),
                    Positioned(
                      left: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(
                          CommunityHeaderGeometry.cutoutPadding,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          borderRadius: CommunityHeaderGeometry.avatarCorners,
                        ),
                        child: Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: accent,
                              width: CommunityHeaderGeometry.avatarOutline,
                            ),
                          ),
                          child: Icon(
                            WicchuIcons.users,
                            color: accent,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: CommunityHeaderGeometry.membershipPadding,
                        decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          borderRadius:
                              CommunityHeaderGeometry.membershipOuterCorners,
                        ),
                        child: SizedBox(
                          width: CommunityHeaderGeometry.membershipWidth,
                          height: CommunityHeaderGeometry.membershipHeight,
                          child: Icon(WicchuIcons.userCheck, color: accent),
                        ),
                      ),
                    ),
                    if (value.border)
                      Positioned.fill(
                        child: CommunityHeaderBorder(
                          color: accent,
                          cutouts: true,
                          membership: true,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
