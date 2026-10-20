import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/domain/community_repository.dart';
import 'package:wicchu/features/community/community_profile_page.dart';
import 'package:wicchu/features/community/create_post_page.dart';
import 'package:wicchu/features/admin/admin_dashboard_page.dart';
import 'package:wicchu/theme/wicchu_theme.dart';
import 'package:wicchu/widgets/compact_profile_description.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets('business empty actions and administration dark=$dark', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = DemoCommunityRepository();
      final page = await repository.createCommunity(
        const CreateCommunityInput(
          name: 'Business',
          description: 'A local business.',
          town: Town(id: 'town-1', name: 'Town', countryCode: 'ES'),
          visibility: CommunityVisibility.public,
          categoryNames: ['General'],
          type: CommunityType.publicProfile,
          profileCategory: ProfileCategory.localBusiness,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? WicchuTheme.dark : WicchuTheme.light,
          home: CommunityProfilePage(community: page, repository: repository),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('community-composer-entry')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('space-profile-create-post')),
        findsNothing,
      );
      expect(find.byTooltip('Manage business'), findsNothing);
      expect(find.text('Your page is ready to publish'), findsOneWidget);
      final create = find.widgetWithText(FilledButton, 'Create post');
      await tester.ensureVisible(create);
      await tester.pumpAndSettle();
      await tester.tap(create);
      await tester.pumpAndSettle();
      expect(
        tester.widget<CreatePostPage>(find.byType(CreatePostPage)).community.id,
        page.id,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('business-top-options')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Create post'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<CreatePostPage>(find.byType(CreatePostPage)).community.id,
        page.id,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('business-top-options')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Manage business'));
      await tester.tap(find.text('Manage business'));
      await tester.pumpAndSettle();
      expect(find.byType(AdminDashboardPage), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      final category = (await repository.listCategories(page.id)).first;
      await repository.createPost(
        page.id,
        CreatePostInput(categoryId: category.id, text: 'First update'),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? WicchuTheme.dark : WicchuTheme.light,
          home: CommunityProfilePage(
            key: const ValueKey('populated'),
            community: page,
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('community-composer-entry')),
        findsOneWidget,
      );
      expect(find.text('Your page is ready to publish'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  for (final dark in [false, true]) {
    testWidgets(
      'business information stays compact and menu stays fixed dark=$dark',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 740));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final repository = _InformationRepository();
        final page = Community(
          id: 'restaurant',
          createdBy: 'owner',
          createdAt: DateTime(2026),
          name: 'Restaurant',
          description: List.filled(
            12,
            'Fresh meals and local seasonal dishes.',
          ).join(' '),
          town: const Town(id: 'town-1', name: 'Town', countryCode: 'ES'),
          visibility: CommunityVisibility.public,
          type: CommunityType.publicProfile,
          profileCategory: ProfileCategory.localBusiness,
          businessServices: [BusinessService.food],
        );
        repository.page = page;
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? WicchuTheme.dark : WicchuTheme.light,
            home: CommunityProfilePage(
              community: page,
              repository: repository,
              screen: CommunityScreen.information,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final description = find.byKey(
          const ValueKey('page-header-description'),
        );
        expect(tester.widget<Text>(description).maxLines, 4);
        expect(
          tester.getTopLeft(find.text('Opening hours')).dy,
          lessThan(tester.getTopLeft(description).dy),
        );
        final menu = find.byKey(
          const ValueKey('business-primary-bottom-action'),
        );
        final menuPosition = tester.getTopLeft(menu);
        final toggle = find.byKey(
          const ValueKey('page-header-description-toggle'),
        );
        await tester.ensureVisible(toggle);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(tester.widget<Text>(description).maxLines, isNull);
        expect(tester.getTopLeft(menu), menuPosition);
        await tester.scrollUntilVisible(
          find.text('Creation date'),
          300,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(menu), menuPosition);
      },
    );
  }
  testWidgets('long compact description expands and collapses', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 240,
              child: ExpandableProfileDescription(
                text: List.filled(30, 'Local business news.').join(' '),
              ),
            ),
          ),
        ),
      ),
    );
    final text = find.byKey(const ValueKey('page-header-description'));
    expect(tester.widget<Text>(text).maxLines, 3);
    await tester.tap(find.text('See more'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(text).maxLines, isNull);
    await tester.ensureVisible(find.text('See less'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('See less'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(text).maxLines, 3);
  });
}

class _InformationRepository extends DemoCommunityRepository {
  late Community page;
  @override
  Future<Community> getCommunity(String id) async => page;
}
