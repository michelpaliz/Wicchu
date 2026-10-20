import 'package:wicchu/services/app_update_service.dart';
import 'package:wicchu/features/main/main_shell.dart';
import 'package:wicchu/features/settings/account_settings_page.dart';
import 'package:flutter/services.dart';
import 'package:wicchu/features/admin/community_rewards_page.dart';
import 'package:wicchu/features/community/post_collection_page.dart';
import 'package:wicchu/features/profile/profile_communities_page.dart';
import 'package:wicchu/widgets/wicchu_list_tile.dart';
import 'package:wicchu/data/authenticated_api_client.dart';
import 'package:wicchu/features/auth/login_page.dart';
import 'package:wicchu/theme/wicchu_icons.dart';
import 'package:wicchu/features/community/post_rules_review_page.dart';
import 'package:wicchu/features/community/create_post_page.dart';
import 'dart:async';
import 'package:wicchu/features/community/post_rich_text_editor.dart';
import 'package:wicchu/features/community/category_page.dart';
import 'package:wicchu/features/community/community_profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:wicchu/features/auth/email_auth_page.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/auth_gateway.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/domain/community_repository.dart';
import 'package:wicchu/features/admin/create_community_page.dart';
import 'package:wicchu/features/admin/admin_dashboard_page.dart';
import 'package:wicchu/features/admin/platform_moderation_page.dart';
import 'package:wicchu/features/chat/direct_chat_pages.dart';
import 'package:wicchu/features/community/post_card.dart';
import 'package:wicchu/features/community/post_media_gallery.dart';
import 'package:wicchu/localization/app_language.dart';
import 'package:wicchu/main.dart';
import 'package:wicchu/features/profile/member_profile_page.dart';
import 'package:wicchu/features/profile/edit_profile_links.dart';

class _ManualUpdateService extends AppUpdateService {
  _ManualUpdateService({this.automatic});
  final Completer<AppUpdateInfo?>? automatic;
  final result = Completer<AppUpdateInfo?>();
  int manualCalls = 0;
  @override
  Future<AppUpdateInfo?> check({
    required String languageCode,
    bool force = false,
  }) async {
    if (!force) return automatic?.future;
    manualCalls++;
    return result.future;
  }
}

class _TownDiscoveryRepository extends DemoCommunityRepository {
  int nearbyCalls = 0;
  String? excludedTown;
  @override
  Future<List<Community>> listNearbyCommunities({
    required double latitude,
    required double longitude,
    double radiusKm = 25,
    String? excludeTownId,
  }) {
    nearbyCalls++;
    excludedTown = excludeTownId;
    return super.listNearbyCommunities(
      latitude: latitude,
      longitude: longitude,
      radiusKm: radiusKm,
      excludeTownId: excludeTownId,
    );
  }
}

class _HomeDiscoveryRepository extends DemoCommunityRepository {
  String? followedId;
  @override
  Future<List<Community>> listJoinedCommunities() async =>
      (await super.listJoinedCommunities())
          .where((community) => community.id == followedId)
          .toList();
  @override
  Future<List<CommunityPost>> listFollowingPosts({String? query}) =>
      super.listPosts(followedId!, query: query);
}

class _FailingFacebookGateway extends _FakeAuthGateway {
  _FailingFacebookGateway() : super(signedIn: false);

  @override
  Future<AuthSession> signInWithFacebook() async =>
      throw const AuthException('Facebook token could not be verified.');
}

class _FakeAuthGateway implements AuthGateway {
  _FakeAuthGateway({required this.signedIn, this.facebookError});
  final bool signedIn;
  final AuthException? facebookError;

  @override
  Future<bool> hasSession() async => signedIn;

  @override
  Future<AuthSession> signInWithFacebook() async {
    if (facebookError != null) throw facebookError!;
    return const AuthSession(
      accessToken: 'access',
      refreshToken: 'refresh',
      userId: 'user-1',
      userName: 'test_user',
      isNewUser: true,
    );
  }

  @override
  Future<AuthSession> signInWithGoogle() => signInWithFacebook();

  @override
  Future<AuthSession> signInWithApple() => signInWithFacebook();

  @override
  Future<Map<String, dynamic>> getDeletionPreview() async => {
    'canDelete': true,
    'ownershipConflicts': <dynamic>[],
  };

  @override
  Future<void> deleteAccount({String? password}) async {}

  @override
  Future<AuthSession> signInWithEmail(String email, String password) =>
      signInWithFacebook();

  @override
  Future<void> registerWithEmail({
    required String name,
    required String userName,
    required String email,
    required String password,
    required String locale,
  }) async {}

  @override
  Future<void> resendVerificationEmail(
    String email, {
    required String locale,
  }) async {}

  @override
  Future<void> requestPasswordReset(String email) async {}

  @override
  Future<void> signOut() async {}
}

class _RecordingRepository extends DemoCommunityRepository {
  String? lastSort;

  @override
  Future<List<CommunityPost>> listPosts(
    String communityId, {
    String? categoryId,
    String? query,
    String? sort,
  }) {
    lastSort = sort;
    return super.listPosts(
      communityId,
      categoryId: categoryId,
      query: query,
      sort: sort,
    );
  }
}

class _NotificationsRepository extends DemoCommunityRepository {
  String postId = '';
  bool read = false;
  CommunityNotificationType type = CommunityNotificationType.postComment;
  String communityId = '';
  String? reviewedCommunity;

  @override
  Future<List<CommunityPost>> listPendingPosts(String communityId) async {
    reviewedCommunity = communityId;
    return [await getPost(postId)];
  }

  @override
  Future<NotificationFeed> listNotifications() async => NotificationFeed(
    unreadCount: read ? 0 : 1,
    items: [
      CommunityNotification(
        id: 'notification-1',
        actorName: 'Alex',
        type: type,
        communityId: communityId,
        postId: postId,
        message: type == CommunityNotificationType.reportCreated
            ? 'reported a post'
            : 'commented on your post',
        createdAt: DateTime.now(),
        isRead: read,
      ),
    ],
  );

  @override
  Future<void> markNotificationRead(String notificationId) async {
    read = true;
  }
}

class _EmptyTownsRepository extends DemoCommunityRepository {
  @override
  Future<List<Town>> listTowns() async => const [];
}

class _NoCommunitiesRepository extends DemoCommunityRepository {
  @override
  Future<List<Community>> listJoinedCommunities() async => [];

  @override
  Future<List<Community>> listManagedCommunities() async => [];
}

class _EmptyExploreRepository extends DemoCommunityRepository {
  @override
  Future<List<Community>> listCommunities({
    String? query,
    String? townId,
  }) async => [];
  @override
  Future<List<Community>> listJoinedCommunities() async => [];
}

class _PeopleExploreRepository extends DemoCommunityRepository {
  @override
  Future<PeopleSearchPage> searchPeople({
    String query = '',
    String? cursor,
    int limit = 25,
    String? townId,
    double? latitude,
    double? longitude,
    double radiusKm = 10,
  }) async {
    if (query.isNotEmpty && !'sanyi ramos'.contains(query.toLowerCase())) {
      return const PeopleSearchPage(people: []);
    }
    return const PeopleSearchPage(
      people: [
        PeopleSearchResult(
          id: 'sanyi-id',
          name: 'Sanyi Ramos',
          userName: 'sanyi_ramos',
          sharedCommunityCount: 0,
        ),
      ],
    );
  }
}

