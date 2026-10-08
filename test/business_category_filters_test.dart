import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/community/community_profile_page.dart';
import 'package:wicchu/features/community/category_empty_state.dart';
import 'package:wicchu/widgets/profile_post_grid.dart';
import 'package:wicchu/features/admin/admin_management_pages.dart';

class _Repository extends DemoCommunityRepository {
  @override
  Future<List<CommunityCategory>> listCategories(String id) async => [
    for (final name in ['Products', 'Offers', 'News'])
      CommunityCategory(id: name, communityId: id, name: name, icon: '🏷️'),
  ];
  @override
  Future<List<CommunityPost>> listPosts(
    String id, {
    String? categoryId,
    String? query,
    String? sort,
  }) async => [
    for (final name in ['Products', 'Offers'])
      CommunityPost(
        id: name,
        communityId: id,
        categoryId: name,
        authorId: 'owner',
        text: '$name post',
        status: PostStatus.published,
        createdAt: DateTime.now(),
      ),
  ];
}

void main() {
  for (final role in CommunityRole.values) {
    testWidgets('page category editor access for $role', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final community = Community(
        id: 'business',
        name: 'Shop',
        description: '',
        town: const Town(id: 'town', name: 'Town', countryCode: 'EC'),
        visibility: CommunityVisibility.public,
        createdBy: 'owner',
        createdAt: DateTime.now(),
        type: CommunityType.publicProfile,
        profileCategory: ProfileCategory.localBusiness,
        myRole: role,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CommunityProfilePage(
            community: community,
            repository: _Repository(),
            screen: CommunityScreen.information,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final entry = find.byKey(const ValueKey('information-edit-categories'));
      if (role == CommunityRole.owner || role == CommunityRole.admin) {
        await tester.ensureVisible(entry);
        await tester.tap(entry);
        await tester.pumpAndSettle();
        expect(find.byType(CategoryManagementPage), findsOneWidget);
        expect(find.text('Products'), findsOneWidget);
        expect(find.text('Add category'), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(entry, findsOneWidget);
      } else {
        expect(entry, findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'business categories filter posts and show category empty states',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final community = Community(
        id: 'business',
        name: 'Shop',
        description: '',
        town: const Town(id: 'town', name: 'Town', countryCode: 'EC'),
        visibility: CommunityVisibility.public,
        createdBy: 'owner',
        createdAt: DateTime.now(),
        type: CommunityType.publicProfile,
        profileCategory: ProfileCategory.localBusiness,
        myRole: CommunityRole.owner,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CommunityProfilePage(
            community: community,
            repository: _Repository(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final filters = find.byKey(const ValueKey('business-category-filters'));
      expect(filters, findsOneWidget);
      expect(find.text('Media'), findsNothing);
      expect(find.text('Polls'), findsNothing);
      final products = find.descendant(
        of: filters,
        matching: find.text('Products'),
      );
      await tester.ensureVisible(products);
      await tester.tap(products);
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<ProfilePostTile>(find.byType(ProfilePostTile))
            .map((tile) => tile.post.categoryId),
        ['Products'],
      );
      await tester.tap(
        find.descendant(of: filters, matching: find.text('News')),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CategoryEmptyState>(find.byType(CategoryEmptyState))
            .category,
        'News',
      );
      await tester.tap(
        find.descendant(of: filters, matching: find.text('All')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ProfilePostTile), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );
}
