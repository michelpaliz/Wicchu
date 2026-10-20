import 'dart:async';
import 'package:wicchu/localization/app_language.dart';
import 'package:wicchu/theme/wicchu_theme.dart';
import 'package:wicchu/features/admin/admin_dashboard_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/community/community_profile_page.dart';
import 'package:wicchu/widgets/feed_filter_bar.dart';

class _PreviewRepository extends DemoCommunityRepository {
  int postReads = 0;
  Community? previewCommunity;
  @override
  Future<Community> getCommunity(String id) async =>
      previewCommunity ?? await super.getCommunity(id);

  @override
  Future<List<CommunityPost>> listPosts(
    String id, {
    String? categoryId,
    String? query,
    String? sort,
  }) async {
    postReads++;
    return [];
  }
}

class _RatingRepository extends DemoCommunityRepository {
  CommunitySurveyResponse? response;
  int submissions = 0;

  @override
  Future<CommunityHelpfulness> getCommunityHelpfulness(
    String communityId,
  ) async => CommunityHelpfulness(
    responseCount: response == null ? 0 : 1,
    minimumResponses: 10,
    isPublic: false,
    eligible: true,
    myVote: response,
  );

  @override
  Future<CommunityHelpfulness> setCommunityHelpfulness(
    String communityId, {
    required bool helpful,
    String? locallyRelevant,
    String? safeParticipation,
    String? wellOrganized,
    bool? recommend,
  }) async {
    submissions++;
    response = CommunitySurveyResponse(
      helpful: helpful,
      locallyRelevant: locallyRelevant,
      safeParticipation: safeParticipation,
      wellOrganized: wellOrganized,
      recommend: recommend,
    );
    return getCommunityHelpfulness(communityId);
  }
}

class _AboutTranslationRepository extends DemoCommunityRepository {
  int translationRequests = 0;
  final requestedLanguages = <String>[];
  Future<CommunityAboutTranslation>? pendingTranslation;
  Community? current;

  @override
  Future<Community> getCommunity(String id) async =>
      current ?? await super.getCommunity(id);

  @override
  Future<CommunityAboutTranslation> translateCommunityAbout(
    String communityId, {
    String targetLanguage = 'auto',
  }) async {
    translationRequests++;
    requestedLanguages.add(targetLanguage);
    if (pendingTranslation != null) return pendingTranslation!;
    return CommunityAboutTranslation(
      communityId: communityId,
      sourceLanguage: 'en',
      targetLanguage: 'es',
      translatedShortDescription: 'Resumen traducido',
      translatedDescription: 'Descripción traducida',
    );
  }
}

