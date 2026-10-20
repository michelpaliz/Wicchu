import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/community/community_profile_page.dart';
import 'package:wicchu/widgets/blinking_follow_icon.dart';

void main() {
  for (final reducedMotion in [false, true]) {
    testWidgets(
      'follow blink respects reduced motion=$reducedMotion and settles visible',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reducedMotion),
              child: const BlinkingFollowIcon(child: Icon(Icons.person_add)),
            ),
          ),
        );
        final fade = find.descendant(
          of: find.byType(BlinkingFollowIcon),
          matching: find.byType(FadeTransition),
        );
        await tester.pump(const Duration(milliseconds: 425));
        final opacity = tester.widget<FadeTransition>(fade).opacity.value;
        expect(opacity, reducedMotion ? 1 : lessThan(1));
        await tester.pumpAndSettle();
        expect(
          tester.widget<FadeTransition>(fade).opacity.value,
          closeTo(1, .001),
        );
      },
    );
  }
  for (final type in CommunityType.values) {
    testWidgets('header shows entire description for $type', (tester) async {
      final summary = List.filled(
        6,
        'A full line of the page description.',
      ).join('\n\n');
      final community = Community(
        id: 'description-test',
        name: 'Page',
        description: '',
        shortDescription: summary,
        town: const Town(id: 'town', name: 'Town', countryCode: 'EC'),
        visibility: CommunityVisibility.public,
        createdBy: 'owner',
        createdAt: DateTime(2026),
        type: type,
        profileCategory: type == CommunityType.publicProfile
            ? ProfileCategory.localBusiness
            : null,
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
      final text = tester.widget<Text>(
        find.byKey(const ValueKey('page-header-description')),
      );
      expect(text.textSpan?.toPlainText(), summary);
      expect(text.maxLines, type == CommunityType.publicProfile ? 3 : null);
      expect(text.style?.fontSize, 13);
      expect(
        find.byKey(const ValueKey('page-header-description-toggle')),
        type == CommunityType.publicProfile ? findsOneWidget : findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
