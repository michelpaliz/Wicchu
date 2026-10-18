import 'package:flutter/material.dart';

import 'app_language.dart';

String? activityStatusText(
  BuildContext context, {
  required bool isOnline,
  DateTime? lastActiveAt,
  DateTime? now,
}) {
  if (isOnline) return context.tr('Active now');
  if (lastActiveAt == null) return null;

  final current = now ?? DateTime.now();
  final active = lastActiveAt.toLocal();
  final difference = current.difference(active);
  if (difference.inMinutes < 60) {
    return context.tr('Active {count} min ago', {
      'count':
          '${difference.isNegative ? 1 : difference.inMinutes.clamp(1, 59)}',
    });
  }
  if (difference.inHours < 24 &&
      active.day == current.day &&
      active.month == current.month &&
      active.year == current.year) {
    return context.tr('Active {count} hr ago', {
      'count': '${difference.inHours}',
    });
  }

  final activeDay = DateTime(active.year, active.month, active.day);
  final currentDay = DateTime(current.year, current.month, current.day);
  final dayDifference = currentDay.difference(activeDay).inDays;
  if (dayDifference == 1) {
    final time = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(active));
    return context.tr('Active yesterday at {time}', {'time': time});
  }
  if (dayDifference <= 7) {
    return context.tr('Active {count} days ago', {'count': '$dayDifference'});
  }
  return context.tr('Active over a week ago');
}
