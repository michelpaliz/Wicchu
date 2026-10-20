import 'package:flutter/widgets.dart';

/// Shares the app-level update dialog with settings and other signed-in routes.
class AppUpdateScope extends InheritedWidget {
  const AppUpdateScope({
    super.key,
    required this.checkForUpdates,
    required super.child,
  });

  final Future<void> Function() checkForUpdates;

  static AppUpdateScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppUpdateScope>();

  @override
  bool updateShouldNotify(AppUpdateScope oldWidget) =>
      checkForUpdates != oldWidget.checkForUpdates;
}
