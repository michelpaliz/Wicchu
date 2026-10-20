import 'dart:async';
import 'package:wicchu/domain/community_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/admin/create_community_page.dart';
import 'package:wicchu/localization/app_language.dart';
import 'package:wicchu/services/place_search_service.dart';
import 'package:wicchu/theme/wicchu_icons.dart';
import 'package:wicchu/theme/wicchu_theme.dart';

class _LocationRepository extends DemoCommunityRepository {
  (double, double)? coordinates;
  final suggestions = Completer<CategorySuggestions>();
  int suggestionRequests = 0;
  @override
  Future<CategorySuggestions> getCategorySuggestions({
    required CommunityType spaceType,
    required String subject,
    required String language,
  }) {
    suggestionRequests++;
    return suggestions.future;
  }

  @override
  Future<Town> locateTown({
    required double latitude,
    required double longitude,
  }) async {
    coordinates = (latitude, longitude);
    return const Town(id: 'remote-town', name: 'Echeandía', countryCode: 'EC');
  }
}

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'creation preserves edits and validates categories (${dark ? 'dark' : 'light'})',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repository = _LocationRepository();
        var gpsRequests = 0;
        await tester.pumpWidget(
          AppLanguageScope(
            languageCode: 'en',
            onLanguageChanged: (_) {},
            child: MaterialApp(
              theme: dark ? WicchuTheme.dark : WicchuTheme.light,
              home: CreateCommunityPage(
                repository: repository,
                locateCurrentTown: () async {
                  gpsRequests++;
                  throw Exception(
                    'Location permission was denied. You can search for a location instead.',
                  );
                },
                searchPlaces: (query, language) async {
                  expect(query, 'Echeandia');
                  return const [
                    PlaceResult(
                      name: 'Echeandía',
                      region: 'Bolívar',
                      country: 'Ecuador',
                      latitude: -1.43,
                      longitude: -79.28,
                    ),
                  ];
                },
              ),
            ),
          ),
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Community name'),
          'Remote community',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
        await tester.pumpAndSettle();
        expect(gpsRequests, 0);
        await tester.tap(find.text('Search city or place'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('place-search')),
          'Echeandia',
        );
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Echeandía'));
        await tester.pumpAndSettle();
        expect(find.text('Echeandía, Bolívar, Ecuador'), findsOneWidget);
        expect(repository.coordinates, (-1.43, -79.28));
        expect(gpsRequests, 0);
        await tester.tap(find.text('Use my current location'));
        await tester.pumpAndSettle();
        expect(gpsRequests, 1);
        final continueAction = tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
            .onPressed!;
        await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
        await tester.pump();
        continueAction();
        await tester.pump();
        expect(repository.suggestionRequests, 1);
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed,
          isNull,
        );
        expect(find.text('Step 2 of 4'), findsOneWidget);
        repository.suggestions.complete(
          const CategorySuggestions(
            template: 'default',
            categories: [
              CategorySuggestion(key: 'general', name: 'General'),
              CategorySuggestion(key: 'events', name: 'Events'),
            ],
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Step 3 of 4'), findsOneWidget);
        expect(find.text('Organize your space'), findsOneWidget);
        expect(
          find.text(
            'Suggestions are generated once for each new space. You can customize them before creating it.',
          ),
          findsOneWidget,
        );
        tester.view.physicalSize = const Size(320, 844);
        tester.platformDispatcher.textScaleFactorTestValue = 1.5;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpAndSettle();
        expect(find.text('Recommended'), findsWidgets);
        expect(find.byIcon(WicchuIcons.dotsThreeVertical), findsWidgets);
        await tester.ensureVisible(find.byTooltip('Rename category').first);
        await tester.tap(find.byTooltip('Rename category').first);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextField, 'Category name'),
          'Community updates',
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await tester.pumpAndSettle();
        expect(find.text('Community updates'), findsOneWidget);
        final categoryRow = find.byKey(
          const ValueKey('creation-category-Community updates'),
        );
        expect(tester.widget<ListTile>(categoryRow).onTap, isNotNull);
        await tester.tap(categoryRow);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<Checkbox>(
                find.descendant(
                  of: categoryRow,
                  matching: find.byType(Checkbox),
                ),
              )
              .value,
          isFalse,
        );
        await tester.tap(categoryRow);
        await tester.pumpAndSettle();
        final categoryInput = find.widgetWithText(TextField, 'Add a category');
        await tester.ensureVisible(categoryInput);
        await tester.enterText(categoryInput, 'Community updates');
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Add category'));
        await tester.pumpAndSettle();
        expect(find.text('This category already exists.'), findsOneWidget);
        expect(
          tester
              .renderObject<RenderParagraph>(
                find.text('This category already exists.'),
              )
              .didExceedMaxLines,
          isFalse,
          reason: 'Validation must remain readable with enlarged text.',
        );
        await tester.enterText(categoryInput, 'Neighbourhood recommendations');
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Add category'));
        await tester.pumpAndSettle();
        expect(find.text('This category already exists.'), findsNothing);
        expect(find.text('Neighbourhood recommendations'), findsOneWidget);
        // Revising the subject must not replace the user's category choices.
        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Subject or purpose'),
          'Local news and events',
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
        await tester.pumpAndSettle();
        expect(find.text('Step 3 of 4'), findsOneWidget);
        expect(find.text('Community updates'), findsOneWidget);
        expect(repository.suggestionRequests, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
