import '../domain/community_models.dart';
import '../domain/community_repository.dart';

class DemoCommunityRepository implements CommunityRepository {
  DemoCommunityRepository() {
    const town = Town(id: 'town-1', name: 'Town X', countryCode: 'EC');
    _communities.add(
      Community(
        id: 'town-x-community',
        name: 'Town X Community',
        description: 'Local community for Town X',
        town: town,
        visibility: CommunityVisibility.public,
        createdBy: 'current-user',
        createdAt: DateTime(2026),
        memberCount: 2481,
        myRole: CommunityRole.owner,
      ),
    );
    _categories['town-x-community'] = [
      for (final (index, name) in const [
        'News',
        'Marketplace',
        'Jobs',
        'Events',
        'Housing',
        'General',
        'Politics',
        'Local Businesses',
      ].indexed)
        CommunityCategory(
          id: 'category-$index',
          communityId: 'town-x-community',
          name: name,
          icon: _iconFor(name),
        ),
    ];
  }

  final List<Community> _communities = [];
  final Map<String, List<CommunityCategory>> _categories = {};
  final Map<String, List<CommunityPost>> _posts = {};
  final Map<String, List<Comment>> _comments = {};
  final Set<String> _savedPostIds = {};

  static const _towns = [Town(id: 'town-1', name: 'Town X', countryCode: 'EC')];

  @override
  Future<WicchuProfile> getProfile() async => const WicchuProfile(
    id: 'current-user',
    name: 'Michael P.',
    userName: 'michael',
    communityCount: 1,
    postCount: 0,
    savedPostCount: 0,
  );

  @override
  Future<NotificationFeed> listNotifications() async =>
      const NotificationFeed(items: [], unreadCount: 0);

  @override
  Future<void> markNotificationRead(String notificationId) async {}

  @override
  Future<void> markAllNotificationsRead() async {}

  @override
  Future<List<Town>> listTowns() async => _towns;

  @override
  Future<List<Community>> listManagedCommunities() async =>
      List.unmodifiable(_communities);

  @override
  Future<List<Community>> listCommunities() async =>
      List.unmodifiable(_communities);

  @override
  Future<List<Community>> listJoinedCommunities() async =>
      List.unmodifiable(_communities);

  @override
  Future<Community> createCommunity(CreateCommunityInput input) async {
    final id = 'community-${_communities.length + 1}';
    final community = Community(
      id: id,
      name: input.name,
      description: input.description,
      town: input.town,
      visibility: input.visibility,
      createdBy: 'current-user',
      createdAt: DateTime.now(),
      memberCount: 1,
      myRole: CommunityRole.owner,
    );
    _communities.add(community);
    _categories[id] = [
      for (final (index, name) in input.categoryNames.indexed)
        CommunityCategory(
          id: 'category-$index',
          communityId: id,
          name: name,
          icon: _iconFor(name),
        ),
    ];
    return community;
  }

  @override
  Future<PostMedia> uploadPostMedia({
    required List<int> bytes,
    required String filename,
    required String mimeType,
  }) async => PostMedia(
    url: filename,
    type: mimeType.startsWith('video/') ? 'video' : 'image',
    blobName: filename,
  );

  @override
  Future<void> joinCommunity(String communityId) async {}

  @override
  Future<void> leaveCommunity(String communityId) async {}

  @override
  Future<List<CommunityCategory>> listCategories(String communityId) async =>
      List.unmodifiable(_categories[communityId] ?? const []);

  @override
  Future<List<CommunityPost>> listPosts(
    String communityId, {
    String? categoryId,
    String? query,
  }) async => List.unmodifiable(
    (_posts[communityId] ?? const []).where(
      (post) =>
          (categoryId == null || post.categoryId == categoryId) &&
          (query == null ||
              post.text.toLowerCase().contains(query.toLowerCase())),
    ),
  );

  @override
  Future<List<CommunityPost>> listFollowingPosts({String? query}) async =>
      List.unmodifiable(
        _posts.values
            .expand((posts) => posts)
            .where(
              (post) =>
                  query == null ||
                  post.text.toLowerCase().contains(query.toLowerCase()),
            ),
      );

  @override
  Future<CommunityPost> createPost(
    String communityId,
    CreatePostInput input,
  ) async {
    final post = CommunityPost(
      id: 'post-${DateTime.now().microsecondsSinceEpoch}',
      communityId: communityId,
      categoryId: input.categoryId,
      authorId: 'current-user',
      authorName: 'You',
      text: input.text,
      status: PostStatus.published,
      createdAt: DateTime.now(),
      media: input.media,
    );
    _posts.putIfAbsent(communityId, () => []).insert(0, post);
    return post;
  }

  @override
  Future<int> setPostReaction(String postId, {required bool reacted}) async =>
      reacted ? 1 : 0;

  @override
  Future<List<Comment>> listComments(String postId) async =>
      List.unmodifiable(_comments[postId] ?? const []);

  @override
  Future<Comment> createComment(String postId, String text) async {
    final comment = Comment(
      id: 'comment-${DateTime.now().microsecondsSinceEpoch}',
      postId: postId,
      authorId: 'current-user',
      authorName: 'You',
      text: text,
      createdAt: DateTime.now(),
    );
    _comments.putIfAbsent(postId, () => []).add(comment);
    return comment;
  }

  @override
  Future<List<CommunityPost>> listMyPosts() async => List.unmodifiable(
    _posts.values
        .expand((posts) => posts)
        .where((post) => post.authorId == 'current-user'),
  );

  @override
  Future<List<CommunityPost>> listSavedPosts() async => List.unmodifiable(
    _posts.values
        .expand((posts) => posts)
        .where((post) => _savedPostIds.contains(post.id)),
  );

  @override
  Future<void> setPostSaved(String postId, {required bool saved}) async {
    saved ? _savedPostIds.add(postId) : _savedPostIds.remove(postId);
  }

  @override
  Future<void> reportPost(String postId, String reason) async {}

  @override
  Future<AdminAttentionSummary> getAdminAttention(String communityId) async =>
      const AdminAttentionSummary();

  @override
  Future<List<CommunityReport>> listReports(String communityId) async => [];

  @override
  Future<void> decideReport(
    String communityId,
    String reportId, {
    required bool resolve,
  }) async {}

  @override
  Future<List<MembershipRequest>> listMembershipRequests(
    String communityId,
  ) async => [];

  @override
  Future<void> decideMembershipRequest(
    String communityId,
    String userId, {
    required bool approve,
  }) async {}

  @override
  Future<List<CommunityPost>> listPendingPosts(String communityId) async =>
      List.unmodifiable(
        (_posts[communityId] ?? const []).where(
          (post) => post.status == PostStatus.pendingApproval,
        ),
      );

  @override
  Future<void> moderatePost(
    String communityId,
    String postId, {
    required bool approve,
    String? reason,
  }) async {}

  static String _iconFor(String name) => switch (name) {
    'News' => '📢',
    'Marketplace' => '🛒',
    'Jobs' => '💼',
    'Events' => '🎉',
    'Local Businesses' => '🏪',
    'Housing' => '🏠',
    'Politics' => '🏛',
    _ => '💬',
  };
}
