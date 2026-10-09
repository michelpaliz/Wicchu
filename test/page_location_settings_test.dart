import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/admin/page_location_settings_page.dart';

void main() {
  for (final apply in [false, true]) {
    testWidgets('location draft ${apply ? 'applies' : 'discards'} on exit', (
      tester,
    ) async {
      final repository = DemoCommunityRepository();
      final community = Community(
        id: 'business',
        name: 'Business',
        description: '',
        town: const Town(id: 'town', name: 'Town', countryCode: 'EC'),
        visibility: CommunityVisibility.public,
        createdBy: 'owner',
        createdAt: DateTime(2026),
        type: CommunityType.publicProfile,
        profileCategory: ProfileCategory.localBusiness,
      );
      PageLocationDraft? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await Navigator.push<PageLocationDraft>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PageLocationSettingsPage(
                        community: community,
                        repository: repository,
                        initial: PageLocationDraft(
                          community.town,
                          '',
                          null,
                          null,
                          false,
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Business address'),
        'New address',
      );
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Unsaved changes'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(apply ? 'Apply' : 'Discard'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Open'), findsOneWidget);
      expect(result?.address, apply ? 'New address' : null);
    });
  }
}
