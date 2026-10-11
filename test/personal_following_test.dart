import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/features/profile/member_profile_page.dart';

void main() {
  testWidgets(
    'member profile follows optimistically and exposes follow lists',
    (tester) async {
      final repository = DemoCommunityRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: MemberProfilePage(
            userId: 'creator-user',
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('profile-follow-button')),
        findsOneWidget,
      );
      expect(find.text('Follow'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('profile-follow-button')));
      await tester.pumpAndSettle();
      expect(find.text('Following'), findsWidgets);

      await tester.tap(find.byKey(const ValueKey('profile-followers-count')));
      await tester.pumpAndSettle();
      expect(find.text('No followers yet'), findsOneWidget);
    },
  );

  testWidgets('profile owner can open the personal publication composer', (
    tester,
  ) async {
    final repository = DemoCommunityRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: MemberProfilePage(userId: 'current-user', repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-create-publication')));
    await tester.pumpAndSettle();

    expect(find.text('My profile'), findsWidgets);
    expect(find.text('Photos or video'), findsOneWidget);

    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
    expect(find.text('Choose where to publish'), findsOneWidget);
    expect(find.text('Personal publication'), findsWidgets);
  });
}
