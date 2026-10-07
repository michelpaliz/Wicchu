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
    this.type = CommunityType.community,
    this.profileCategory,
  });

  final String name;
  final String description;
  final Town town;
  final CommunityVisibility visibility;
  final List<String> categoryNames;
  final bool approvalRequired;
  final List<CommunityRule> rules;
  final CommunityType type;
  final ProfileCategory? profileCategory;
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

class MemberGrowthPoint {
  const MemberGrowthPoint({required this.date, required this.members});

  final DateTime date;
  final int members;
}

class CommunityInsights {
  const CommunityInsights({
    this.totalMembers = 0,
    this.newMembers30d = 0,
    this.newMembersChangePercent,
    this.monthlyActiveUsers = 0,
    this.weeklyActiveUsers = 0,
    this.monthlyActivityRate = 0,
    this.posts30d = 0,
    this.comments30d = 0,
    this.reactions30d = 0,
    this.memberGrowth = const [],
    this.monetization = const CommunityMonetizationEligibility(),
  });

  final int totalMembers;
  final int newMembers30d;
  final double? newMembersChangePercent;
  final int monthlyActiveUsers;
  final int weeklyActiveUsers;
  final double monthlyActivityRate;
  final int posts30d;
  final int comments30d;
  final int reactions30d;
  final List<MemberGrowthPoint> memberGrowth;
  final CommunityMonetizationEligibility monetization;
}

class CommunityMonetizationEligibility {
  const CommunityMonetizationEligibility({
    this.eligible = false,
    this.memberTarget = 1000,
    this.monthlyActiveTarget = 250,
    this.membersRemaining = 1000,
    this.monthlyActiveRemaining = 250,
    this.goodStanding = true,
    this.restrictionReason,
  });

  final bool eligible;
  final int memberTarget;
  final int monthlyActiveTarget;
  final int membersRemaining;
  final int monthlyActiveRemaining;
  final bool goodStanding;
  final String? restrictionReason;
}

class CreatePostInput {
  const CreatePostInput({
    required this.categoryId,
    required this.text,
    this.media = const [],
    this.pollOptions = const [],
    this.mentionedUserIds = const [],
    this.anonymousAsAdmin = false,
    this.anonymousAsMember = false,
    this.todayMenu,
    this.businessFeature,
  });

  final String categoryId;
  final String text;
  final List<PostMedia> media;
  final List<String> pollOptions;
  final List<String> mentionedUserIds;
  final bool anonymousAsAdmin;
  final bool anonymousAsMember;
  final TodayMenu? todayMenu;
  final BusinessPostFeature? businessFeature;
}