void main() {
  testWidgets(
    'About ignores stale language responses and preserves untranslated fields',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _AboutTranslationRepository();
      final original = (await repository.listJoinedCommunities()).first;
      final community = Community(
        id: original.id,
        name: original.name,
        shortDescription: 'Original summary',
        description: 'Original description',
        town: original.town,
        visibility: original.visibility,
        createdBy: original.createdBy,
        createdAt: original.createdAt,
        myRole: CommunityRole.member,
      );
      repository.current = community;
      var language = 'es';
      late StateSetter updateLanguage;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            updateLanguage = setState;
            return AppLanguageScope(
              languageCode: language,
              onLanguageChanged: (_) {},
              child: MaterialApp(
                home: CommunityProfilePage(
                  community: community,
                  repository: repository,
                  screen: CommunityScreen.information,
                ),
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      final pending = Completer<CommunityAboutTranslation>();
      repository.pendingTranslation = pending.future;
      final button = find.byKey(const ValueKey('about-translation-button'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
      updateLanguage(() => language = 'en');
      await tester.pump();
      pending.complete(
        CommunityAboutTranslation(
          communityId: community.id,
          targetLanguage: 'es',
          translatedShortDescription: '',
          translatedDescription: 'Stale Spanish response',
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Stale Spanish response', findRichText: true),
        findsNothing,
      );
      expect(
        find.text('Original description', findRichText: true),
        findsOneWidget,
      );
      repository.pendingTranslation = Future.value(
        CommunityAboutTranslation(
          communityId: community.id,
          targetLanguage: 'en',
          translatedShortDescription: '',
          translatedDescription: 'Translated description',
        ),
      );
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(repository.requestedLanguages, ['es', 'en']);
      expect(
        find.text('Translated description', findRichText: true),
        findsOneWidget,
      );
      await tester.drag(
        find.byKey(const ValueKey('community-information-content')),
        const Offset(0, 900),
      );
      await tester.pumpAndSettle();
      expect(find.text('Original summary'), findsOneWidget);
      updateLanguage(() => language = 'fr');
      await tester.pumpAndSettle();
      expect(
        find.text('Original description', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.text('Translated description', findRichText: true),
        findsNothing,
      );
    },
  );

  for (final business in [false, true]) {
    testWidgets(
      'About translation works with compact layout business=$business',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(430, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final repository = _AboutTranslationRepository();
        final original = (await repository.listJoinedCommunities()).first;
        final community = Community(
          id: original.id,
          name: original.name,
          shortDescription: 'Original summary',
          description: 'Original description',
          town: original.town,
          visibility: original.visibility,
          createdBy: original.createdBy,
          createdAt: original.createdAt,
          myRole: CommunityRole.member,
          type: business
              ? CommunityType.publicProfile
              : CommunityType.community,
          profileCategory: business ? ProfileCategory.localBusiness : null,
        );
        repository.current = community;

        await tester.pumpWidget(
          MaterialApp(
            home: CommunityProfilePage(
              community: community,
              repository: repository,
              screen: CommunityScreen.information,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('about-translation-button')),
        );
        await tester.tap(
          find.byKey(const ValueKey('about-translation-button')),
        );
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Descripción traducida', findRichText: true),
          findsOneWidget,
        );
        expect(repository.translationRequests, 1);

        await tester.tap(
          find.byKey(const ValueKey('about-translation-button')),
        );
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Original description', findRichText: true),
          findsOneWidget,
        );
        expect(repository.translationRequests, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final role in [
    null,
    CommunityRole.member,
    CommunityRole.moderator,
    CommunityRole.admin,
    CommunityRole.owner,
  ]) {
    testWidgets('community information management tabs respect role $role', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _PreviewRepository();
      final community = Community(
        id: 'role-community',
        name: 'Community',
        description: '🌿 Community\n\nPublic description',
        town: const Town(id: 'town-1', name: 'Town X', countryCode: 'EC'),
        visibility: CommunityVisibility.public,
        createdBy: 'owner',
        createdAt: DateTime(2026),
        myRole: role,
      );
      repository.previewCommunity = community;
      await tester.pumpWidget(
        MaterialApp(
          theme: role == CommunityRole.owner || role == CommunityRole.moderator
              ? WicchuTheme.dark
              : WicchuTheme.light,
          home: CommunityProfilePage(
            community: community,
            repository: repository,
            screen: CommunityScreen.information,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final tabs = find.byKey(const ValueKey('community-information-tabs'));
      final manages = [
        CommunityRole.owner,
        CommunityRole.admin,
        CommunityRole.moderator,
      ].contains(role);
      expect(tabs, manages ? findsOneWidget : findsNothing);
      expect(find.byTooltip('Manage community'), findsNothing);
      expect(find.text('🌿 Community'), findsNothing);
      expect(find.text('Public description'), findsOneWidget);
      if (manages) {
        final tabActions = find.descendant(
          of: tabs,
          matching: find.byType(InkWell),
        );
        expect(tabActions, findsNWidgets(2));
        expect(tester.getSize(tabActions.at(0)).width, 160);
        expect(tester.getSize(tabActions.at(1)).width, 160);
        final identity = find.byKey(
          const ValueKey('community-information-identity'),
        );
        final identityPosition = tester.getTopLeft(identity);
        expect(identityPosition.dy, lessThan(tester.getTopLeft(tabs).dy));
        await tester.tap(
          find.descendant(
            of: tabs,
            matching: find.text(
              role == CommunityRole.moderator ? 'Moderation' : 'Administration',
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AdminDashboardPage), findsOneWidget);
        expect(tester.getTopLeft(identity), identityPosition);
        expect(
          find.byKey(const ValueKey('information-members-entry')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('information-administrators-entry')),
          findsOneWidget,
        );
        expect(find.text('Public description'), findsNothing);
        if (role == CommunityRole.moderator) {
          expect(find.text('Categories'), findsNothing);
          expect(
            find.descendant(
              of: find.byType(AdminDashboardPage),
              matching: find.text('Members'),
            ),
            findsNothing,
          );
          expect(find.text('Settings'), findsNothing);
          expect(find.text('Removed posts'), findsOneWidget);
        } else {
          expect(find.text('Categories'), findsOneWidget);
        }
        if (role != CommunityRole.moderator) {
          final dashboardList = find.descendant(
            of: find.byType(AdminDashboardPage),
            matching: find.byType(ListView),
          );
          await tester.drag(dashboardList, const Offset(0, -400));
          await tester.pumpAndSettle();
          expect(identity.hitTestable(), findsNothing);
          expect(tabs.hitTestable(), findsOneWidget);
          final pinnedPosition = tester.getTopLeft(tabs);
          await tester.drag(dashboardList, const Offset(0, -200));
          await tester.pumpAndSettle();
          expect(tester.getTopLeft(tabs), pinnedPosition);
        }
        await tester.ensureVisible(
          find.descendant(of: tabs, matching: find.text('Information')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(of: tabs, matching: find.text('Information')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AdminDashboardPage), findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final type in [
    BusinessRequestType.appointment,
    BusinessRequestType.quote,
  ]) {
    testWidgets(
      'business information removes repeated paragraphs and offers ${type.name}',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(430, 1100));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final repository = _PreviewRepository();
        final original = (await repository.listJoinedCommunities()).first;
        final business = Community(
          id: original.id,
          name: 'Test business',
          shortDescription: 'Welcome!\n\nFriendly local service.',
          description:
              'Friendly local service.\n\nAppointments available on weekends.',
          town: original.town,
          visibility: CommunityVisibility.public,
          createdBy: original.createdBy,
          createdAt: original.createdAt,
          type: CommunityType.publicProfile,
          profileCategory: ProfileCategory.localBusiness,
          businessRequestCapabilities: [type],
        );
        repository.previewCommunity = business;
        await tester.pumpWidget(
          MaterialApp(
            home: CommunityProfilePage(
              community: business,
              repository: repository,
              screen: CommunityScreen.information,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final description = tester.widget<Text>(
          find.byKey(const ValueKey('page-header-description')),
        );
        expect(description.maxLines, 4);
        final text = description.textSpan!.toPlainText();
        expect(text, contains('Welcome!'));
        expect(text, contains('Appointments available on weekends.'));
        expect('Friendly local service.'.allMatches(text).length, 1);
        expect(
          find.byKey(const ValueKey('business-information-details')),
          findsOneWidget,
        );
        expect(find.text('Opening hours'), findsOneWidget);
        expect(find.text(type.actionLabel), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('rating choice opens and submits one complete survey', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _RatingRepository();
    final original = (await repository.listJoinedCommunities()).first;
    final community = Community(
      id: original.id,
      name: original.name,
      description: original.description,
      town: original.town,
      visibility: original.visibility,
      createdBy: original.createdBy,
      createdAt: original.createdAt,
      myRole: CommunityRole.member,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CommunityProfilePage(
          community: community,
          repository: repository,
          screen: CommunityScreen.rating,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Complete your rating'), findsOneWidget);
    await tester.tap(find.text('Yes').first);
    await tester.pumpAndSettle();
    expect(repository.submissions, 0);
    expect(find.text('Rate this community'), findsOneWidget);
    expect(find.text('1 of 5 answered'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('rating-submit')))
          .onPressed,
      isNull,
    );
    for (var i = 1; i < 5; i++) {
      final choice = find.descendant(
        of: find.byKey(ValueKey('rating-answer-$i')),
        matching: find.text('Yes'),
      );
      await tester.ensureVisible(choice);
      await tester.tap(choice);
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('Send rating'));
    await tester.pumpAndSettle();
    expect(repository.submissions, 1);
    expect(repository.response?.helpful, isTrue);
    expect(repository.response?.locallyRelevant, 'yes');
    expect(repository.response?.safeParticipation, 'yes');
    expect(repository.response?.wellOrganized, 'yes');
    expect(repository.response?.recommend, isTrue);
    expect(
      find.text('Your feedback is saved. You can update it at any time.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Not really').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repository.submissions, 1);
    expect(repository.response?.helpful, isTrue);

    await tester.tap(find.text('Not really').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send rating'));
    await tester.pumpAndSettle();
    expect(repository.submissions, 2);
    expect(repository.response?.helpful, isFalse);
    expect(find.text('Update your rating'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final visibility in CommunityVisibility.values) {
    testWidgets('non-member preview respects $visibility', (tester) async {
      final repository = _PreviewRepository();
      final original = (await repository.listCommunities()).first;
      final community = Community(
        id: original.id,
        name: original.name,
        description: original.description,
        town: original.town,
        visibility: visibility,
        createdBy: original.createdBy,
        createdAt: original.createdAt,
      );
      repository.previewCommunity = community;
      await tester.pumpWidget(
        MaterialApp(
          home: CommunityProfilePage(
            community: community,
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        repository.postReads,
        visibility == CommunityVisibility.public ? 1 : 0,
      );
      if (visibility == CommunityVisibility.public) {
        expect(
          find.text('Community preview. Join to take part.'),
          findsNothing,
        );
      } else {
        expect(find.text('Join to view community posts.'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('membership options open in a bottom sheet', (tester) async {
    final repository = _PreviewRepository();
    final original = (await repository.listJoinedCommunities()).first;
    final community = Community(
      id: original.id,
      name: original.name,
      shortDescription: original.shortDescription,
      description: original.description,
      town: original.town,
      visibility: original.visibility,
      createdBy: original.createdBy,
      createdAt: original.createdAt,
      myRole: CommunityRole.member,
    );
    repository.previewCommunity = community;
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityProfilePage(
          community: community,
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('community-management-shortcut')),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('community-role-badge')));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('You are a member of this community'), findsOneWidget);
    expect(find.text('Manage community'), findsNothing);
    expect(find.text('Leave community'), findsOneWidget);
  });

  testWidgets('private member directory is hidden from regular members', (
    tester,
  ) async {
    final repository = _PreviewRepository();
    final original = (await repository.listJoinedCommunities()).first;
    final community = Community(
      id: original.id,
      name: original.name,
      description: original.description,
      town: original.town,
      visibility: original.visibility,
      createdBy: original.createdBy,
      createdAt: original.createdAt,
      myRole: CommunityRole.member,
      membersListVisible: false,
    );
    repository.previewCommunity = community;

    await tester.pumpWidget(
      MaterialApp(
        home: CommunityProfilePage(
          community: community,
          repository: repository,
          screen: CommunityScreen.members,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('The member list is private.'), findsOneWidget);
    expect(find.text('You'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'about description starts compact and administration opens filtered members',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _PreviewRepository();
      final original = (await repository.listJoinedCommunities()).first;
      final community = Community(
        id: original.id,
        name: original.name,
        shortDescription: List.filled(
          3,
          'A concise summary of local news and events.',
        ).join(' '),
        description: List.filled(
          10,
          'News, events and stories from our local community.',
        ).join(' '),
        town: original.town,
        visibility: original.visibility,
        createdBy: original.createdBy,
        createdAt: original.createdAt,
        myRole: CommunityRole.member,
        memberCount: original.memberCount,
      );
      repository.previewCommunity = community;
      await tester.pumpWidget(
        MaterialApp(
          home: CommunityProfilePage(
            community: community,
            repository: repository,
            screen: CommunityScreen.information,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('page-header-description')))
            .maxLines,
        5,
      );
      expect(
        tester.widget<Text>(find.text(community.shortDescription)).maxLines,
        isNull,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('community-description-toggle')),
      );
      await tester.tap(
        find.byKey(const ValueKey('community-description-toggle')),
      );
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const ValueKey('community-information-content')),
        const Offset(0, 900),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.text(community.shortDescription)).maxLines,
        2,
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('page-header-description')))
            .maxLines,
        5,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('community-description-toggle')),
      );
      await tester.tap(
        find.byKey(const ValueKey('community-description-toggle')),
      );
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const ValueKey('community-information-content')),
        const Offset(0, 900),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.text(community.shortDescription)).maxLines,
        isNull,
      );
      final aboutToggle = find.byKey(
        const ValueKey('page-header-description-toggle'),
      );
      await tester.ensureVisible(aboutToggle);
      await tester.ensureVisible(aboutToggle);
      await tester.tap(aboutToggle);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('page-header-description')))
            .maxLines,
        isNull,
      );
      await tester.ensureVisible(aboutToggle);
      await tester.tap(aboutToggle);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('page-header-description')))
            .maxLines,
        5,
      );
      final admins = find.byKey(
        const ValueKey('information-administrators-entry'),
      );
      expect(find.text('Administrators'), findsOneWidget);
      await tester.tap(admins);
      await tester.pumpAndSettle();
      expect(
        tester.widget<FeedFilterBar>(find.byType(FeedFilterBar)).selectedIndex,
        1,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'business owners switch between the public information and management tabs',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _PreviewRepository();
      final original = (await repository.listJoinedCommunities()).first;
      final business = Community(
        id: original.id,
        name: 'COMIDA RAPIDA',
        shortDescription: 'A short customer introduction.',
        description: 'Additional business details.',
        town: original.town,
        visibility: CommunityVisibility.public,
        createdBy: original.createdBy,
        createdAt: original.createdAt,
        type: CommunityType.publicProfile,
        profileCategory: ProfileCategory.localBusiness,
        myRole: CommunityRole.owner,
        businessServices: const [BusinessService.food],
        businessAcceptingOrders: true,
        businessAcceptingRequests: true,
        businessRequestCapabilities: const [BusinessRequestType.appointment],
      );
      repository.previewCommunity = business;
      await tester.pumpWidget(
        MaterialApp(
          home: CommunityProfilePage(
            community: business,
            repository: repository,
            screen: CommunityScreen.information,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('business-information-tabs')),
        findsOneWidget,
      );
      expect(find.text('View menu'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('business-primary-bottom-action')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('business-information-message')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('business-information-follow')),
        findsNothing,
      );
      expect(
        find.textContaining(
          'A short customer introduction.',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('business-management-content')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('information-edit-page')), findsNothing);

      await tester.tap(find.text('Manage'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('business-management-content')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('information-edit-page')),
        findsOneWidget,
      );
      expect(find.text('Menu'), findsOneWidget);
      expect(find.text('Manage appointments'), findsOneWidget);
      expect(
        find.textContaining(
          'A short customer introduction.',
          findRichText: true,
        ),
        findsNothing,
      );
      expect(find.text('View menu'), findsNothing);
      expect(
        find.byKey(const ValueKey('business-primary-bottom-action')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('business visitors do not see the management tab', (
    tester,
  ) async {
    final repository = _PreviewRepository();
    final original = (await repository.listJoinedCommunities()).first;
    final business = Community(
      id: original.id,
      name: 'Visitor business',
      shortDescription: 'Public description.',
      description: 'More public information.',
      town: original.town,
      visibility: CommunityVisibility.public,
      createdBy: original.createdBy,
      createdAt: original.createdAt,
      type: CommunityType.publicProfile,
      profileCategory: ProfileCategory.localBusiness,
      businessServices: const [BusinessService.food],
    );
    repository.previewCommunity = business;
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityProfilePage(
          community: business,
          repository: repository,
          screen: CommunityScreen.information,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('business-information-tabs')),
      findsNothing,
    );
    expect(find.text('Manage'), findsNothing);
    expect(
      find.textContaining('Public description.', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('business-primary-bottom-action')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('business-information-follow')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('business-information-message')),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Follow'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Message'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
