import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/localization/app_language.dart';
import 'package:wicchu/features/profile/member_profile_page.dart';

class _RetryRepository extends DemoCommunityRepository {
  int calls = 0;
  final cursors = <String?>[];
  @override
  Future<UserFollowPage> listFollowingUsers(
    String userId, {
    String? cursor,
  }) async {
    calls++;
    cursors.add(cursor);
    if (calls == 1 || calls == 3) throw Exception('Temporary failure');
    return UserFollowPage(
      users: [
        UserFollowProfile(
          id: 'person$calls',
          name: 'Person $calls',
          userName: 'person$calls',
        ),
      ],
      nextCursor: calls == 2 ? 'next' : null,
    );
  }
}

class _PrivateProfileRepository extends DemoCommunityRepository {
  @override
  Future<PublicMemberProfile> getMemberProfile(String userId) async =>
      const PublicMemberProfile(
        id: 'private-user',
        name: 'Private member',
        userName: 'private.member',
        postCount: 0,
        communityCount: 0,
        followerCount: 2,
        followingCount: 1,
        isPrivate: true,
        canViewPersonalPosts: false,
      );

  @override
  Future<UserFollowActionResult> followUser(String userId) async =>
      const UserFollowActionResult(
        status: UserFollowStatus.pending,
        followerCount: 2,
      );

  @override
  Future<List<CommunityPost>> listMemberPosts(
    String userId, {
    String kind = 'all',
    String sort = 'newest',
  }) async => const [];
}

class _PrivateAccessRepository extends DemoCommunityRepository {
  bool following = true;
  int postLoads = 0;
  @override
  Future<PublicMemberProfile> getMemberProfile(String userId) async =>
      PublicMemberProfile(
        id: 'private-user',
        name: 'Private member',
        userName: 'private.member',
        postCount: 1,
        communityCount: 0,
        isPrivate: true,
        canViewPersonalPosts: following,
        followedByMe: following,
        followStatus: following
            ? UserFollowStatus.accepted
            : UserFollowStatus.none,
      );
  @override
  Future<UserFollowActionResult> unfollowUser(String userId) async {
    following = false;
    return const UserFollowActionResult(
      status: UserFollowStatus.none,
      followerCount: 0,
    );
  }

  @override
  Future<List<CommunityPost>> listMemberPosts(
    String userId, {
    String kind = 'all',
    String sort = 'newest',
  }) async {
    postLoads++;
    // Simulate a cached response: the permission flag must still be respected.
    return [
      CommunityPost(
        id: 'private-post',
        communityId: '',
        categoryId: '',
        authorId: userId,
        text: 'Private personal content',
        destinationType: 'personal',
        status: PostStatus.published,
        createdAt: DateTime(2026),
      ),
    ];
  }
}

class _FollowRequestRepository extends DemoCommunityRepository {
  bool? accepted;

  @override
  Future<PublicMemberProfile> getMemberProfile(String userId) async =>
      const PublicMemberProfile(
        id: 'current-user',
        name: 'Profile owner',
        userName: 'owner',
        postCount: 0,
        communityCount: 0,
        followRequestCount: 1,
        isPrivate: true,
      );

  @override
  Future<UserFollowPage> listFollowRequests({String? cursor}) async =>
      const UserFollowPage(
        users: [
          UserFollowProfile(
            id: 'requester',
            name: 'Requesting member',
            userName: 'requester',
          ),
        ],
      );

  @override
  Future<void> respondToFollowRequest(
    String userId, {
    required bool accept,
  }) async {
    accepted = accept;
  }
}

