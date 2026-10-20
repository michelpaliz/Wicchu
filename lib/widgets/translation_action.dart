import 'package:flutter/material.dart';
import '../localization/app_language.dart';
import '../theme/wicchu_icons.dart';
import '../theme/wicchu_theme.dart';

/// A shared, quiet action for translating feed and comment text.
class TranslationAction extends StatelessWidget {
  const TranslationAction({
    super.key,
    required this.translating,
    required this.translated,
    required this.onPressed,
  });

  final bool translating;
  final bool translated;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final label = context.tr(
      translating
          ? 'Translating…'
          : translated
          ? 'View original'
          : 'Translate',
    );
    return Semantics(
      liveRegion: translating,
      child: TextButton.icon(
        onPressed: translating ? null : onPressed,
        style: TextButton.styleFrom(
          foregroundColor: translated
              ? colors.primary
              : colors.onSurfaceVariant,
          textStyle: WicchuPostTypography.action(context),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          minimumSize: const Size(48, 48),
        ),
        icon: translating
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(WicchuIcons.globe, size: 16),
        label: Text(label),
      ),
    );
  }
}

class TranslationAttribution extends StatelessWidget {
  const TranslationAttribution({super.key, this.languageCode});

  final String? languageCode;

  @override
  Widget build(BuildContext context) {
    final language = languageCode?.toLowerCase().split(RegExp('[-_]')).first;
    final label = switch (language) {
      'es' => 'Automatically translated to Spanish',
      'en' => 'Automatically translated to English',
      _ => 'Translated automatically',
    };
    return Semantics(
      liveRegion: true,
      child: Text(
        context.tr(label),
        style: WicchuPostTypography.metadata(context),
      ),
    );
  }
}