class _DelayedLogoutGateway extends _FakeAuthGateway {
  _DelayedLogoutGateway() : super(signedIn: true);
  final completion = Completer<void>();
  int calls = 0;
  @override
  Future<void> signOut() async {
    calls++;
    await completion.future;
    await super.signOut();
  }
}

class _ExpiredSessionRepository extends DemoCommunityRepository {
  @override
  Future<List<Community>> listJoinedCommunities() async =>
      throw const ApiException('Please sign in again.', statusCode: 401);
}

void main() {
  testWidgets('You opens account hub and identity opens personal profile', (
    tester,
  ) async {
    await tester.pumpWidget(
      WicchuApp(
        repository: DemoCommunityRepository(),
        authGateway: _FakeAuthGateway(signedIn: true),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('You').last);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Edit profile'), findsOneWidget);
    expect(find.byType(MemberProfilePage), findsNothing);
    final identity = find.byKey(const ValueKey('account-profile-identity'));
    final scaffold = tester.widget<Scaffold>(
      find.ancestor(of: identity, matching: find.byType(Scaffold)).first,
    );
    expect(
      scaffold.backgroundColor,
      Theme.of(tester.element(identity)).scaffoldBackgroundColor,
    );
    expect(find.text('My activity'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('account-profile-identity')));
    await tester.pumpAndSettle();
    expect(find.byType(MemberProfilePage), findsOneWidget);
    expect(
      find.byKey(const ValueKey('personal-profile-create-post')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('personal-profile-options')));
    await tester.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    expect(
      find.descendant(of: sheet, matching: find.text('You')),
      findsNothing,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('Share profile')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('Find people')),
      findsOneWidget,
    );
    Navigator.of(tester.element(sheet)).pop();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byTooltip('Edit profile'), findsOneWidget);
  });

  testWidgets('root navigator supports Spanish editor link dialog', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'language': 'es',
      'onboarding_preferences_completed': true,
    });
    await tester.pumpWidget(
      WicchuApp(
        repository: DemoCommunityRepository(),
        authGateway: _FakeAuthGateway(signedIn: false),
      ),
    );
    await tester.pumpAndSettle();
    final controller = PostTextController('');
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    app.navigatorKey!.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) =>
            Scaffold(body: PostRichTextEditor(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(quill.QuillToolbarLinkStyleButton));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Texto'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Wicchu');
    await tester.enterText(
      find.byType(TextFormField).last,
      'https://wicchu.com',
    );
    await tester.pump();
    await tester.tap(find.text('Ok'));
    await tester.pumpAndSettle();
    expect(controller.text, '[Wicchu](https://wicchu.com)');
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('own profile communities count opens flat space rows', (
    tester,
  ) async {
    await tester.pumpWidget(
      WicchuApp(
        repository: DemoCommunityRepository(),
        authGateway: _FakeAuthGateway(signedIn: true),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('You'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('account-profile-identity')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-communities')));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileCommunitiesPage), findsOneWidget);
    expect(find.byType(WicchuListTile), findsWidgets);
    await tester.tap(
      find.descendant(
        of: find.byType(WicchuListTile).first,
        matching: find.byType(ListTile),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CommunityProfilePage), findsOneWidget);
  });

  testWidgets('expired Home session offers working sign in instead of retry', (
    tester,
  ) async {
    await tester.pumpWidget(
      WicchuApp(
        repository: _ExpiredSessionRepository(),
        authGateway: _FakeAuthGateway(signedIn: true),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Please sign in again.'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Retry'), findsNothing);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);
  });

  testWidgets(
    'email recovery validates input and confirms reset without password fields',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EmailAuthPage(
            authGateway: _FakeAuthGateway(signedIn: false),
            onSignedIn: () {},
          ),
        ),
      );
      await tester.tap(find.byTooltip('Show password'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Hide password'), findsOneWidget);
      await tester.ensureVisible(find.text('Forgot password?'));
      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsOneWidget);
      await tester.tap(find.text('Send reset link'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField),
        'neighbor@example.com',
      );
      await tester.ensureVisible(find.text('Send reset link'));
      await tester.tap(find.text('Send reset link'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'If an account exists, a password reset email has been sent.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('logout shows progress and restores the button on failure', (
    tester,
  ) async {
    final auth = _DelayedLogoutGateway();
    await tester.pumpWidget(
      WicchuApp(repository: DemoCommunityRepository(), authGateway: auth),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('You'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Log out'),
      350,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out'));
    await tester.pump();
    expect(find.text('Signing out…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.text('Signing out…'));
    expect(auth.calls, 1);
    auth.completion.completeError(Exception('Connection failed'));
    await tester.pumpAndSettle();
    expect(find.text('Log out'), findsOneWidget);
    expect(find.textContaining('Connection failed'), findsOneWidget);
  });

  setUp(
    () => SharedPreferences.setMockInitialValues({
      'onboarding_preferences_completed': true,
    }),
  );

  testWidgets('Home pins are relevant, deduplicated and open the full post', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(600, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _HomeDiscoveryRepository();
    final followed = (await repository.listCommunities()).first;
    repository.followedId = followed.id;
    final nearby = await repository.createCommunity(
      CreateCommunityInput(
        name: 'Nearby pinned space',
        description: '',
        town: followed.town,
        visibility: CommunityVisibility.public,
        categoryNames: ['General'],
      ),
    );
    final pins = <CommunityPost>[];
    for (final community in [followed, nearby]) {
      final category = (await repository.listCategories(community.id)).first;
      final post = await repository.createPost(
        community.id,
        CreatePostInput(
          categoryId: category.id,
          text: 'Pinned from ${community.name}',
        ),
      );
      await repository.setPostPinned(post.id, pinned: true);
      pins.add(post);
    }
    await tester.pumpWidget(
      WicchuApp(
        repository: repository,
        authGateway: _FakeAuthGateway(signedIn: true),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-pinned-carousel')), findsOneWidget);
    for (final post in pins) {
      expect(find.byKey(ValueKey('home-pinned-${post.id}')), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is PostCard && w.post?.id == post.id),
        findsNothing,
      );
    }
    await tester.tap(find.text('Following'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(ValueKey('home-pinned-${pins.first.id}')),
      findsOneWidget,
    );
    expect(find.byKey(ValueKey('home-pinned-${pins.last.id}')), findsNothing);
    expect(find.byKey(const ValueKey('home-pinned-carousel')), findsNothing);
    expect(find.byKey(const ValueKey('home-pinned-featured')), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('home-pinned-${pins.first.id}')));
    await tester.pumpAndSettle();
    expect(find.byType(PostCollectionPage), findsOneWidget);
    expect(
      tester
          .widget<PostCollectionPage>(find.byType(PostCollectionPage))
          .initialPostId,
      pins.first.id,
    );
    Navigator.of(tester.element(find.byType(PostCollectionPage))).pop();
    await tester.pumpAndSettle();
    await repository.setPostPinned(pins.first.id, pinned: false);
    // Returning from detail refreshes Home with the latest pin state.
    await tester.tap(find.byKey(ValueKey('home-pinned-${pins.first.id}')));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(PostCollectionPage))).pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-pinned-carousel')), findsNothing);
    expect(
      find.byWidgetPredicate(
        (w) => w is PostCard && w.post?.id == pins.first.id,
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home combines local discovery and keeps Following restricted', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(600, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _HomeDiscoveryRepository();
    final followed = (await repository.listCommunities()).first;
    repository.followedId = followed.id;
    final nearby = await repository.createCommunity(
      CreateCommunityInput(
        name: 'Nearby public space',
        description: '',
        town: followed.town,
        visibility: CommunityVisibility.public,
        categoryNames: ['General'],
      ),
    );
    for (final community in [followed, nearby]) {
      final category = (await repository.listCategories(community.id)).first;
      await repository.createPost(
        community.id,
        CreatePostInput(
          categoryId: category.id,
          text: community.id == followed.id
              ? 'Followed update'
              : 'Local discovery update',
        ),
      );
    }
    await tester.pumpWidget(
      WicchuApp(
        repository: repository,
        authGateway: _FakeAuthGateway(signedIn: true),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Followed update', findRichText: true), findsOneWidget);
    expect(
      find.text('Local discovery update', findRichText: true),
      findsOneWidget,
    );
    await tester.tap(find.text('Following'));
    await tester.pumpAndSettle();
    expect(find.text('Followed update', findRichText: true), findsOneWidget);
    expect(
      find.text('Local discovery update', findRichText: true),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the aggregated home navigation', (tester) async {
    await tester.pumpWidget(
      WicchuApp(
        repository: DemoCommunityRepository(),
        authGateway: _FakeAuthGateway(signedIn: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home-search')), findsOneWidget);
    expect(find.text('For you'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);
    expect(find.text('Community'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('bottom-pages-navigation')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('bottom-community-navigation')),
      findsOneWidget,
    );
    expect(find.byTooltip('Messages'), findsOneWidget);
    expect(find.byTooltip('Notifications'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
    await tester.tap(find.byTooltip('Messages'));
    await tester.pumpAndSettle();
    expect(find.byType(ConversationListPage), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Community'));
    await tester.pumpAndSettle();
    expect(find.byType(CommunityProfilePage), findsOneWidget);
    expect(
      tester
          .widget<CommunityProfilePage>(find.byType(CommunityProfilePage))
          .embedded,
      isTrue,
    );
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Notifications'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('bottom-pages-navigation')));
    await tester.pumpAndSettle();
    expect(find.text('My pages'), findsOneWidget);
    expect(find.text('Following'), findsOneWidget);
    expect(find.text('Your pages and the ones you follow'), findsOneWidget);
    expect(find.byTooltip('Create a page'), findsOneWidget);
    expect(find.byKey(const ValueKey('page-type-filters')), findsNothing);
  });

  testWidgets('long pressing the bottom community item opens the switcher', (
    tester,
  ) async {
    final repository = DemoCommunityRepository();
    final second = await repository.createCommunity(
      const CreateCommunityInput(
        name: 'Second neighborhood',
        description: 'Nearby',
        town: Town(id: 'town-1', name: 'Town X', countryCode: 'EC'),
        visibility: CommunityVisibility.public,
        categoryNames: ['General'],
      ),
    );
    await tester.pumpWidget(
      WicchuApp(
        repository: repository,
        authGateway: _FakeAuthGateway(signedIn: true),
      ),
    );
    await tester.pumpAndSettle();
    await tester.longPress(
      find.byKey(const ValueKey('bottom-community-navigation')),
    );
    await tester.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    expect(
      find.descendant(of: sheet, matching: find.text('My communities')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('Second neighborhood')),
      findsOneWidget,
    );
    await tester.tap(find.text('Second neighborhood'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CommunityProfilePage>(find.byType(CommunityProfilePage))
          .community
          .id,
      second.id,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Communities without membership offers discovery', (
    tester,
  ) async {
    await tester.pumpWidget(
      WicchuApp(
        repository: _NoCommunitiesRepository(),
        authGateway: _FakeAuthGateway(signedIn: true),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Community'));
    await tester.pumpAndSettle();
    expect(find.text('Find your community'), findsOneWidget);
    expect(find.byType(CommunityProfilePage), findsNothing);
    await tester.tap(find.text('Explore communities'));
    await tester.pumpAndSettle();
    expect(find.text('Town X Community'), findsWidgets);
  });

  testWidgets('empty Pages opens public profile creation', (tester) async {
    await tester.pumpWidget(
      WicchuApp(
        repository: _EmptyExploreRepository(),
        authGateway: _FakeAuthGateway(signedIn: true),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('bottom-pages-navigation')));
    await tester.pumpAndSettle();
    expect(
      find.text('You do not manage any public pages yet.'),
      findsOneWidget,
    );
    expect(find.byTooltip('Create a page'), findsOneWidget);
    expect(find.text('Create community'), findsNothing);

    await tester.tap(find.byTooltip('Create a page'));
    await tester.pumpAndSettle();
    expect(find.byType(CreateCommunityPage), findsOneWidget);
    expect(find.text('Public profile'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty Home shows discovery and routes to Explore', (
    tester,
  ) async {
    await tester.pumpWidget(
      WicchuApp(
        repository: _NoCommunitiesRepository(),
        authGateway: _FakeAuthGateway(signedIn: true),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-search')), findsOneWidget);
    expect(find.text('Find your community'), findsOneWidget);
    expect(find.text('No posts found'), findsNothing);
    await tester.tap(find.text('Explore communities'));
    await tester.pumpAndSettle();
    expect(find.text('Town X Community'), findsWidgets);
  });

  testWidgets(
    'manual update request waits for an automatic check then retries',
    (tester) async {
      final automatic = Completer<AppUpdateInfo?>();
      final service = _ManualUpdateService(automatic: automatic);
      final repository = DemoCommunityRepository();
      await tester.pumpWidget(
        WicchuApp(
          repository: repository,
          authGateway: _FakeAuthGateway(signedIn: true),
          updateService: service,
        ),
      );
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(MainShell))).push(
        MaterialPageRoute<void>(
          builder: (_) => AccountSettingsPage(repository: repository),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Check for updates'),
        300,
        scrollable: find
            .descendant(
              of: find.byType(AccountSettingsPage),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('Check for updates'));
      await tester.pump();
      expect(service.manualCalls, 0);
      expect(find.text('Checking for updates…'), findsOneWidget);
      automatic.complete(null);
      await tester.pump();
      expect(service.manualCalls, 1);
      service.result.complete(null);
      await tester.pumpAndSettle();
      expect(find.text('Wicchu is up to date.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final outcome in ['update', 'current', 'failure']) {
    testWidgets('signed-in Settings manual update check: $outcome', (
      tester,
    ) async {
      final service = _ManualUpdateService();
      final repository = DemoCommunityRepository();
      await tester.pumpWidget(
        WicchuApp(
          repository: repository,
          authGateway: _FakeAuthGateway(signedIn: true),
          updateService: service,
        ),
      );
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(MainShell))).push(
        MaterialPageRoute<void>(
          builder: (_) => AccountSettingsPage(repository: repository),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Check for updates'),
        300,
        scrollable: find
            .descendant(
              of: find.byType(AccountSettingsPage),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('Check for updates'));
      await tester.pump();
      expect(find.text('Checking for updates…'), findsOneWidget);
      expect(service.manualCalls, 1);
      if (outcome == 'failure') {
        service.result.completeError(StateError('Offline'));
      } else if (outcome == 'current') {
        service.result.complete(null);
      } else {
        service.result.complete(
          const AppUpdateInfo(
            latestVersion: '1.0.2',
            latestBuild: 29,
            required: false,
            updateUrl: 'https://apps.apple.com/app/wicchu',
            releaseNotes: 'New features',
          ),
        );
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      if (outcome == 'update') {
        expect(find.text('A new Wicchu update is available'), findsOneWidget);
        expect(find.text('Version 1.0.2 is ready to install.'), findsOneWidget);
        await tester.tap(find.text('Later'));
        await tester.pumpAndSettle();
      } else {
        expect(
          find.text(
            outcome == 'current'
                ? 'Wicchu is up to date.'
                : 'Could not check for updates. Please try again.',
          ),
          findsOneWidget,
        );
      }
      expect(find.text('Check for updates'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('single community switcher creates selects and explores', (
    tester,
  ) async {
    final repository = DemoCommunityRepository();
    await tester.pumpWidget(
      WicchuApp(
        repository: repository,
        authGateway: _FakeAuthGateway(signedIn: true),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Businesses'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Community'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Choose a community'));
    await tester.pumpAndSettle();
    expect(find.text('Current'), findsOneWidget);
    await tester.tap(find.text('Create community'));
    await tester.pumpAndSettle();
    expect(find.byType(CreateCommunityPage), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Community name'),
      'Worldwide neighbors',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Anywhere'));
    await tester.pumpAndSettle();
    for (var step = 0; step < 2; step++) {
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.widgetWithText(FilledButton, 'Create space').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enter community'));
    await tester.pumpAndSettle();
    final created = tester
        .widget<CommunityProfilePage>(find.byType(CommunityProfilePage))
        .community;
    expect(created.name, 'Worldwide neighbors');
    final profile = await repository.getProfile();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('currentCommunityId:${profile.id}'), created.id);
    await tester.tap(find.byTooltip('Choose a community'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Explore communities'),
      150,
      scrollable: find
          .descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Explore communities'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('explore-search')), findsOneWidget);
    expect(find.text('Search communities…'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('community tab excludes public pages and switches communities', (
    tester,
  ) async {
    final repository = DemoCommunityRepository();
    final second = await repository.createCommunity(
      const CreateCommunityInput(
        name: 'Second neighborhood',
        description: 'Nearby',
        town: Town(id: 'town-1', name: 'Town X', countryCode: 'EC'),
        visibility: CommunityVisibility.public,
        categoryNames: ['General'],
      ),
    );
    final page = await repository.createCommunity(
      const CreateCommunityInput(
        name: 'Public business excluded from communities',
        description: '',
        town: Town(id: 'town-1', name: 'Town X', countryCode: 'EC'),
        visibility: CommunityVisibility.public,
        categoryNames: ['General'],
        type: CommunityType.publicProfile,
        profileCategory: ProfileCategory.localBusiness,
      ),
    );
    final profile = await repository.getProfile();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('currentCommunityId:${profile.id}', page.id);
    await tester.pumpWidget(
      WicchuApp(
        repository: repository,
        authGateway: _FakeAuthGateway(signedIn: true),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Community'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Choose a community'));
    await tester.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    expect(
      find.descendant(of: sheet, matching: find.text(page.name)),
      findsNothing,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('My communities')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('2')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('Town X Community')),
      findsOneWidget,
    );
    await tester.tap(find.text('Second neighborhood'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CommunityProfilePage>(find.byType(CommunityProfilePage))
          .community
          .id,
      second.id,
    );
    expect(find.byType(FloatingActionButton), findsNothing);
    final communityPage = find.byType(CommunityProfilePage);
    final allFilter = find.descendant(
      of: communityPage,
      matching: find.text('All'),
    );
    await tester.drag(
      find.descendant(
        of: communityPage,
        matching: find.byType(NestedScrollView),
      ),
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();
    expect(allFilter.hitTestable(), findsOneWidget);
    expect(find.text('About'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(
      find.byKey(const ValueKey('community-composer-entry')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('community-composer-entry')));
    await tester.pumpAndSettle();
    expect(find.byType(PostRulesReviewPage), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Posting to'), findsOneWidget);
    expect(find.text('Second neighborhood'), findsOneWidget);
    expect(find.text('Category'), findsNothing);
    expect(find.byKey(const ValueKey('post-kind-text')), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('For you'), findsOneWidget);
    await tester.tap(find.text('Community'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CommunityProfilePage>(find.byType(CommunityProfilePage))
          .community
          .id,
      second.id,
    );
  });

  testWidgets(
    'Home aggregates communities and preserves the publishing selection',
    (tester) async {
      final repository = DemoCommunityRepository();
      final second = await repository.createCommunity(
        const CreateCommunityInput(
          name: 'Second neighborhood',
          description: 'Nearby',
          town: Town(id: 'town-1', name: 'Town X', countryCode: 'EC'),
          visibility: CommunityVisibility.public,
          categoryNames: ['General'],
        ),
      );
      await tester.pumpWidget(
        WicchuApp(
          repository: repository,
          authGateway: _FakeAuthGateway(signedIn: true),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('My spaces'), findsNothing);
      await tester.tap(find.text('Community'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Choose a community'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Second neighborhood'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(find.text('For you'), findsOneWidget);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'currentCommunityId:current-user',
        ),
        second.id,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        WicchuApp(
          repository: repository,
          authGateway: _FakeAuthGateway(signedIn: true),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('For you'), findsOneWidget);
    },
  );

  testWidgets('account deletion dismisses settings and returns to login', (
    tester,
  ) async {
    await tester.pumpWidget(
      WicchuApp(
        repository: DemoCommunityRepository(),
        authGateway: _FakeAuthGateway(signedIn: true),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('You'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(WicchuIcons.gearSix).first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Delete account'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Delete account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete account'));
    await tester.pump(const Duration(seconds: 1));
    final fields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    final deleteButton = find.widgetWithText(FilledButton, 'Delete account');
    expect(tester.widget<FilledButton>(deleteButton).onPressed, isNull);
    await tester.enterText(fields.first, 'review-password');
    await tester.enterText(fields.last, 'DELETE');
    await tester.pump();
    expect(tester.widget<FilledButton>(deleteButton).onPressed, isNotNull);
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    expect(find.text('Account deleted'), findsOneWidget);
    expect(find.text('Continue to sign in'), findsOneWidget);
    expect(find.text('Continue with email'), findsNothing);
    await tester.tap(find.text('Continue to sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Continue with email'), findsOneWidget);
    expect(find.text('Continue with Facebook'), findsOneWidget);
    expect(find.text('Delete account'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('logs out to the sign-in screen and can sign in again', (
    tester,
  ) async {
    await tester.pumpWidget(
      WicchuApp(
        repository: DemoCommunityRepository(),
        authGateway: _FakeAuthGateway(signedIn: true),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('You'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Log out'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Continue with Facebook'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);

    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('For you'), findsOneWidget);
  });

  testWidgets(
    'home uses the five-item navigation without a central add action',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'language': 'es',
        'onboarding_preferences_completed': true,
      });
      final repository = DemoCommunityRepository();
      final community = await repository.createCommunity(
        const CreateCommunityInput(
          name: 'Echeandía',
          description: 'Comunidad local',
          town: Town(id: 'town-2', name: 'Echeandía', countryCode: 'EC'),
          visibility: CommunityVisibility.public,
          categoryNames: ['General'],
        ),
      );
      final category = (await repository.listCategories(community.id)).first;
      await repository.createPost(
        community.id,
        CreatePostInput(categoryId: category.id, text: 'Jornada de limpieza'),
      );

      await tester.pumpWidget(
        WicchuApp(
          repository: repository,
          authGateway: _FakeAuthGateway(signedIn: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.bySemanticsLabel('Publicación'), findsNothing);
      expect(find.text('Comunidad'), findsOneWidget);
      expect(find.text('Páginas'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('bottom-pages-navigation')),
        findsOneWidget,
      );
    },
  );

  testWidgets('personal profile editing is accessed directly through You', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'language': 'es',
      'onboarding_preferences_completed': true,
    });
    final repository = DemoCommunityRepository();
    await tester.pumpWidget(
      WicchuApp(
        repository: repository,
        authGateway: _FakeAuthGateway(signedIn: true),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tú'));
    await tester.pumpAndSettle();
    expect(find.byType(MemberProfilePage), findsNothing);
    expect(find.byTooltip('Cambiar perfil'), findsNothing);
    expect(find.byTooltip('Editar perfil'), findsOneWidget);
    for (final label in ['Votaciones', 'Publicaciones guardadas']) {
      await tester.scrollUntilVisible(
        find.text(label),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.byType(PostCollectionPage), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }
    await tester.scrollUntilVisible(
      find.byTooltip('Editar perfil'),
      -250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(find.byTooltip('Editar perfil'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Editar perfil'));
    await tester.pumpAndSettle();
    expect(find.byType(EditProfilePage), findsOneWidget);
  });

  testWidgets(
    'pages long press opens switcher while profile long press does not',
    (tester) async {
      final repository = DemoCommunityRepository();
      final business = await repository.createCommunity(
        const CreateCommunityInput(
          name: 'My business',
          description: '',
          town: Town(id: 'town-1', name: 'Town X', countryCode: 'EC'),
          visibility: CommunityVisibility.public,
          categoryNames: ['General'],
          type: CommunityType.publicProfile,
          profileCategory: ProfileCategory.localBusiness,
        ),
      );
      final secondPage = await repository.createCommunity(
        const CreateCommunityInput(
          name: 'Second public page',
          description: '',
          town: Town(id: 'town-1', name: 'Town X', countryCode: 'EC'),
          visibility: CommunityVisibility.public,
          categoryNames: ['General'],
          type: CommunityType.publicProfile,
          profileCategory: ProfileCategory.creator,
        ),
      );
      await tester.pumpWidget(
        WicchuApp(
          repository: repository,
          authGateway: _FakeAuthGateway(signedIn: true),
        ),
      );
      await tester.pumpAndSettle();
      await tester.longPress(
        find.byKey(const ValueKey('bottom-profile-navigation')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Personal profile'), findsNothing);
      await tester.longPress(
        find.byKey(const ValueKey('bottom-pages-navigation')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Personal profile'), findsNothing);
      expect(find.text('Town X Community'), findsNothing);
      await tester.tap(find.text('My business').last);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CommunityProfilePage>(find.byType(CommunityProfilePage))
            .community
            .id,
        business.id,
      );
      await tester.tap(find.byKey(const ValueKey('business-top-options')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Create post'));
      await tester.pumpAndSettle();
      expect(find.byType(CreatePostPage), findsOneWidget);
      expect(
        tester.widget<CreatePostPage>(find.byType(CreatePostPage)).community.id,
        business.id,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('bottom-pages-navigation')),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Switch profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Second public page').last);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CommunityProfilePage>(find.byType(CommunityProfilePage))
            .community
            .id,
        secondPage.id,
      );
      await tester.tap(find.byKey(const ValueKey('bottom-profile-navigation')));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Edit profile'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('account-profile-identity')));
      await tester.pumpAndSettle();
      expect(find.byType(MemberProfilePage), findsOneWidget);
      expect(find.byType(CommunityProfilePage), findsNothing);
      expect(find.byTooltip('Switch profile'), findsNothing);
      final profile = await repository.getProfile();
      expect(
        tester.widget<MemberProfilePage>(find.byType(MemberProfilePage)).userId,
        profile.id,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('bottom-pages-navigation')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CommunityProfilePage>(find.byType(CommunityProfilePage))
            .community
            .id,
        secondPage.id,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('My pages'), findsOneWidget);
      expect(find.byType(CommunityProfilePage), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('another user profile hides edit controls', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MemberProfilePage(
          userId: 'another-user',
          repository: DemoCommunityRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(WicchuIcons.pencilSimple), findsNothing);
  });

  testWidgets('translates the current user label on a post', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('es'),
        supportedLocales: [Locale('en'), Locale('es')],
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: Scaffold(
          body: PostCard(
            category: 'General',
            icon: '💬',
            community: 'Echeandía',
            author: 'You',
            time: 'Hace 3 min',
            text: 'Jornada de limpieza',
          ),
        ),
      ),
    );
    expect(find.text('Tú'), findsOneWidget);
    expect(
      find.textContaining('Hace 3 min · Echeandía', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('💬 General'), findsNothing);
    await tester.tap(find.byTooltip('Más opciones'));
    await tester.pumpAndSettle();
    expect(find.text('Opciones de la publicación'), findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets('opens a community and its prominent categories', (tester) async {
    await tester.pumpWidget(
      WicchuApp(
        repository: DemoCommunityRepository(),
        authGateway: _FakeAuthGateway(signedIn: true),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Town X Community').first);
    await tester.pumpAndSettle();

    expect(find.byType(CommunityProfilePage), findsOneWidget);
    expect(find.text('About'), findsNothing);
    expect(find.text('Members'), findsNothing);
    expect(find.text('All'), findsOneWidget);
    expect(find.byTooltip('Customize categories'), findsOneWidget);
    await tester.tap(find.byTooltip('Customize categories'));
    await tester.pumpAndSettle();
    expect(find.text('Category notifications'), findsOneWidget);
    expect(find.text('Or choose specific categories'), findsOneWidget);
    await tester.tap(find.text('Reset selection'));
    await tester.pumpAndSettle();
    expect(find.text('Category notifications'), findsOneWidget);
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsNothing);
    await tester.tap(find.byKey(const ValueKey('community-composer-entry')));
    await tester.pumpAndSettle();
    expect(find.byType(PostRulesReviewPage), findsOneWidget);
    expect(find.byType(CreatePostPage), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(CreatePostPage), findsNothing);
    await tester.tap(find.byKey(const ValueKey('community-role-badge')));
    await tester.pumpAndSettle();
    expect(find.text('You own this community'), findsOneWidget);
    expect(find.text('Manage community'), findsNothing);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Manage community'), findsNothing);
    final informationEntry = find.byKey(
      const ValueKey('community-information-entry'),
    );
    tester.widget<InkWell>(informationEntry).onTap!.call();
    await tester.pumpAndSettle();
    final managementTabs = find.byKey(
      const ValueKey('community-information-tabs'),
    );
    await tester.tap(
      find.descendant(
        of: managementTabs,
        matching: find.text('Administration'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AdminDashboardPage), findsOneWidget);
    await tester.tap(
      find.descendant(of: managementTabs, matching: find.text('Information')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Public community'), findsOneWidget);
    expect(find.textContaining('Created '), findsOneWidget);
    expect(find.text('Categories'), findsNothing);
    for (final destination in [
      'Community rules',
      'Useful links',
      'Community rating',
    ]) {
      final row = find.widgetWithText(ListTile, destination);
      await tester.scrollUntilVisible(
        row,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.byType(AppBar), findsOneWidget);
      if (destination == 'Community rules') {
        expect(
          find.text('No community rules have been added yet.'),
          findsOneWidget,
        );
      } else if (destination == 'Useful links') {
        expect(find.text('Directions'), findsOneWidget);
      } else {
        expect(find.byType(ExpansionTile), findsOneWidget);
      }
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('community-information-content')),
        findsOneWidget,
      );
    }

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('information-members-entry')),
      -180,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(
      tester.element(find.byKey(const ValueKey('information-members-entry'))),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('information-members-entry')));
    await tester.pumpAndSettle();
    expect(find.text('Members'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('community-information-content')),
      findsOneWidget,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('community-header-members')));
    await tester.pumpAndSettle();
    expect(find.text('Members'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('All'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'business profile opens information, followers and inline composer',
    (tester) async {
      final repository = DemoCommunityRepository();
      final profile = await repository.createCommunity(
        const CreateCommunityInput(
          name: 'Local garden business',
          description: 'Gardens and pools',
          town: Town(id: 'town-1', name: 'Town X', countryCode: 'EC'),
          visibility: CommunityVisibility.public,
          categoryNames: ['Posts'],
          type: CommunityType.publicProfile,
          profileCategory: ProfileCategory.localBusiness,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CommunityProfilePage(
            community: profile,
            repository: repository,
            embedded: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Town X, Ecuador'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('local-business-contact')),
        findsOneWidget,
      );
      expect(find.text('About'), findsNothing);
      expect(find.text('Followers'), findsNothing);
      expect(find.text('All'), findsNothing);
      expect(find.text('Posts'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('community-information-entry')),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Gardens and pools', findRichText: true),
        findsOneWidget,
      );
      final followers = find.byKey(const ValueKey('information-members-entry'));
      await tester.scrollUntilVisible(
        followers,
        250,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.ensureVisible(followers);
      await tester.tap(followers);
      await tester.pumpAndSettle();
      expect(find.text('Followers'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('page-header-followers')));
      await tester.pumpAndSettle();
      expect(find.text('Followers'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('business-top-options')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Create post'));
      await tester.pumpAndSettle();
      expect(find.byType(CreatePostPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final category in ProfileCategory.values) {
    testWidgets('information and rating copy for ${category.name}', (
      tester,
    ) async {
      final repository = DemoCommunityRepository();
      final profile = await repository.createCommunity(
        CreateCommunityInput(
          name: 'A long public page name for layout checking',
          description: 'Page description',
          town: const Town(id: 'town-1', name: 'Town X', countryCode: 'EC'),
          visibility: CommunityVisibility.public,
          categoryNames: const ['Posts'],
          type: CommunityType.publicProfile,
          profileCategory: category,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CommunityProfilePage(
            community: profile,
            repository: repository,
            screen: CommunityScreen.information,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final title = category == ProfileCategory.localBusiness
          ? 'Business rating'
          : 'Profile rating';
      expect(find.text('Community rating'), findsNothing);
      final rating = find.text(title);
      await tester.ensureVisible(rating);
      await tester.tap(rating);
      await tester.pumpAndSettle();
      expect(find.text(title), findsWidgets);
      expect(find.textContaining('community score'), findsNothing);
      expect(
        find.textContaining(
          category == ProfileCategory.localBusiness
              ? 'There are not enough ratings yet.'
              : 'profile score',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('community draft is preserved when exit is cancelled', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CreateCommunityPage(repository: DemoCommunityRepository()),
      ),
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Community name'),
      'Draft group',
    );
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Discard community draft?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Draft group'), findsOneWidget);
    expect(find.byType(CreateCommunityPage), findsOneWidget);
  });

  testWidgets('public profile entry opens the form with profile selected', (
    tester,
  ) async {
    await tester.pumpWidget(
      WicchuApp(
        repository: DemoCommunityRepository(),
        authGateway: _FakeAuthGateway(signedIn: true),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('You').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Create a public profile'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await Scrollable.ensureVisible(
      tester.element(find.text('Create a public profile')),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create a public profile'));
    await tester.pumpAndSettle();
    expect(find.text('Page name'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('space-type-community')));
    await tester.pumpAndSettle();
    expect(find.text('Community name'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('creates a community even when the town list is empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      WicchuApp(
        repository: DemoCommunityRepository(),
        authGateway: _FakeAuthGateway(signedIn: true),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('You').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Create a community'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create a community'));
    await tester.pumpAndSettle();

    expect(find.text('Create a space'), findsOneWidget);
    expect(find.text('Community name'), findsOneWidget);

    final repository = _EmptyTownsRepository();
    var locationRequests = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: CreateCommunityPage(
          repository: repository,
          locateCurrentTown: () async {
            locationRequests++;
            return const Town(id: 'town-1', name: 'Town X', countryCode: 'EC');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
          .onPressed,
      isNull,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Community name'),
      'Riverside',
    );
    await tester.pumpAndSettle();
    for (var step = 0; step < 3; step++) {
      if (step == 1) {
        expect(locationRequests, 0);
        await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
        await tester.pumpAndSettle();
        expect(find.text('Choose a location to continue.'), findsOneWidget);
        await tester.tap(find.text('Use my current location'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pumpAndSettle();
    }
    expect(locationRequests, 1);
    await tester.ensureVisible(find.text('Add rule'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add rule'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a rule title.'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Rule title'),
      'Be kind',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Description'),
      'Respect your neighbors.',
    );
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Be kind'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Create space').last);
    await tester.pumpAndSettle();
    expect(find.text('Your community is ready!'), findsOneWidget);
    await tester.tap(find.text('Enter community'));
    await tester.pumpAndSettle();
    expect(
      (await repository.listCommunities()).any(
        (item) => item.name == 'Riverside',
      ),
      isTrue,
    );
  });

  for (final theme in ['light', 'dark']) {
    testWidgets(
      'location rows keep Apply visible on small Spanish screen $theme',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'onboarding_preferences_completed': true,
          'language': 'es',
          'themeMode': theme,
        });
        await tester.binding.setSurfaceSize(const Size(320, 640));
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(() {
          tester.binding.setSurfaceSize(null);
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });
        await tester.pumpWidget(
          WicchuApp(
            repository: DemoCommunityRepository(),
            authGateway: _FakeAuthGateway(signedIn: true),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Explorar'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Ubicación'));
        await tester.pumpAndSettle();
        expect(find.text('Filtrar por ubicación'), findsOneWidget);
        expect(find.byType(DropdownButtonFormField<String>), findsNothing);
        expect(find.text('Restablecer filtros'), findsNothing);
        final myTown = find.widgetWithText(RadioListTile<int>, 'Mi localidad');
        await tester.ensureVisible(myTown);
        await tester.tap(myTown);
        await tester.pumpAndSettle();
        final apply = find.widgetWithText(FilledButton, 'Aplicar filtros');
        expect(apply.hitTestable(), findsOneWidget);
        expect(tester.widget<FilledButton>(apply).onPressed, isNull);
        expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
        await tester.tap(find.text('Restablecer filtros'));
        await tester.pumpAndSettle();
        expect(find.byType(DropdownButtonFormField<String>), findsNothing);
        expect(tester.widget<FilledButton>(apply).onPressed, isNotNull);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'nearby choices apply only on confirmation and retain detected town',
    (tester) async {
      final locationReady = Completer<void>();
      const channel = MethodChannel('flutter.baseflow.com/geolocator');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        switch (call.method) {
          case 'isLocationServiceEnabled':
            return true;
          case 'checkPermission':
            return 3;
          case 'getCurrentPosition':
            await locationReady.future;
            return {
              'latitude': 1.0,
              'longitude': 2.0,
              'timestamp': 0,
              'accuracy': 1.0,
              'altitude': 0.0,
              'heading': 0.0,
              'speed': 0.0,
              'speed_accuracy': 0.0,
            };
        }
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      final repository = _TownDiscoveryRepository();
      final town = await repository.locateTown(latitude: 1, longitude: 2);
      await tester.pumpWidget(
        WicchuApp(
          repository: repository,
          authGateway: _FakeAuthGateway(signedIn: true),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Explore'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Location'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(RadioListTile<int>, 'Nearby towns'));
      await tester.pump();
      expect(find.text('Finding your current town…'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Apply filters'),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<RadioListTile<int>>(
              find.widgetWithText(RadioListTile<int>, 'Anywhere'),
            )
            .enabled,
        isFalse,
      );
      locationReady.complete();
      await tester.pumpAndSettle();
      expect(repository.nearbyCalls, 0);
      Navigator.of(tester.element(find.text('Apply filters'))).pop();
      await tester.pumpAndSettle();
      expect(repository.nearbyCalls, 0);
      await tester.tap(find.byTooltip('Location'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<RadioGroup<int>>(find.byType(RadioGroup<int>)).groupValue,
        0,
      );
      await tester.tap(find.widgetWithText(RadioListTile<int>, 'Nearby towns'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply filters'));
      await tester.pumpAndSettle();
      expect(repository.nearbyCalls, 1);
      expect(repository.excludedTown, town.id);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty Explore offers creation after changing location', (
    tester,
  ) async {
    await tester.pumpWidget(
      WicchuApp(
        repository: _EmptyExploreRepository(),
        authGateway: _FakeAuthGateway(signedIn: true),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();
    expect(find.text('No communities to explore yet'), findsOneWidget);
    await tester.tap(find.byTooltip('Location'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(RadioListTile<int>, 'Anywhere'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply filters'));
    await tester.pumpAndSettle();
    expect(find.text('No communities to explore yet'), findsOneWidget);
    await tester.ensureVisible(find.text('Create community'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create community'));
    await tester.pumpAndSettle();
    expect(find.byType(CreateCommunityPage), findsOneWidget);
  });

  testWidgets('searches communities in Explore', (tester) async {
    final repository = DemoCommunityRepository();
    await repository.createCommunity(
      const CreateCommunityInput(
        name: 'Riverside',
        description: 'Neighbors nearby',
        town: Town(id: 'town-1', name: 'Town X', countryCode: 'EC'),
        visibility: CommunityVisibility.public,
        categoryNames: ['General'],
      ),
    );
    await tester.pumpWidget(
      WicchuApp(
        repository: repository,
        authGateway: _FakeAuthGateway(signedIn: true),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Discover communities, businesses and public profiles near you.',
      ),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('explore-search')), findsOneWidget);
    expect(find.text('Businesses'), findsOneWidget);
    expect(find.text('People'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Riverside');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('Riverside'), findsWidgets);
    expect(find.text('Town X Community'), findsNothing);
    await tester.tap(find.byTooltip('Location'));
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButtonFormField<int>), findsNothing);
    expect(
      find.widgetWithText(RadioListTile<int>, 'Nearby towns'),
      findsOneWidget,
    );
    expect(find.widgetWithText(RadioListTile<int>, 'My town'), findsOneWidget);
    expect(find.textContaining('km'), findsNothing);
    expect(find.text('Reset filters'), findsNothing);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    await tester.tap(find.widgetWithText(RadioListTile<int>, 'My town'));
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Apply filters'),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Reset filters'));
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    await tester.tap(find.text('Apply filters'));
    await tester.pumpAndSettle();
    expect(find.text('Riverside'), findsWidgets);
    expect(find.text('No spaces match these filters.'), findsNothing);
  });

  testWidgets('People filter searches users instead of communities', (
    tester,
  ) async {
    await tester.pumpWidget(
      WicchuApp(
        repository: _PeopleExploreRepository(),
        authGateway: _FakeAuthGateway(signedIn: true),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('People'));
    await tester.pumpAndSettle();

    expect(find.text('Sanyi Ramos'), findsOneWidget);
    expect(find.text('@sanyi_ramos'), findsOneWidget);
    expect(find.text('0 shared communities'), findsNothing);
    expect(find.text('1 person found'), findsOneWidget);
    expect(find.text('Create community'), findsNothing);

    await tester.tap(find.byTooltip('Location'));
    await tester.pumpAndSettle();
    final nearMe = tester.widget<RadioListTile<int>>(
      find.widgetWithText(RadioListTile<int>, 'Near me'),
    );
    expect(nearMe.enabled, isTrue);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    await tester.tap(find.widgetWithText(RadioListTile<int>, 'My town'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>),
          )
          .onChanged,
      isNotNull,
    );
    expect(
      find.text('Location filtering for people is not available yet.'),
      findsNothing,
    );
    await tester.tap(find.text('Reset filters'));
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    await tester.tap(find.text('Apply filters'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('explore-search')),
      'unknown',
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text('No people found.'), findsOneWidget);
    expect(find.text('Create community'), findsNothing);
  });

  testWidgets('Businesses tab opens local business discovery', (tester) async {
    await tester.pumpWidget(
      WicchuApp(
        repository: DemoCommunityRepository(),
        authGateway: _FakeAuthGateway(signedIn: true),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Businesses'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('discovery-filters')), findsNothing);
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('People'), findsOneWidget);
  });

  testWidgets('requests popular category posts', (tester) async {
    final repository = _RecordingRepository();
    final community = (await repository.listCommunities()).first;
    final category = (await repository.listCategories(community.id)).first;
    await tester.pumpWidget(
      MaterialApp(
        home: CategoryPage(
          community: community,
          category: category,
          repository: repository,
          canPost: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Popular'));
    await tester.pumpAndSettle();

    expect(repository.lastSort, 'popular');
  });

  testWidgets('opens a notification post and marks it read', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _NotificationsRepository();
    final post = await repository.createPost(
      'town-x-community',
      const CreatePostInput(categoryId: 'category-0', text: 'Meeting tonight'),
    );
    repository.postId = post.id;
    await tester.pumpWidget(
      WicchuApp(
        repository: repository,
        authGateway: _FakeAuthGateway(signedIn: true),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Notification settings'));
    await tester.pumpAndSettle();
    expect(find.text('Post activity'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alex commented on your post'));
    await tester.pumpAndSettle();

    expect(repository.read, isTrue);
    expect(find.text('Meeting tonight'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unread'));
    await tester.pumpAndSettle();
    expect(find.text('You’re all caught up'), findsOneWidget);
    expect(find.text('Alex commented on your post'), findsNothing);
    await tester.tap(find.text('All notifications'));
    await tester.pumpAndSettle();
    expect(find.text('Alex commented on your post'), findsOneWidget);
  });

  testWidgets('report notification opens the reported post media', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _NotificationsRepository()
      ..type = CommunityNotificationType.reportCreated;
    final media = await repository.uploadPostMedia(
      bytes: const [1, 2, 3],
      filename: 'reported-image.jpg',
      mimeType: 'image/jpeg',
    );
    final post = await repository.createPost(
      'town-x-community',
      CreatePostInput(
        categoryId: 'category-0',
        text: 'Reported image publication',
        media: [media],
      ),
    );
    repository.postId = post.id;

    await tester.pumpWidget(
      WicchuApp(
        repository: repository,
        authGateway: _FakeAuthGateway(signedIn: true),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alex reported a post'));
    await tester.pumpAndSettle();

    expect(repository.read, isTrue);
    expect(find.text('Reported image publication'), findsOneWidget);
    expect(find.byType(PostCard), findsOneWidget);
    expect(find.byType(PostMediaGallery), findsOneWidget);
    await tester.tap(find.byType(PostMediaGallery));
    await tester.pumpAndSettle();
    expect(find.byType(PostMediaViewer), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reward notification opens the community rewards page', (
    tester,
  ) async {
    final repository = _NotificationsRepository()
      ..type = CommunityNotificationType.rewardRequestApproved
      ..communityId = 'town-x-community';

    await tester.pumpWidget(
      WicchuApp(
        repository: repository,
        authGateway: _FakeAuthGateway(signedIn: true),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('notification-notification-1')));
    await tester.pumpAndSettle();

    expect(repository.read, isTrue);
    expect(find.text('Rewards'), findsOneWidget);
    expect(find.byType(CommunityRewardsPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('new reward request notification opens the rewards queue', (
    tester,
  ) async {
    final repository = _NotificationsRepository()
      ..type = CommunityNotificationType.rewardRequest;

    await tester.pumpWidget(
      WicchuApp(
        repository: repository,
        authGateway: _FakeAuthGateway(signedIn: true),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('notification-notification-1')));
    await tester.pumpAndSettle();

    expect(repository.read, isTrue);
    expect(find.byType(PlatformModerationPage), findsOneWidget);
    expect(tester.widget<TabBar>(find.byType(TabBar)).controller?.index, 2);
    expect(find.text('No pending reward requests.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending post notification opens the community approval queue', (
    tester,
  ) async {
    final repository = _NotificationsRepository()
      ..type = CommunityNotificationType.postPending
      ..communityId = 'town-x-community';
    final post = await repository.createPost(
      'town-x-community',
      const CreatePostInput(
        categoryId: 'category-0',
        text: 'Please review this post',
      ),
    );
    repository.postId = post.id;
    await tester.pumpWidget(
      WicchuApp(
        repository: repository,
        authGateway: _FakeAuthGateway(signedIn: true),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alex commented on your post'));
    await tester.pumpAndSettle();
    expect(repository.reviewedCommunity, 'town-x-community');
    expect(repository.read, isTrue);
    expect(find.text('Approval queue'), findsOneWidget);
    expect(find.text('Please review this post'), findsOneWidget);
    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);
  });

  testWidgets('Facebook authentication errors remain visible', (tester) async {
    await tester.pumpWidget(
      WicchuApp(
        repository: DemoCommunityRepository(),
        authGateway: _FailingFacebookGateway(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with Facebook'));
    await tester.pumpAndSettle();
    expect(find.text('Facebook token could not be verified.'), findsOneWidget);
    expect(find.text('Facebook sign-in is unavailable.'), findsNothing);
  });

  testWidgets('offers Google and Facebook when signed out', (tester) async {
    await tester.pumpWidget(
      WicchuApp(
        repository: DemoCommunityRepository(),
        authGateway: _FakeAuthGateway(signedIn: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Continue with Facebook'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('offers verified email registration when Facebook has no email', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_preferences_completed': true,
    });
    await tester.pumpWidget(
      WicchuApp(
        repository: DemoCommunityRepository(),
        authGateway: _FakeAuthGateway(
          signedIn: false,
          facebookError: const AuthException(
            'This Facebook account does not provide an email address. Register with a verified email instead.',
            code: 'FACEBOOK_EMAIL_UNAVAILABLE',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue with Facebook'));
    await tester.pumpAndSettle();
    expect(find.text('Use email'), findsOneWidget);

    await tester.tap(find.text('Use email'));
    await tester.pumpAndSettle();
    expect(find.text('Create account'), findsWidgets);
  });

  testWidgets('existing Facebook email directs user to email sign-in', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_preferences_completed': true,
    });
    await tester.pumpWidget(
      WicchuApp(
        repository: DemoCommunityRepository(),
        authGateway: _FakeAuthGateway(
          signedIn: false,
          facebookError: const AuthException(
            'An account already uses this email.',
            code: 'EMAIL_ALREADY_REGISTERED',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue with Facebook'));
    await tester.pumpAndSettle();
    expect(find.text('Account already exists'), findsOneWidget);
    expect(find.text('Sign in with email'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);

    await tester.tap(find.text('Sign in with email'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('existing Facebook email can open password recovery', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_preferences_completed': true,
    });
    await tester.pumpWidget(
      WicchuApp(
        repository: DemoCommunityRepository(),
        authGateway: _FakeAuthGateway(
          signedIn: false,
          facebookError: const AuthException(
            'An account already uses this email.',
            code: 'EMAIL_ALREADY_REGISTERED',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue with Facebook'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    expect(find.text('Reset password'), findsOneWidget);
    expect(find.text('Recover access to your account'), findsOneWidget);
  });

  testWidgets('Facebook conflict directs an existing Google user correctly', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_preferences_completed': true,
    });
    await tester.pumpWidget(
      WicchuApp(
        repository: DemoCommunityRepository(),
        authGateway: _FakeAuthGateway(
          signedIn: false,
          facebookError: const AuthException(
            'Sign in with your existing method.',
            code: 'ACCOUNT_LINK_REQUIRED',
            existingProvider: 'google',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue with Facebook'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Continue with Google'),
      ),
      findsOneWidget,
    );
    expect(find.text('Forgot password?'), findsNothing);
    expect(
      find.textContaining('Continue with Google, then connect Facebook'),
      findsOneWidget,
    );
  });

  testWidgets('switches between Spanish and English across the home screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      WicchuApp(
        repository: DemoCommunityRepository(),
        authGateway: _FakeAuthGateway(signedIn: true),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('You').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Language and appearance'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await Scrollable.ensureVisible(
      tester.element(find.text('Language and appearance')),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Language and appearance'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Español'));
    await tester.pumpAndSettle();
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
    expect(find.text('Inicio'), findsOneWidget);
    await tester.tap(find.text('Inicio').last);
    await tester.pumpAndSettle();
    expect(find.text('Para ti'), findsOneWidget);

    final spanishContext = tester.element(find.text('Inicio'));
    expect(
      formatPostTime(
        spanishContext,
        DateTime.now().subtract(const Duration(minutes: 3)),
      ),
      '3 min',
    );
    expect(
      spanishContext.trError(Exception('Server message without a translation')),
      'Ha ocurrido un error. Inténtalo de nuevo.',
    );
    await tester.tap(find.text('Tú').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('1 espacio · 0 publicaciones'),
      -250,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('1 espacio · 0 publicaciones'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Cerrar sesión'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Cerrar sesión'), findsOneWidget);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Inicio').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tú').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Idioma y apariencia'),
      -250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Idioma y apariencia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('translates the admin review queue', (tester) async {
    SharedPreferences.setMockInitialValues({
      'language': 'es',
      'onboarding_preferences_completed': true,
    });
    await tester.pumpWidget(
      WicchuApp(
        repository: DemoCommunityRepository(),
        authGateway: _FakeAuthGateway(signedIn: true),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Explorar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Town X Community').first);
    await tester.pumpAndSettle();
    tester
        .widget<InkWell>(
          find.byKey(const ValueKey('community-information-entry')),
        )
        .onTap!
        .call();
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('community-information-tabs')),
        matching: find.text('Administración'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Moderación'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Moderación'));
    await tester.pumpAndSettle();

    expect(
      find.text('No hay denuncias abiertas que requieran tu atención.'),
      findsOneWidget,
    );
  });

  testWidgets('changes and saves the appearance setting', (tester) async {
    await tester.pumpWidget(
      WicchuApp(
        repository: DemoCommunityRepository(),
        authGateway: _FakeAuthGateway(signedIn: true),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('You').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Language and appearance'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(
      tester.element(find.text('Language and appearance')),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Language and appearance'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark').last);
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    expect(
      (await SharedPreferences.getInstance()).getString('themeMode'),
      'dark',
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Light').last);
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.light,
    );
  });
}
