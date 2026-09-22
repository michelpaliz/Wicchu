import 'community_models.dart';

class CreateCommunityInput {
  const CreateCommunityInput({
    required this.name,
    required this.description,
    required this.town,
    required this.visibility,
    required this.categoryNames,
    this.approvalRequired = false,
  });

  final String name;
  final String description;
  final Town town;
  final CommunityVisibility visibility;
  final List<String> categoryNames;
  final bool approvalRequired;
}

class AdminAttentionSummary {
  const AdminAttentionSummary({
    this.pendingPosts = 0,
    this.openReports = 0,
    this.membershipRequests = 0,
  });

  final int pendingPosts;
  final int openReports;
  final int membershipRequests;
}

class CreatePostInput {
  const CreatePostInput({
    required this.categoryId,
    required this.text,
    this.media = const [],
  });

  final String categoryId;
  final String text;
  final List<PostMedia> media;
}

abstract interface class CommunityRepository {
  Future<List<Town>> listTowns();
  Future<Town> locateTown({
    required double latitude,
    required double longitude,
  });
  Future<WicchuProfile> getProfile();
  Future<NotificationFeed> listNotifications();
  Future<void> markNotificationRead(String notificationId);
  Future<void> markAllNotificationsRead();
  Future<List<Community>> listCommunities({String? query});
  Future<List<Community>> listJoinedCommunities();
  Future<List<Community>> listManagedCommunities();
  Future<List<Community>> listNearbyCommunities({
    required double latitude,
    required double longitude,
    double radiusKm = 25,
  });
  Future<Community> createCommunity(CreateCommunityInput input);
  Future<void> joinCommunity(String communityId);
  Future<void> leaveCommunity(String communityId);
  Future<List<CommunityCategory>> listCategories(String communityId);
  Future<CommunityCategory> createCategory(
    String communityId, {
    required String name,
    String description,
  });
  Future<CommunityCategory> updateCategory(
    String communityId,
    CommunityCategory category, {
    required String name,
    required String description,
  });
  Future<void> deleteCategory(String communityId, String categoryId);
  Future<List<CommunityMember>> listMembers(String communityId);
  Future<void> setMemberRole(
    String communityId,
    String userId,
    CommunityRole role,
  );
  Future<Community> updateCommunity(
    Community community, {
    required String name,
    required String description,
    required CommunityVisibility visibility,
    required bool approvalRequired,
    String? imageUrl,
    String? imageBlobName,
  });
  Future<List<CommunityPost>> listPosts(
    String communityId, {
    String? categoryId,
    String? query,
    String? sort,
  });
  Future<List<CommunityPost>> listFollowingPosts({String? query});
  Future<CommunityPost> getPost(String postId);
  Future<SharedPostPreview> getSharedPost(String postId);
  Future<void> recordPostShare(String postId);
  Future<CommunityPost> createPost(String communityId, CreatePostInput input);
  Future<PostMedia> uploadPostMedia({
    required List<int> bytes,
    required String filename,
    required String mimeType,
  });
  Future<int> setPostReaction(String postId, {required bool reacted});
  Future<List<Comment>> listComments(String postId);
  Future<Comment> createComment(String postId, String text);
  Future<List<CommunityPost>> listMyPosts();
  Future<List<CommunityPost>> listSavedPosts();
  Future<void> setPostSaved(String postId, {required bool saved});
  Future<void> reportPost(String postId, String reason);
  Future<AdminAttentionSummary> getAdminAttention(String communityId);
  Future<List<CommunityReport>> listReports(String communityId);
  Future<void> decideReport(
    String communityId,
    String reportId, {
    required bool resolve,
  });
  Future<List<MembershipRequest>> listMembershipRequests(String communityId);
  Future<void> decideMembershipRequest(
    String communityId,
    String userId, {
    required bool approve,
  });
  Future<List<CommunityPost>> listPendingPosts(String communityId);
  Future<void> moderatePost(
    String communityId,
    String postId, {
    required bool approve,
    String? reason,
  });
}
