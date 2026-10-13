import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/community/category_notifications_sheet.dart';
import 'package:wicchu/theme/wicchu_theme.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'category switches, master toggle and reset stay consistent; dark=$dark',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? WicchuTheme.dark : WicchuTheme.light,
            home: const Scaffold(
              body: CategoryNotificationsSheet(
                categories: [
                  CommunityCategory(
                    id: 'news',
                    communityId: 'c',
                    name: 'News',
                    icon: '📰',
                  ),
                  CommunityCategory(
                    id: 'events',
                    communityId: 'c',
                    name: 'Events',
                    icon: '📅',
                  ),
                ],
                initialOrder: ['all', 'news', 'events'],
                defaultOrder: ['all', 'news', 'events'],
                initialPreferences:
                    ScopedNotificationPreferences.communityDefaults(),
              ),
            ),
          ),
        );
        final all = find.byKey(const ValueKey('all-category-notifications'));
        final news = find.byKey(const ValueKey('category-notification-news'));
        final events = find.byKey(
          const ValueKey('category-notification-events'),
        );
        bool enabled(Finder finder) =>
            tester.widget<SwitchListTile>(finder).value;
        expect(enabled(all), isTrue);
        await tester.ensureVisible(news);
        await tester.pumpAndSettle();
        await tester.tap(news);
        await tester.pumpAndSettle();
        expect(enabled(news), isFalse);
        expect(enabled(events), isTrue);
        expect(enabled(all), isFalse);
        await tester.tap(find.text('Reset selection'));
        await tester.pumpAndSettle();
        expect(enabled(news), isTrue);
        expect(enabled(events), isTrue);
        expect(enabled(all), isTrue);
        await tester.ensureVisible(all);
        await tester.pumpAndSettle();
        await tester.tap(all);
        await tester.pumpAndSettle();
        expect(enabled(news), isFalse);
        expect(enabled(events), isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