abstract interface class CommunityRepository {
  Future<List<Town>> listTowns();
  Future<Town> locateTown({
    required double latitude,
    required double longitude,
  });
  Future<WicchuProfile> getProfile();
  Future<void> updateProfile({
    required String name,
    required String userName,
    required String bio,
    required String location,
  });
  Future<PublicMemberProfile> getMemberProfile(String userId);
  Future<PeopleSearchPage> searchPeople({
    String query = '',
    String? cursor,
    int limit = 25,
  });
  Future<List<BlockedUser>> listBlockedUsers();
  Future<void> blockUser(String userId);
  Future<void> unblockUser(String userId);
  Future<List<DirectConversation>> listDirectConversations();
  Future<List<DirectConversation>> listMessageRequests();
  Future<DirectConversation> startDirectConversation(String userId);
  Future<void> respondToMessageRequest(
    String conversationId, {
    required bool accept,
  });
  Future<DirectMessagePage> listDirectMessages(
    String conversationId, {
    String? before,
  });
  Future<void> markDirectConversationRead(String conversationId);
  Future<DirectMessage> sendDirectMessage(String conversationId, String body);
  Future<void> deleteDirectMessage(String messageId, {required bool everyone});
  Future<void> deleteDirectConversation(String conversationId);
  Future<MessagingPrivacy> getMessagingPrivacy();
  Future<MessagingPrivacy> updateMessagingPrivacy(MessagingPrivacy value);
  Future<void> reportDirectMessage(
    String messageId,
    String reason, {
    required String category,
  });
  Future<List<CommunityPost>> listMemberPosts(
    String userId, {
    String kind = 'all',
    String sort = 'newest',
  });
  Future<SocialLinks> getMySocialLinks();
  Future<SocialLinks> updateMySocialLinks(SocialLinks links);
  Future<EditableMemberProfile> getEditableProfile();
  Future<bool> isUsernameAvailable(String userName);
  Future<EditableMemberProfile> updateEditableProfile(
    EditableMemberProfile profile,
  );
  Future<NotificationFeed> listNotifications();
  Future<void> markNotificationRead(String notificationId);
  Future<void> markAllNotificationsRead();
  Future<NotificationPreferences> getNotificationPreferences();
  Future<NotificationPreferences> updateNotificationPreferences({
    bool? postActivity,
    bool? communityActivity,
    bool? promotions,
  });
  Future<void> registerDeviceToken(
    String token, {
    required String platform,
    String languageCode = 'en',
  });
  Future<void> unregisterDeviceToken(String token);
  Future<List<Community>> listCommunities({String? query});
  Future<Community> getCommunity(String communityId);
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
  Future<bool> getAdminAnonymity(String communityId);
  Future<bool> updateAdminAnonymity(
    String communityId, {
    required bool anonymousInCommunity,
  });
  Future<CommunityHelpfulness> getCommunityHelpfulness(String communityId);
  Future<CommunityHelpfulness> setCommunityHelpfulness(
    String communityId, {
    required bool helpful,
    String? locallyRelevant,
    String? safeParticipation,
    String? wellOrganized,
    bool? recommend,
  });
  Future<CommunityInvitation> createCommunityInvitation(
    String communityId,
    String email,
  );
  Future<CommunityInvitation> createCommunityInvitationLink(String communityId);
  Future<CommunityInvitation> getCommunityInvitationLink(String token);
  Future<void> respondToCommunityInvitationLink(
    String token, {
    required bool accept,
  });
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
  Future<void> createOwnershipTransfer(String communityId, String targetUserId);
  Future<void> stepDownCommunityRole(String communityId);
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
    String? icon,
  });
  Future<CommunityCategory> updateCategory(
    String communityId,
    CommunityCategory category, {
    required String name,
    required String description,
    String? icon,
  });
  Future<void> deleteCategory(String communityId, String categoryId);
  Future<List<CommunityMember>> listMembers(
    String communityId, {
    bool includeInactive = false,
  });
  Future<void> setMemberRole(
    String communityId,
    String userId,
    CommunityRole role,
  );
  Future<void> setMemberAccess(
    String communityId,
    String userId, {
    required String action,
    String? reason,
    String? internalNote,
    DateTime? expiresAt,
  });
  Future<Community> updateCommunity(
    Community community, {
    required Town town,
    required String name,
    required String description,
    required CommunityVisibility visibility,
    required bool approvalRequired,
    required bool showWeather,
    required List<CommunityLink> links,
    ProfileCategory? profileCategory,
    required List<BusinessService> businessServices,
    required BusinessLocation? businessLocation,
    List<BusinessHour>? businessHours,
    List<BusinessFulfillmentOption>? businessFulfillmentOptions,
    BusinessContact? businessContact,
    String? imageUrl,
    String? imageBlobName,
    String? coverImageUrl,
    String? coverImageBlobName,
  });
  Future<CommunityWeather?> getCommunityWeather(String communityId);
  Future<List<CommunityPost>> listPosts(
    String communityId, {
    String? categoryId,
    String? query,
    String? sort,
  });
  Future<List<CommunityPost>> listFollowingPosts({String? query});
  Future<List<CommunityPost>> listTodayMenus(String townId, {String? query});
  Future<List<CommunityPost>> listLocalBusinessPosts(
    String townId, {
    String? query,
  });
  Future<CommunityPost> getPost(String postId);
  Future<SharedPostPreview> getSharedPost(String postId);
  Future<PostShareKit> getPostShareKit(String postId);
  Future<void> recordPostShare(String postId);
  Future<void> recordBusinessPostEngagement(
    String postId, {
    required String action,
  });
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
  Future<void> reportPost(
    String postId,
    String reason, {
    String category = 'other',
    bool hidePost = false,
  });
  Future<void> reportComment(
    String commentId,
    String reason, {
    String category = 'other',
  });
  Future<void> reportMember(
    String userId,
    String reason, {
    String category = 'other',
  });
  Future<void> reportCommunity(
    String communityId,
    String reason, {
    String category = 'other',
  });
  Future<void> appealCommunityBan(String communityId, String reason);
  Future<void> contactWicchuSafety(
    String communityId,
    String reason, {
    required String issue,
  });
  Future<List<PlatformReport>> listPlatformReports({bool resolved = false});
  Future<void> decidePlatformReport(
    String reportId, {
    required String action,
    String? note,
  });
  Future<AdminAttentionSummary> getAdminAttention(String communityId);
  Future<CommunityInsights> getCommunityInsights(String communityId);
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
  Future<List<CommunityPost>> listRemovedPosts(String communityId);
  Future<void> restorePost(
    String communityId,
    String postId, {
    required String reason,
  });
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
