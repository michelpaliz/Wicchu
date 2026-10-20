import 'package:flutter/material.dart';

import '../localization/app_language.dart';
import '../services/app_update_service.dart';
import '../theme/wicchu_icons.dart';

class AppUpdateDialog extends StatefulWidget {
  const AppUpdateDialog({
    super.key,
    required this.update,
    required this.onUpdate,
  });

  final AppUpdateInfo update;
  // False means the user cancelled the native update; errors remain retryable.
  final Future<bool> Function() onUpdate;

  @override
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<AppUpdateDialog> {
  bool _opening = false;
  bool _failed = false;
  final _errorKey = GlobalKey();

  Future<void> _update() async {
    if (_opening) return;
    setState(() {
      _opening = true;
      _failed = false;
    });
    try {
      final opened = await widget.onUpdate();
      if (opened && mounted && !widget.update.required) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _failed = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final errorContext = _errorKey.currentContext;
          if (mounted && errorContext != null) {
            Scrollable.ensureVisible(errorContext);
          }
        });
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final update = widget.update;
    return PopScope(
      canPop: !update.required && !_opening,
      child: AlertDialog(
        scrollable: true,
        icon: const Icon(WicchuIcons.downloadSimple),
        title: Text(
          context.tr(
            update.required
                ? 'Update Wicchu to continue'
                : 'A new Wicchu update is available',
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              update.latestVersion.isEmpty
                  ? context.tr('A new version is ready to install.')
                  : context.tr('Version {version} is ready to install.', {
                      'version': update.latestVersion,
                    }),
            ),
            if (update.releaseNotes.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(context.tr("What's new"), style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Text(update.releaseNotes),
            ],
            if (_failed) ...[
              const SizedBox(height: 16),
              Semantics(
                key: _errorKey,
                liveRegion: true,
                child: Text(
                  context.tr('Could not open the store. Please try again.'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (!update.required)
            TextButton(
              onPressed: _opening ? null : () => Navigator.pop(context),
              child: Text(context.tr('Later')),
            ),
          FilledButton.icon(
            onPressed: _opening ? null : _update,
            icon: _opening
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(WicchuIcons.arrowSquareOut),
            label: Text(
              context.tr(_opening ? 'Opening update…' : 'Update now'),
            ),
          ),
        ],
      ),
    );
  }
}
