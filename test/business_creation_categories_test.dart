import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/domain/community_repository.dart';
import 'package:wicchu/features/admin/create_community_page.dart';

class _Repository extends DemoCommunityRepository {
  CreateCommunityInput? input;
  Community? created;
  @override
  Future<Community> createCommunity(CreateCommunityInput value) async {
    input = value;
    return created = await super.createCommunity(value);
  }
}

void main() {
  for (final custom in [false, true]) {
    testWidgets(
      'business creation persists ${custom ? 'selected categories' : 'Posts fallback'}',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(430, 950));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final repository = _Repository();
        await tester.pumpWidget(
          MaterialApp(
            home: CreateCommunityPage(
              repository: repository,
              initialType: CommunityType.publicProfile,
              locateCurrentTown: () async =>
                  const Town(id: 'town-1', name: 'Town', countryCode: 'EC'),
            ),
          ),
        );
        final category = find.byType(DropdownButtonFormField<ProfileCategory>);
        await tester.ensureVisible(category);
        await tester.tap(category);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Local business').last);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField).first, 'My shop');
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Use my current location'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
        await tester.pumpAndSettle();
        expect(find.text('Products'), findsOneWidget);
        if (custom) {
          await tester.tap(find.text('Offers'));
          final name = find.byKey(const ValueKey('business-category-name'));
          await tester.enterText(name, '  Cakes  ');
          await tester.ensureVisible(find.byTooltip('Add category'));
          await tester.tap(find.byTooltip('Add category'));
          await tester.pumpAndSettle();
          expect(find.text('Cakes'), findsOneWidget);
          await tester.enterText(name, 'cakes');
          await tester.ensureVisible(find.byTooltip('Add category'));
          await tester.tap(find.byTooltip('Add category'));
          await tester.pumpAndSettle();
          expect(find.text('This category already exists.'), findsOneWidget);
        }
        await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
        await tester.pumpAndSettle();
        for (final label in custom ? ['Offers', 'Cakes'] : ['Posts']) {
          expect(find.text(label), findsOneWidget);
        }
        await tester.tap(find.text('Edit information'));
        await tester.pumpAndSettle();
        for (var step = 0; step < 3; step++) {
          await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
          await tester.pumpAndSettle();
        }
        expect(find.text('My shop'), findsOneWidget);
        await tester.tap(find.widgetWithText(FilledButton, 'Create space'));
        await tester.pumpAndSettle();
        final expected = custom ? ['Offers', 'Cakes'] : ['Posts'];
        expect(repository.input?.categoryNames, expected);
        expect(
          (await repository.listCategories(
            repository.created!.id,
          )).map((c) => c.name),
          expected,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
