import 'community_models.dart';

class CreateCommunityInput {
  const CreateCommunityInput({
    required this.name,
    this.shortDescription = '',
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
  final String shortDescription;
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
    this.interactions30d = 0,
    this.uniqueContributors30d = 0,
    this.monthlyRetentionRate = 0,
    this.retentionDataAvailable = false,
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
  final int interactions30d;
  final int uniqueContributors30d;
  final double monthlyRetentionRate;
  final bool retentionDataAvailable;
  final List<MemberGrowthPoint> memberGrowth;
  final CommunityMonetizationEligibility monetization;
}

class CommunityMonetizationEligibility {
  const CommunityMonetizationEligibility({
    this.eligible = false,
    this.currency = 'EUR',
    this.reviewRequired = true,
    this.evaluationPeriodStart,
    this.evaluationPeriodEnd,
    this.daysRemaining = 0,
    this.payoutSetupComplete = false,
    this.availableBalanceCents = 0,
    this.minimumPayoutCents = 2500,
    this.enrollment = const CommunityRewardEnrollment(),
    this.currentTier,
    this.nextTier,
    this.tiers = const [],
    this.history = const [],
    this.goodStanding = true,
    this.restrictionReason,
  });

  final bool eligible;
  final String currency;
  final bool reviewRequired;
  final DateTime? evaluationPeriodStart;
  final DateTime? evaluationPeriodEnd;
  final int daysRemaining;
  final bool payoutSetupComplete;
  final int availableBalanceCents;
  final int minimumPayoutCents;
  final CommunityRewardEnrollment enrollment;
  final CommunityRewardTier? currentTier;
  final CommunityRewardTier? nextTier;
  final List<CommunityRewardTier> tiers;
  final List<CommunityRewardEvaluation> history;
  final bool goodStanding;
  final String? restrictionReason;
}

class CommunityRewardEnrollment {
  const CommunityRewardEnrollment({
    this.requested = false,
    this.status = 'not_requested',
    this.accepted = false,
    this.countryCode,
    this.countryName,
    this.contactEmail,
    this.currency,
    this.termsVersion,
    this.requestedAt,
    this.acceptedAt,
    this.reviewNote,
  });

  final bool requested;
  final String status;
  final bool accepted;
  final String? countryCode;
  final String? countryName;
  final String? contactEmail;
  final String? currency;
  final String? termsVersion;
  final DateTime? requestedAt;
  final DateTime? acceptedAt;
  final String? reviewNote;
}

class CommunityRewardRequest {
  const CommunityRewardRequest({
    required this.id,
    required this.communityId,
    required this.countryCode,
    required this.contactEmail,
    required this.requestedAt,
    this.countryName,
    this.note,
  });

  final String id;
  final String communityId;
  final String countryCode;
  final String? countryName;
  final String contactEmail;
  final String? note;
  final DateTime requestedAt;
}

class PlatformRewardPayout {
  const PlatformRewardPayout({
    required this.id,
    required this.communityName,
    required this.contactEmail,
    required this.periodStart,
    required this.rewardCents,
    required this.currency,
    required this.status,
    this.availableBalanceCents = 0,
    this.minimumPayoutCents = 2500,
    this.attributedJoins = 0,
    this.attributedNewUsers = 0,
    this.attributedActive7d = 0,
    this.attributedActive30d = 0,
    this.reviewNote,
  });

  final String id;
  final String communityName;
  final String contactEmail;
  final DateTime periodStart;
  final int rewardCents;
  final String currency;
  final String status;
  final int availableBalanceCents;
  final int minimumPayoutCents;
  final int attributedJoins;
  final int attributedNewUsers;
  final int attributedActive7d;
  final int attributedActive30d;
  final String? reviewNote;
}

class PlatformAnalytics {
  const PlatformAnalytics({
    this.registeredUsers = 0,
    this.newRegistrations = 0,
    this.dailyActiveUsers = 0,
    this.weeklyActiveUsers = 0,
    this.monthlyActiveUsers = 0,
    this.monthlyRetentionPercent,
    this.activeCommunities = 0,
    this.participatingCommunities = 0,
    this.pendingReviews = 0,
    this.registrationsByLocation = const [],
    this.currencySummary = const [],
    this.communityPerformance = const [],
  });

  final int registeredUsers;
  final int newRegistrations;
  final int dailyActiveUsers;
  final int weeklyActiveUsers;
  final int monthlyActiveUsers;
  final double? monthlyRetentionPercent;
  final int activeCommunities;
  final int participatingCommunities;
  final int pendingReviews;
  final List<PlatformLocationRegistration> registrationsByLocation;
  final List<PlatformCurrencySummary> currencySummary;
  final List<PlatformCommunityPerformance> communityPerformance;
}

class PlatformLocationRegistration {
  const PlatformLocationRegistration({required this.location, this.users = 0});

  final String location;
  final int users;
}

class PlatformCurrencySummary {
  const PlatformCurrencySummary({
    required this.currency,
    this.pendingCents = 0,
    this.approvedCents = 0,
    this.paidCents = 0,
    this.remainingBudgetCents = 0,
  });
  final String currency;
  final int pendingCents;
  final int approvedCents;
  final int paidCents;
  final int remainingBudgetCents;
}

class PlatformCommunityPerformance {
  const PlatformCommunityPerformance({
    required this.name,
    required this.currency,
    this.members = 0,
    this.monthlyActive = 0,
    this.posts = 0,
    this.interactions = 0,
    this.contributors = 0,
    this.newUsers = 0,
    this.activeAfter7Days = 0,
    this.activeAfter30Days = 0,
  });
  final String name;
  final String currency;
  final int members;
  final int monthlyActive;
  final int posts;
  final int interactions;
  final int contributors;
  final int newUsers;
  final int activeAfter7Days;
  final int activeAfter30Days;
}

class CommunityRewardEvaluation {
  const CommunityRewardEvaluation({
    required this.id,
    required this.periodStart,
    required this.periodEnd,
    required this.members,
    required this.monthlyActive,
    required this.posts,
    required this.interactions,
    this.uniqueContributors = 0,
    required this.retentionPercent,
    required this.rewardCents,
    required this.currency,
    required this.status,
    this.tierId,
    this.reviewNote,
    this.paidAt,
  });

  final String id;
  final DateTime periodStart;
  final DateTime periodEnd;
  final int members;
  final int monthlyActive;
  final int posts;
  final int interactions;
  final int uniqueContributors;
  final double retentionPercent;
  final String? tierId;
  final int rewardCents;
  final String currency;
  final String status;
  final String? reviewNote;
  final DateTime? paidAt;
}

class CommunityRewardTier {
  const CommunityRewardTier({
    required this.id,
    required this.monthlyRewardCents,
    required this.memberTarget,
    required this.monthlyActiveTarget,
    required this.postsTarget,
    required this.interactionsTarget,
    this.contributorsTarget = 0,
    required this.retentionTargetPercent,
    required this.qualified,
  });

  final String id;
  final int monthlyRewardCents;
  final int memberTarget;
  final int monthlyActiveTarget;
  final int postsTarget;
  final int interactionsTarget;
  final int contributorsTarget;
  final double retentionTargetPercent;
  final bool qualified;
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
    this.importantAnnouncement = false,
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
  final bool importantAnnouncement;
}

class BusinessProductInput {
  const BusinessProductInput({
    required this.categoryId,
    required this.name,
    required this.priceCents,
    this.kind = BusinessProductKind.product,
    this.description = '',
    this.image,
    this.available = true,
    this.quantityAvailable,
    this.variants = const [],
    this.expiresAt,
    this.position = 0,
  });

  final String categoryId;
  final String name;
  final int priceCents;
  final BusinessProductKind kind;
  final String description;
  final PostMedia? image;
  final bool available;
  final int? quantityAvailable;
  final List<BusinessProductVariantInput> variants;
  final DateTime? expiresAt;
  final int position;
}

class BusinessProductVariantInput {
  const BusinessProductVariantInput({
    this.id,
    required this.name,
    this.sku = '',
    this.priceCents,
    this.available = true,
    this.quantityAvailable,
    this.attributes = const {},
  });

  final String? id;
  final String name;
  final String sku;
  final int? priceCents;
  final bool available;
  final int? quantityAvailable;
  final Map<String, String> attributes;
}

class BusinessOrderLineInput {
  const BusinessOrderLineInput({
    required this.productId,
    required this.quantity,
    this.variantId,
  });

  final String productId;
  final String? variantId;
  final int quantity;
}

class BusinessOrderInput {
  const BusinessOrderInput({
    required this.fulfillmentMethod,
    this.quantities = const {},
    this.lines = const [],
    this.deliveryAddress = '',
    this.customerPhone = '',
    this.notes = '',
  });

  final BusinessFulfillmentOption fulfillmentMethod;
  final Map<String, int> quantities;
  final List<BusinessOrderLineInput> lines;
  final String deliveryAddress;
  final String customerPhone;
  final String notes;
}

class BusinessRequestInput {
  const BusinessRequestInput({
    required this.type,
    required this.serviceName,
    this.description = '',
    this.contactPhone = '',
    this.location = '',
    this.destination = '',
    this.preferredAt,
    this.attachmentBlobNames = const [],
  });

  final BusinessRequestType type;
  final String serviceName;
  final String description;
  final String contactPhone;
  final String location;
  final String destination;
  final DateTime? preferredAt;
  final List<String> attachmentBlobNames;
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
  Future<UserFollowActionResult> followUser(String userId);
  Future<UserFollowActionResult> unfollowUser(String userId);
  Future<UserFollowPage> listFollowRequests({String? cursor});
  Future<void> respondToFollowRequest(String userId, {required bool accept});
  Future<UserFollowPage> listFollowers(String userId, {String? cursor});
  Future<UserFollowPage> listFollowingUsers(String userId, {String? cursor});
  Future<PeopleSearchPage> searchPeople({
    String query = '',
    String? cursor,
    int limit = 25,
    String? townId,
    double? latitude,
    double? longitude,
    double radiusKm = 10,
  });
  Future<List<BlockedUser>> listBlockedUsers();
  Future<void> blockUser(String userId);
  Future<void> unblockUser(String userId);
  Future<List<DirectConversation>> listDirectConversations({String? pageId});
  Future<List<DirectConversation>> listMessageRequests({String? pageId});
  Future<DirectConversation> startDirectConversation(String userId);
  Future<DirectConversation> startPageConversation(String pageId);
  Future<void> updateDirectConversationLabel(
    String conversationId,
    ConversationLabel label,
  );
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
  Future<CategoryActivity> getCategoryActivity(String communityId);
  Future<void> markCommunityPostsSeen(String communityId, List<String> postIds);
  Future<ScopedNotificationPreferences>
  getCommunityContentNotificationPreferences(String communityId);
  Future<ScopedNotificationPreferences>
  updateCommunityContentNotificationPreferences(
    String communityId,
    ScopedNotificationPreferences preferences,
  );
  Future<ScopedNotificationPreferences> getPersonContentNotificationPreferences(
    String userId,
  );
  Future<ScopedNotificationPreferences>
  updatePersonContentNotificationPreferences(
    String userId,
    ScopedNotificationPreferences preferences,
  );
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
  Future<List<Community>> listLocalBusinesses({String? townId, String? query});
  Future<List<Community>> listNearbyBusinesses({
    required double latitude,
    required double longitude,
    double radiusKm = 10,
    String? query,
  });
  Future<List<CommunityPost>> listBusinessPosts(
    List<String> businessIds, {
    String? query,
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
  Future<BusinessCatalog> getBusinessCatalog(
    String businessId, {
    bool manage = false,
  });
  Future<void> setBusinessAcceptingOrders(
    String businessId, {
    required bool accepting,
  });
  Future<BusinessCatalogCategory> createBusinessCatalogCategory(
    String businessId,
    String name,
  );
  Future<void> deleteBusinessCatalogCategory(
    String businessId,
    String categoryId,
  );
  Future<BusinessProduct> createBusinessProduct(
    String businessId,
    BusinessProductInput input,
  );
  Future<BusinessProduct> updateBusinessProduct(
    String businessId,
    String productId,
    BusinessProductInput input,
  );
  Future<void> deleteBusinessProduct(String businessId, String productId);
  Future<BusinessOrder> createBusinessOrder(
    String businessId,
    BusinessOrderInput input,
  );
  Future<List<BusinessOrder>> listMyBusinessOrders();
  Future<List<BusinessOrder>> listManagedBusinessOrders(String businessId);
  Future<BusinessOrder> updateBusinessOrderStatus(
    String orderId,
    BusinessOrderStatus status, {
    String reason = '',
  });
  Future<BusinessOrder> cancelBusinessOrder(String orderId);
  Future<BusinessRequestSettings> getBusinessRequestSettings(String businessId);
  Future<BusinessRequestSettings> updateBusinessRequestSettings(
    String businessId, {
    required bool acceptingRequests,
    required List<BusinessRequestType> capabilities,
  });
  Future<BusinessRequest> createBusinessRequest(
    String businessId,
    BusinessRequestInput input,
  );
  Future<List<BusinessRequest>> listMyBusinessRequests();
  Future<List<BusinessRequest>> listManagedBusinessRequests(String businessId);
  Future<BusinessRequest> updateBusinessRequestStatus(
    String requestId,
    BusinessRequestStatus status, {
    String message = '',
    DateTime? scheduledAt,
    int? quotedPriceCents,
  });
  Future<BusinessRequest> cancelBusinessRequest(String requestId);
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
  Future<void> createAdminInvitation(String communityId, String targetUserId);
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
  Future<List<String>> getCategoryOrder(String communityId);
  Future<List<String>> updateCategoryOrder(
    String communityId,
    List<String> order,
  );
  Future<List<String>> resetCategoryOrder(String communityId);
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
  Future<void> setPageInboxAccess(
    String communityId,
    String userId, {
    required bool enabled,
  });
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
    String? shortDescription,
    required String description,
    required CommunityVisibility visibility,
    required bool approvalRequired,
    bool? membersListVisible,
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
    bool? published,
    String? accentColor,
    bool? neonBordersEnabled,
    NeonBorderAnimation? neonBorderAnimation,
    double? neonAnimationDurationSeconds,
    bool? headerBorderEnabled,
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
  Future<CommunityPost> createPersonalPost(CreatePostInput input);
  Future<List<CommunityShareResult>> sharePersonalPostToCommunities(
    String postId, {
    required Map<String, String> categoryByCommunity,
    String caption = '',
  });
  Future<CommunityPost> updatePost(String postId, CreatePostInput input);
  Future<void> deletePost(String postId);
  Future<void> setPostPinned(String postId, {required bool pinned});
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
  Future<void> setPostHidden(String postId, {required bool hidden});
  Future<void> reportPost(
    String postId,
    String reason, {
    String category = 'other',
    bool hidePost = false,
    String? communityId,
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
  Future<List<CommunityRewardRequest>> listCommunityRewardRequests();
  Future<void> reviewCommunityRewardRequest(
    String requestId, {
    required bool approve,
    String currency = 'USD',
    String? note,
  });
  Future<List<PlatformRewardPayout>> listPlatformRewardPayouts({
    bool completed = false,
  });
  Future<void> reviewPlatformRewardPayout(
    String payoutId, {
    required String action,
    String? note,
  });
  Future<PlatformAnalytics> getPlatformAnalytics();
  Future<AdminAttentionSummary> getAdminAttention(String communityId);
  Future<CommunityInsights> getCommunityInsights(String communityId);
  Future<CommunityRewardEnrollment> acceptCommunityRewardTerms(
    String communityId, {
    required String countryCode,
  });
  Future<CommunityRewardEnrollment> requestCommunityRewards(
    String communityId, {
    required String countryCode,
    String? countryName,
    required String contactEmail,
    String? note,
  });
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
  Future<void> removePost(
    String communityId,
    String postId, {
    required String reason,
  });
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
