import 'community_models.dart';

class CreateCommunityInput {
  const CreateCommunityInput({
    required this.name,
    required this.description,
    required this.town,
    required this.visibility,
    required this.categoryNames,
    this.approvalRequired = false,
    this.rules = const [],
  });

  final String name;
  final String description;
  final Town town;
  final CommunityVisibility visibility;
  final List<String> categoryNames;
  final bool approvalRequired;
  final List<CommunityRule> rules;
}

class AdminAttentionSummary {
  const AdminAttentionSummary({
    this.pendingPosts = 0,
    this.openReports = 0,
    this.membershipRequests = 0,
    this.pendingPromotions = 0,
  });

  final int pendingPosts;
  final int openReports;
  final int membershipRequests;
  final int pendingPromotions;
}

class CreatePostInput {
  const CreatePostInput({
    required this.categoryId,
    required this.text,
    this.media = const [],
    this.pollOptions = const [],
  });

  final String categoryId;
  final String text;
  final List<PostMedia> media;
  final List<String> pollOptions;
}

abstract interface class CommunityRepository {
  Future<List<Town>> listTowns();
  Future<Town> locateTown({
    required double latitude,
    required double longitude,
  });
  Future<WicchuProfile> getProfile();
  Future<PublicMemberProfile> getMemberProfile(String userId);
  Future<List<CommunityPost>> listMemberPosts(
    String userId, {
    String kind = 'all',
    String sort = 'newest',
  });
  Future<SocialLinks> getMySocialLinks();
  Future<SocialLinks> updateMySocialLinks(SocialLinks links);
  Future<NotificationFeed> listNotifications();
  Future<void> markNotificationRead(String notificationId);
  Future<void> markAllNotificationsRead();
  Future<NotificationPreferences> getNotificationPreferences();
  Future<NotificationPreferences> updateNotificationPreferences({
    bool? postActivity,
    bool? communityActivity,
    bool? promotions,
  });
  Future<void> registerDeviceToken(String token, {required String platform});
  Future<void> unregisterDeviceToken(String token);
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
  Future<CommunityInvitation> createCommunityInvitation(
    String communityId,
    String email,
  );
  Future<List<CommunityInvitation>> listCommunityInvitations(
    String communityId,
  );
  Future<List<CommunityInvitation>> listMyCommunityInvitations();
  Future<void> respondToCommunityInvitation(
    String invitationId, {
    required bool accept,
  });
  Future<void> revokeCommunityInvitation(
    String communityId,
    String invitationId,
  );
  Future<CommunityRules> listRules(String communityId);
  Future<CommunityRule> createRule(
    String communityId, {
    required String title,
    required String description,
    required int position,
  });
  Future<CommunityRule> updateRule(
    String communityId,
    CommunityRule rule, {
    String? title,
    String? description,
    int? position,
  });
  Future<void> deleteRule(String communityId, String ruleId);
  Future<void> acceptRules(String communityId, int rulesVersion);
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
  Future<CommunityPost> updatePost(String postId, CreatePostInput input);
  Future<void> deletePost(String postId);
  Future<PostMedia> uploadPostMedia({
    required List<int> bytes,
    required String filename,
    required String mimeType,
  });
  Future<int> setPostReaction(String postId, {required bool reacted});
  Future<PostPoll> voteOnPost(String postId, String optionId);
  Future<List<Comment>> listComments(String postId);
  Future<Comment> createComment(
    String postId,
    String text, {
    String? parentCommentId,
  });
  Future<int> setCommentReaction(String commentId, {required bool reacted});
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
  Future<PromotionEligibility> getPromotionEligibility();
  Future<List<PromotionCampaign>> listMyPromotions();
  Future<PromotionCampaign> createPromotion(
    String postId, {
    required int durationDays,
  });
  Future<void> cancelPromotion(String promotionId);
  Future<void> recordPromotionImpression(String promotionId);
  Future<void> recordPromotionClick(String promotionId);
  Future<List<PromotionCampaign>> listPendingPromotions(String communityId);
  Future<void> reviewPromotion(
    String communityId,
    String promotionId, {
    required bool approve,
    String? reason,
  });
}
