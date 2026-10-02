import 'package:wicchu/features/community/post_rules_review_page.dart';
import 'package:wicchu/features/community/create_post_page.dart';
import 'dart:async';
import 'package:wicchu/features/community/post_rich_text_editor.dart';
import 'package:wicchu/features/community/category_page.dart';
import 'package:wicchu/features/community/community_profile_page.dart';
import 'package:flutter/material.dart';
import 'package:wicchu/features/auth/email_auth_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/auth_gateway.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/domain/community_repository.dart';
import 'package:wicchu/features/admin/create_community_page.dart';
import 'package:wicchu/features/community/post_card.dart';
import 'package:wicchu/localization/app_language.dart';
import 'package:wicchu/main.dart';
import 'package:wicchu/features/profile/member_profile_page.dart';
import 'package:wicchu/features/profile/edit_profile_links.dart';

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

class _FakeAuthGateway implements AuthGateway {
  _FakeAuthGateway({required this.signedIn});
  final bool signedIn;

  @override
  Future<bool> hasSession() async => signedIn;

  @override
  Future<AuthSession> signInWithFacebook() async => const AuthSession(
    accessToken: 'access',
    refreshToken: 'refresh',
    userId: 'user-1',
    userName: 'test_user',
    isNewUser: true,
  );

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
  late String postId;
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
        message: 'commented on your post',
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
  Future<List<Community>> listCommunities({String? query}) async => [];
  @override
  Future<List<Community>> listJoinedCommunities() async => [];
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

void main() {
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
    await tester.tap(find.byTooltip('Account menu'));
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

  setUp(() => SharedPreferences.setMockInitialValues({}));

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

    expect(find.text('Wicchu'), findsOneWidget);
    expect(find.text('For you'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);
    expect(find.text('Community'), findsOneWidget);
    expect(find.byTooltip('Notifications'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
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
    expect(find.text('Wicchu'), findsOneWidget);
    expect(find.text('Find your community'), findsOneWidget);
    expect(find.text('No posts found'), findsNothing);
    await tester.tap(find.text('Explore communities'));
    await tester.pumpAndSettle();
    expect(find.text('Town X Community'), findsWidgets);
  });

  testWidgets(
    'community tab switches profiles and shares selection with Home',
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
      await tester.tap(find.text('Community'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Choose a community'));
      await tester.pumpAndSettle();
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

      await tester.tap(find.bySemanticsLabel('Post'));
      await tester.pumpAndSettle();
      expect(find.byType(PostRulesReviewPage), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(
        find.text('Posting to Second neighborhood', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Category'), findsWidgets);
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
    },
  );

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
      await tester.tap(find.byTooltip('My spaces'));
      await tester.pumpAndSettle();
      final sheetList = find.descendant(
        of: find.byType(DraggableScrollableSheet),
        matching: find.byType(ListView),
      );
      final initialHeight = tester.getSize(sheetList).height;
      await tester.drag(sheetList, const Offset(0, -260));
      await tester.pumpAndSettle();
      expect(tester.getSize(sheetList).height, greaterThan(initialHeight));
      await tester.tap(find.text('Second neighborhood'));
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
    await tester.tap(find.byTooltip('Account menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined).first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Delete account'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Delete account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    final fields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.first, 'review-password');
    await tester.enterText(fields.last, 'DELETE');
    await tester.tap(find.widgetWithText(FilledButton, 'Delete account'));
    await tester.pumpAndSettle();
    expect(find.text('Continue with email'), findsOneWidget);
    expect(find.text('Continue with Facebook'), findsNothing);
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
    await tester.tap(find.byTooltip('Account menu'));
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
    expect(find.text('Continue with Facebook'), findsNothing);
    expect(find.text('Continue with Google'), findsOneWidget);

    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('For you'), findsOneWidget);
  });

  testWidgets('home uses the central post action across multiple towns', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'language': 'es'});
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
    expect(find.byIcon(CupertinoIcons.plus), findsOneWidget);

    await tester.tap(find.byIcon(CupertinoIcons.plus));
    await tester.pumpAndSettle();
    expect(find.text('Elige una comunidad'), findsOneWidget);
    await tester.tap(find.text('Echeandía').last);
    await tester.pumpAndSettle();
    expect(find.text('¿Qué quieres publicar?'), findsNothing);
    expect(find.text('Crear publicación'), findsOneWidget);
    final publish = find.widgetWithText(FilledButton, 'Publicar');
    expect(tester.widget<FilledButton>(publish).onPressed, isNull);
    final controller = tester
        .widget<PostRichTextEditor>(find.byType(PostRichTextEditor))
        .controller;
    controller.replaceText(
      0,
      0,
      'A new community post',
      const TextSelection.collapsed(offset: 20),
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(publish).onPressed, isNotNull);
    controller.replaceText(
      0,
      controller.document.length - 1,
      '',
      const TextSelection.collapsed(offset: 0),
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(publish).onPressed, isNull);
  });

  testWidgets('personal profile editing is accessed through the account menu', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'language': 'es'});
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
    expect(find.byType(MemberProfilePage), findsOneWidget);
    expect(find.byTooltip('Cambiar perfil'), findsOneWidget);
    expect(find.text('Editar perfil'), findsNothing);
    await tester.tap(find.byTooltip('Menú de cuenta'));
    await tester.pumpAndSettle();
    expect(find.text('Editar perfil'), findsOneWidget);
    await tester.tap(find.text('Editar perfil'));
    await tester.pumpAndSettle();
    expect(find.byType(EditProfilePage), findsOneWidget);
  });

  testWidgets(
    'profile switcher selects a managed business and returns to personal',
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
      await tester.pumpWidget(
        WicchuApp(
          repository: repository,
          authGateway: _FakeAuthGateway(signedIn: true),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('You'));
      await tester.pumpAndSettle();
      expect(find.byType(MemberProfilePage), findsOneWidget);
      await tester.tap(find.byTooltip('Switch profile'));
      await tester.pumpAndSettle();
      expect(find.text('Town X Community'), findsNothing);
      await tester.tap(find.text('My business'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CommunityProfilePage>(find.byType(CommunityProfilePage))
            .community
            .id,
        business.id,
      );
      await tester.tap(find.bySemanticsLabel('Post'));
      await tester.pumpAndSettle();
      expect(find.byType(CreatePostPage), findsOneWidget);
      expect(
        tester.widget<CreatePostPage>(find.byType(CreatePostPage)).community.id,
        business.id,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Switch profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Personal profile'));
      await tester.pumpAndSettle();
      expect(find.byType(MemberProfilePage), findsOneWidget);
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
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
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
    expect(find.text('General'), findsOneWidget);
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
    expect(find.text('Manage community'), findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('community-information-entry')));
    await tester.pumpAndSettle();
    expect(find.text('Community type'), findsOneWidget);
    expect(find.text('Creation date'), findsOneWidget);
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
    await tester.tap(find.byKey(const ValueKey('community-members-entry')));
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
      expect(find.textContaining('Local business'), findsOneWidget);
      expect(find.text('About'), findsNothing);
      expect(find.text('Followers'), findsNothing);
      expect(find.text('All'), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('community-information-entry')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Gardens and pools'), findsOneWidget);
      final followers = find.byKey(const ValueKey('information-members-entry'));
      await tester.ensureVisible(followers);
      await tester.tap(followers);
      await tester.pumpAndSettle();
      expect(find.text('Followers'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('community-members-entry')));
      await tester.pumpAndSettle();
      expect(find.text('Followers'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      final composer = find.byKey(const ValueKey('community-composer-entry'));
      await tester.ensureVisible(composer);
      await tester.tap(composer);
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
              ? 'business score'
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
    await tester.tap(find.byTooltip('Account menu'));
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
    await tester.tap(find.byTooltip('Account menu'));
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
        expect(
          find.text('Confirm your current location to continue.'),
          findsOneWidget,
        );
        await tester.tap(find.text('Use my current location'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pumpAndSettle();
    }
    expect(locationRequests, 1);
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
    await tester.tap(
      find.widgetWithText(FilledButton, 'Create community').last,
    );
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

  testWidgets(
    'empty Explore offers creation and joined filter stays distinct',
    (tester) async {
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
      await tester.tap(find.byTooltip('Discovery filters'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<int>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('My communities').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply filters'));
      await tester.pumpAndSettle();
      expect(find.text('Find your community'), findsOneWidget);
      await tester.ensureVisible(find.text('All'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create community'));
      await tester.pumpAndSettle();
      expect(find.byType(CreateCommunityPage), findsOneWidget);
    },
  );

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
    await tester.tap(find.byTooltip('Discovery filters'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<int>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('500 or more').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply filters'));
    await tester.pumpAndSettle();
    expect(find.text('No spaces match these filters.'), findsOneWidget);
    await tester.tap(find.text('Adjust filters'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset filters'));
    await tester.pumpAndSettle();
    expect(find.text('Riverside'), findsWidgets);
    expect(find.text('No spaces match these filters.'), findsNothing);
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

  testWidgets('offers Google and hides Facebook when signed out', (
    tester,
  ) async {
    await tester.pumpWidget(
      WicchuApp(
        repository: DemoCommunityRepository(),
        authGateway: _FakeAuthGateway(signedIn: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Continue with Facebook'), findsNothing);
    expect(find.text('Continue with Google'), findsOneWidget);
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
    await tester.tap(find.byTooltip('Account menu'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('EN'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('EN').first);
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
    await tester.tap(find.byTooltip('Menú de cuenta'));
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
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Inicio').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tú').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Menú de cuenta'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('ES'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('ES').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('translates the admin review queue', (tester) async {
    SharedPreferences.setMockInitialValues({'language': 'es'});
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
    await tester.tap(find.byKey(const ValueKey('community-role-badge')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Administrar comunidad'));
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
    await tester.tap(find.byTooltip('Account menu'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byTooltip('Appearance'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Appearance').first);
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
    await tester.tap(find.byTooltip('Appearance').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Light').last);
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.light,
    );
  });
}
