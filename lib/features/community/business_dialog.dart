import 'package:flutter/material.dart';

/// Wait for removal of the dialog's widgets before callers dispose controllers.
Future<T?> showBusinessDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final route = DialogRoute<T>(context: context, builder: builder);
  final result = await navigator.push(route);
  await route.completed;
  return result;
}