void main() {
  testWidgets('unfollowing refreshes and removes private personal posts', (
    tester,
  ) async {
    final repository = _PrivateAccessRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: MemberProfilePage(userId: 'private-user', repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Private personal content'), findsOneWidget);
    final loads = repository.postLoads;
    await tester.ensureVisible(find.text('Following'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Following'));
    await tester.pumpAndSettle();
    expect(repository.postLoads, greaterThan(loads));
    expect(find.text('Private personal content'), findsNothing);
    expect(find.text('This profile is private'), findsOneWidget);
  });

  testWidgets(
    'returning from account settings refreshes the short description',
    (tester) async {
      final repository = DemoCommunityRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: MemberProfilePage(
            userId: 'current-user',
            repository: repository,
            onAccountMenu: () async {
              final current = await repository.getEditableProfile();
              await repository.updateEditableProfile(
                EditableMemberProfile(
                  name: current.name,
                  userName: current.userName,
                  shortDescription: 'A new short description',
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('A new short description'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('personal-profile-options')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('You'));
      await tester.pumpAndSettle();
      expect(find.text('A new short description'), findsOneWidget);
    },
  );

  testWidgets(
    'follow list retries initial and pagination failures without automatic loops',
    (tester) async {
      final repository = _RetryRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: MemberProfilePage(
            userId: 'current-user',
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile-following-count')));
      await tester.pumpAndSettle();
      expect(repository.calls, 1);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Person 2'), findsOneWidget);
      expect(repository.calls, 2);
      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();
      expect(find.text('Person 2'), findsOneWidget);
      expect(repository.calls, 3);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Person 4'), findsOneWidget);
      expect(repository.cursors, [null, null, 'next', 'next']);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 400));
      await tester.pumpAndSettle();
      expect(repository.cursors.last, isNull);
      expect(find.text('Person 5'), findsOneWidget);
      expect(find.text('Person 2'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Spanish compact profile and publishing destination are localized',
    (tester) async {
      final postRequest = ValueNotifier<int>(0);
      addTearDown(postRequest.dispose);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('es'),
          supportedLocales: const [Locale('en'), Locale('es')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (_, child) => AppLanguageScope(
            languageCode: 'es',
            onLanguageChanged: (_) {},
            child: child!,
          ),
          home: MemberProfilePage(
            userId: 'current-user',
            repository: DemoCommunityRepository(),
            postRequest: postRequest,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey('profile-create-publication')),
        findsNothing,
      );
      postRequest.value++;
      await tester.pumpAndSettle();
      expect(find.text('Publicar en'), findsOneWidget);
      expect(find.text('Mi perfil'), findsWidgets);
      await tester.tap(find.text('Cambiar'));
      await tester.pumpAndSettle();
      expect(find.text('Elige dónde publicar'), findsOneWidget);
      expect(find.text('My profile'), findsNothing);
      expect(find.text('Community'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

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
    final postRequest = ValueNotifier<int>(0);
    addTearDown(postRequest.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: MemberProfilePage(
          userId: 'current-user',
          repository: repository,
          postRequest: postRequest,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('profile-create-publication')),
      findsNothing,
    );
    postRequest.value++;
    await tester.pumpAndSettle();

    expect(find.text('My profile'), findsWidgets);
    expect(find.text('Photos or video'), findsOneWidget);

    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
    expect(find.text('Choose where to publish'), findsOneWidget);
    expect(find.text('Personal publication'), findsWidgets);
  });

  testWidgets('private profiles require an approved follow request', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MemberProfilePage(
          userId: 'private-user',
          repository: _PrivateProfileRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('This profile is private'), findsOneWidget);
    expect(find.text('Follow'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('profile-follow-button')));
    await tester.pumpAndSettle();

    expect(find.text('Requested'), findsOneWidget);
    expect(find.text('Follow request sent'), findsOneWidget);
  });

  testWidgets('profile owner can approve a follow request', (tester) async {
    final repository = _FollowRequestRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: MemberProfilePage(userId: 'current-user', repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Follow requests'));
    await tester.pumpAndSettle();
    expect(find.text('Requesting member'), findsOneWidget);
    await tester.tap(find.byTooltip('Accept'));
    await tester.pumpAndSettle();

    expect(repository.accepted, isTrue);
    expect(find.text('Requesting member'), findsNothing);
  });
}
