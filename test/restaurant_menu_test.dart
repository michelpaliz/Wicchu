import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/features/community/create_post_page.dart';
import 'package:wicchu/features/community/post_card.dart';

void main() {
  testWidgets('food business owners can choose the today menu composer', (
    tester,
  ) async {
    final community = Community(
      id: 'restaurant',
      name: 'Como en Casa',
      description: '',
      town: const Town(id: 'town', name: 'Echeandía', countryCode: 'EC'),
      visibility: CommunityVisibility.public,
      createdBy: 'owner',
      createdAt: DateTime.now(),
      myRole: CommunityRole.owner,
      type: CommunityType.publicProfile,
      profileCategory: ProfileCategory.localBusiness,
      businessServices: const [
        BusinessService.food,
        BusinessService.retail,
        BusinessService.transport,
        BusinessService.realEstate,
        BusinessService.professionalServices,
      ],
      businessFulfillmentOptions: const [BusinessFulfillmentOption.delivery],
    );
    const category = CommunityCategory(
      id: 'posts',
      communityId: 'restaurant',
      name: 'Posts',
      description: '',
      icon: '🍴',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CreatePostPage(
          community: community,
          repository: DemoCommunityRepository(),
          categories: const [category],
        ),
      ),
    );

    expect(find.byKey(const ValueKey('post-kind-todayMenu')), findsOneWidget);
    expect(find.byKey(const ValueKey('post-kind-retailOffer')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('post-kind-transportTrip')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('post-kind-realEstate')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('post-kind-professionalService')),
      findsOneWidget,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -350));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('post-kind-todayMenu')));
    await tester.tap(find.byKey(const ValueKey('next-post-step')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('menu-dish-0')), findsOneWidget);
    expect(find.text('Delivery'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('menu-dish-0')),
      'Sancocho',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('next-post-step')));
    await tester.pumpAndSettle();
    expect(find.text('Category'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('next-post-step')));
    await tester.pumpAndSettle();
    final preview = tester.widget<PostCard>(find.byType(PostCard));
    expect(preview.text, contains('Sancocho'));
    expect(preview.post?.todayMenu?.dishes.single.name, 'Sancocho');
    expect(
      preview.post?.todayMenu?.fulfillmentOptions,
      contains(BusinessFulfillmentOption.delivery),
    );
    expect(preview.repository, isNull);
    expect(find.text('Copy description'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('today menu post renders dishes and fulfillment options', (
    tester,
  ) async {
    final post = CommunityPost(
      id: 'menu-post',
      communityId: 'restaurant',
      categoryId: 'posts',
      authorId: 'owner',
      text: "🍴 Today's menu",
      status: PostStatus.published,
      createdAt: DateTime.now(),
      todayMenu: TodayMenu(
        expiresAt: DateTime.now().add(const Duration(hours: 4)),
        dishes: const [
          TodayMenuDish(name: 'Sancocho', price: r'$5'),
          TodayMenuDish(name: 'Seco de carne', available: false),
        ],
        fulfillmentOptions: const [
          BusinessFulfillmentOption.delivery,
          BusinessFulfillmentOption.pickup,
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PostCard(
            post: post,
            category: 'Posts',
            icon: '🍴',
            community: 'Como en Casa',
            author: 'Como en Casa',
            time: 'Now',
            text: post.text,
            showActions: false,
          ),
        ),
      ),
    );

    expect(find.text("Today's menu"), findsOneWidget);
    expect(find.text('Sancocho'), findsOneWidget);
    expect(find.text(r'$5'), findsOneWidget);
    expect(find.text('Seco de carne'), findsOneWidget);
    expect(find.text('Delivery'), findsOneWidget);
    expect(find.text('Pickup'), findsOneWidget);
  });
}
