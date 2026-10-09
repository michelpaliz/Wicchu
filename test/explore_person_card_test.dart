import 'package:wicchu/theme/wicchu_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/main/explore_person_card.dart';
import 'package:wicchu/theme/wicchu_theme.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'person card handles long identity and large text in ${dark ? 'dark' : 'light'} mode',
      (tester) async {
        var taps = 0;
        const person = PeopleSearchResult(
          id: 'long-profile',
          name: 'Chavela Morales with a very long display name',
          userName: '@chavela_morales_with_a_very_long_username',
          sharedCommunityCount: 3,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? WicchuTheme.dark : WicchuTheme.light,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 288,
                  child: MediaQuery(
                    data: const MediaQueryData(
                      textScaler: TextScaler.linear(2),
                    ),
                    child: ExplorePersonCard(
                      person: person,
                      onTap: () => taps++,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('CM'), findsOneWidget);
        expect(
          find.text('@chavela_morales_with_a_very_long_username'),
          findsOneWidget,
        );
        expect(find.text('3 shared communities'), findsOneWidget);
        await tester.tap(find.byType(ExplorePersonCard));
        expect(taps, 1);
      },
    );
  }

  testWidgets(
    'zero shared communities and missing username omit secondary lines',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: WicchuTheme.light,
          home: Scaffold(
            body: ExplorePersonCard(
              person: const PeopleSearchResult(
                id: 'person',
                name: 'Test User',
                userName: '',
                sharedCommunityCount: 0,
              ),
              onTap: () {},
            ),
          ),
        ),
      );
      expect(find.text('TU'), findsOneWidget);
      expect(find.text('0 shared communities'), findsNothing);
      expect(find.byIcon(WicchuIcons.users), findsNothing);
      expect(find.text('@'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
