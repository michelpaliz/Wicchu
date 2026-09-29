import 'package:flutter/material.dart';
import '../domain/community_repository.dart';

/// Invalidate visible and stacked screens only after a successful server change.
final _changes = Expando<ValueNotifier<int>>();
ValueNotifier<int> _notifier(CommunityRepository repository) =>
    _changes[repository] ??= ValueNotifier<int>(0);

void notifyBlockVisibilityChanged(CommunityRepository repository) =>
    _notifier(repository).value++;

mixin BlockVisibilityListener<T extends StatefulWidget> on State<T> {
  CommunityRepository get visibilityRepository;
  void reloadBlockVisibility();
  ChangeNotifier? _visibilityChanges;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = _notifier(visibilityRepository);
    if (identical(next, _visibilityChanges)) return;
    _visibilityChanges?.removeListener(_changed);
    _visibilityChanges = next..addListener(_changed);
  }

  void _changed() {
    if (mounted) reloadBlockVisibility();
  }

  @override
  void dispose() {
    _visibilityChanges?.removeListener(_changed);
    super.dispose();
  }
}
