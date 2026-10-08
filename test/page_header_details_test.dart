import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/community/community_profile_page.dart';

void main() {
  test('profile summary never falls back to the full About description', () {
    final community = Community(
      id: 'page',
      name: 'My page',
      description: 'This longer About text belongs only on information pages.',
      town: const Town(id: 'town', name: 'Echeandía', countryCode: 'EC'),
      visibility: CommunityVisibility.public,
      createdBy: 'owner',
      createdAt: DateTime(2026),
      type: CommunityType.publicProfile,
    );

    expect(community.profileSummary, isEmpty);
  });

  for (final category in [null, ...ProfileCategory.values]) {
    testWidgets('header location and expandable description for $category', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final descriptionText = [
        'Local updates',
        '',
        List.filled(12, 'Updates and stories from our neighborhood.').join(' '),
      ].join('\n');
      final shortDescription = [
        'Local updates',
        '',
        List.filled(4, 'News and stories from our neighborhood.').join(' '),
      ].join('\n');
      final community = Community(
        id: 'page',
        name: 'My page',
        shortDescription: shortDescription,
        description: descriptionText,
        town: const Town(id: 'town', name: 'Echeandía', countryCode: 'EC'),
        visibility: CommunityVisibility.public,
        createdBy: 'owner',
        createdAt: DateTime.now(),
        type: category == null
            ? CommunityType.community
            : CommunityType.publicProfile,
        profileCategory: category,
        businessServices: category == ProfileCategory.localBusiness
            ? const [BusinessService.gardening, BusinessService.pools]
            : const [],
        businessContact: category == ProfileCategory.localBusiness
            ? const BusinessContact(phone: '+34123456789')
            : const BusinessContact(),
        myRole: CommunityRole.owner,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CommunityProfilePage(
            community: community,
            repository: DemoCommunityRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('page-header-location')))
            .data,
        contains(
          category == null
              ? 'Echeandía, Ecuador'
              : category == ProfileCategory.localBusiness
              ? 'Echeandía'
              : 'Echeandía, EC',
        ),
      );
      if (category == null) {
        expect(
          find.byKey(const ValueKey('community-header-metadata')),
          findsOneWidget,
        );
        expect(find.text('0 members'), findsOneWidget);
        expect(find.text('Public'), findsOneWidget);
        expect(find.text('Public community'), findsNothing);
        expect(find.byKey(const ValueKey('page-header-share')), findsNothing);
      } else {
        expect(
          find.byKey(const ValueKey('page-header-share')),
          category == ProfileCategory.localBusiness
              ? findsNothing
              : findsOneWidget,
        );
        expect(find.byKey(const ValueKey('page-header-edit')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('page-header-followers')),
          findsOneWidget,
        );
        expect(find.text('0 followers'), findsOneWidget);
        if (category == ProfileCategory.localBusiness) {
          expect(
            find.byKey(const ValueKey('local-business-contact')),
            findsOneWidget,
          );
          expect(
            tester
                .widget<Text>(
                  find.byKey(const ValueKey('page-header-location')),
                )
                .data,
            'Echeandía, Ecuador',
          );
          expect(
            tester
                .widget<IconButton>(
                  find.byKey(const ValueKey('local-business-contact')),
                )
                .onPressed,
            isNotNull,
          );
        }
      }
      final description = find.byKey(const ValueKey('page-header-description'));
      final toggle = find.byKey(
        const ValueKey('page-header-description-toggle'),
      );
      if (category == ProfileCategory.localBusiness) {
        expect(tester.widget<Text>(description).maxLines, 1);
        expect(tester.widget<Text>(description).data, 'Local updates');
        expect(toggle, findsNothing);
        expect(find.text(descriptionText), findsNothing);
        expect(tester.takeException(), isNull);
        return;
      }
      expect(tester.widget<Text>(description).maxLines, 2);
      expect(
        tester.widget<Text>(description).data,
        startsWith('Local updates\nNews and stories'),
      );
      expect(tester.widget<Text>(description).data, isNot(contains('\n\n')));
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(description).maxLines, isNull);
      expect(tester.widget<Text>(description).data, shortDescription);
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      tester
          .state<NestedScrollViewState>(find.byType(NestedScrollView))
          .outerController
          .jumpTo(0);
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(description).maxLines, 2);
      expect(
        tester.widget<Text>(description).data,
        startsWith('Local updates\nNews and stories'),
      );
      expect(tester.widget<Text>(description).data, isNot(contains('\n\n')));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('restaurant header uses compact primary follow controls', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final community = Community(
      id: 'restaurant',
      name: 'COMIDA RAPIDA',
      shortDescription:
          '¡Bienvenidos a nuestro rincón del sabor!\nHamburguesas y mucho más.',
      description: 'Información completa del restaurante.',
      town: const Town(id: 'town', name: 'Echeandía', countryCode: 'EC'),
      visibility: CommunityVisibility.public,
      createdBy: 'owner',
      createdAt: DateTime(2026),
      type: CommunityType.publicProfile,
      profileCategory: ProfileCategory.localBusiness,
      // Older business records may not have saved services yet.
      businessServices: const [],
      memberCount: 1,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CommunityProfilePage(
          community: community,
          repository: DemoCommunityRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 follower'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('page-header-location')))
          .data,
      'Echeandía, Ecuador',
    );
    expect(find.textContaining('Food'), findsNothing);
    expect(find.byKey(const ValueKey('local-business-follow')), findsOneWidget);
    expect(find.text('Follow'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('local-business-contact')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('page-header-description')))
          .data,
      '¡Bienvenidos a nuestro rincón del sabor!',
    );
  });
}
