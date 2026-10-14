import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/community/post_share.dart';
import 'package:wicchu/features/community/post_rules_review_page.dart';

class _SharingRepository extends DemoCommunityRepository {
  _SharingRepository({this.includeOrigin = false});

  final bool includeOrigin;
  int shares = 0;
  bool accepted = false;
  Map<String, String>? destinations;
  @override
  Future<List<Community>> listCommunities({String? query}) async => [
    if (includeOrigin)
      Community(
        id: 'origin',
        name: 'Original community',
        description: '',
        town: const Town(id: 'town', name: 'Town', countryCode: 'EC'),
        visibility: CommunityVisibility.public,
        createdBy: 'owner',
        createdAt: DateTime(2026),
        myRole: CommunityRole.member,
      ),
    Community(
      id: 'community',
      name: 'Echeandia',
      description: '',
      town: const Town(id: 'town', name: 'Town', countryCode: 'EC'),
      visibility: CommunityVisibility.public,
      createdBy: 'owner',
      createdAt: DateTime(2026),
      myRole: CommunityRole.member,
    ),
  ];
  @override
  Future<List<CommunityCategory>> listCategories(String id) async => [
    for (final name in ['General', 'Business'])
      CommunityCategory(id: name, communityId: id, name: name, icon: '💬'),
  ];
  @override
  Future<CommunityRules> listRules(String id) async => CommunityRules(
    rules: const [],
    rulesVersion: 1,
    acceptedRulesVersion: accepted ? 1 : 0,
    acceptanceRequired: !accepted,
    canManage: false,
  );
  @override
  Future<void> acceptRules(String id, int version) async {
    accepted = true;
  }

  @override
  Future<List<CommunityShareResult>> sharePersonalPostToCommunities(
    String postId, {
    required Map<String, String> categoryByCommunity,
    String caption = '',
  }) async {
    if (!accepted) throw StateError('Rules not accepted');
    shares++;
    destinations = Map.of(categoryByCommunity);
    return [
      const CommunityShareResult(
        communityId: 'community',
        status: 'pending_approval',
      ),
    ];
  }
}

Future<void> _openShare(
  WidgetTester tester,
  _SharingRepository repository, {
  Locale locale = const Locale('en'),
  String sourceCommunityId = 'business',
}) async {
  await tester.binding.setSurfaceSize(const Size(430, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => sharePostTo(
              context,
              repository,
              CommunityPost(
                id: 'post',
                communityId: sourceCommunityId,
                categoryId: 'posts',
                authorId: 'author',
                text: 'Business publication',
                status: PostStatus.published,
                createdAt: DateTime(2026),
                canShareToCommunities: true,
              ),
              PostShareDestination.community,
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('community post excludes its source from destinations', (
    tester,
  ) async {
    await _openShare(
      tester,
      _SharingRepository(includeOrigin: true),
      sourceCommunityId: 'origin',
    );
    expect(find.text('Original community'), findsNothing);
    expect(find.text('Echeandia'), findsOneWidget);
  });

  testWidgets(
    'short community list stays compact and comment expands on focus',
    (tester) async {
      await _openShare(tester, _SharingRepository());
      expect(tester.getSize(find.byType(BottomSheet)).height, lessThan(630));
      expect(find.text('0/1000'), findsNothing);
      final comment = find.widgetWithText(
        TextField,
        'Optional sharing caption',
      );
      await tester.tap(comment);
      await tester.pumpAndSettle();
      expect(find.text('0/1000'), findsOneWidget);
      await tester.enterText(comment, 'Hello neighbours');
      await tester.pump();
      expect(find.text('16/1000'), findsOneWidget);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(FilledButton), findsOneWidget);
    },
  );

  testWidgets('Spanish sharing confirmation explains pending approval', (
    tester,
  ) async {
    final repository = _SharingRepository()..accepted = true;
    await _openShare(tester, repository, locale: const Locale('es'));
    await tester.tap(find.text('Echeandia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('General'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Compartir en 1 comunidad'));
    await tester.pumpAndSettle();
    expect(repository.shares, 1);
    expect(find.text('1 pendiente(s) de aprobación'), findsOneWidget);
    expect(find.text('1 awaiting community approval'), findsNothing);
  });
  testWidgets('canceling category selection leaves destination unselected', (
    tester,
  ) async {
    final repository = _SharingRepository();
    await _openShare(tester, repository);
    await tester.tap(find.text('Echeandia'));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.text('Choose a category'))).pop();
    await tester.pumpAndSettle();
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isFalse,
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(repository.shares, 0);
  });
  testWidgets(
    'rules review is explicit and preserves category on cancellation',
    (tester) async {
      final repository = _SharingRepository();
      await _openShare(tester, repository);
      await tester.tap(find.text('Echeandia'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Business'));
      await tester.pumpAndSettle();
      expect(find.text('Business · Change category'), findsOneWidget);
      await tester.tap(find.text('Share to 1 community'));
      await tester.pumpAndSettle();
      expect(find.byType(PostRulesReviewPage), findsOneWidget);
      expect(repository.shares, 0);
      expect(repository.accepted, isFalse);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Business · Change category'), findsOneWidget);
      await tester.tap(find.text('Share to 1 community'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(repository.shares, 1);
      expect(repository.destinations, {'community': 'Business'});
      expect(find.text('1 awaiting community approval'), findsOneWidget);
    },
  );
}
