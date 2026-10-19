enum CommunityVisibility { public, private }

enum CommunityRole { owner, admin, moderator, member }

enum MembershipStatus { active, pending, banned }

enum CommunityType { community, publicProfile }

enum CommunityScope { local, global }

enum NeonBorderAnimation { staticGlow, snake, breathing, aurora }

extension NeonBorderAnimationApi on NeonBorderAnimation {
  String get apiValue => switch (this) {
    NeonBorderAnimation.staticGlow => 'static',
    NeonBorderAnimation.snake => 'snake',
    NeonBorderAnimation.breathing => 'breathing',
    NeonBorderAnimation.aurora => 'aurora',
  };
}

NeonBorderAnimation neonBorderAnimationFromApi(Object? value) =>
    switch (value?.toString()) {
      'snake' => NeonBorderAnimation.snake,
      'breathing' => NeonBorderAnimation.breathing,
      'aurora' => NeonBorderAnimation.aurora,
      _ => NeonBorderAnimation.staticGlow,
    };

enum ProfileCategory {
  localBusiness('local_business', 'Local business'),
  person('person', 'Person'),
  creator('creator', 'Creator'),
  organization('organization', 'Organization');

  const ProfileCategory(this.apiValue, this.label);
  final String apiValue;
  final String label;

  static ProfileCategory? fromApi(Object? value) {
    for (final category in values) {
      if (category.apiValue == value) return category;
    }
    return null;
  }
}

const maxBusinessServices = 10;

enum BusinessService {
  gardening('gardening', 'Gardening'),
  pools('pools', 'Pools'),
  concierge('concierge', 'Concierge'),
  cleaning('cleaning', 'Cleaning'),
  maintenance('maintenance', 'Maintenance'),
  construction('construction', 'Construction'),
  food('food', 'Food'),
  retail('retail', 'Retail'),
  health('health', 'Health'),
  beauty('beauty', 'Beauty'),
  transport('transport', 'Transport'),
  education('education', 'Education'),
  professionalServices('professional_services', 'Professional services'),
  realEstate('real_estate', 'Real estate'),
  other('other', 'Other');

  const BusinessService(this.apiValue, this.label);
  final String apiValue;
  final String label;

  static BusinessService? fromApi(Object? value) {
    for (final service in values) {
      if (service.apiValue == value) return service;
    }
    return null;
  }
}

enum PostStatus { published, pendingApproval, removed }

enum ReportStatus { open, reviewing, resolved, dismissed }

enum ModerationTargetType { post, comment, member }

enum CommunityNotificationType {
  userFollow,
  postReaction,
  commentReaction,
  postComment,
  commentReply,
  postMention,
  newPost,
  newPersonalPost,
  todayMenu,
  businessOrder,
  businessRequest,
  postApproved,
  postRejected,
  postRemoved,
  postRestored,
  commentApproved,
  commentRejected,
  commentRemoved,
  memberRemoved,
  memberBanned,
  memberUnbanned,
  membershipApproved,
  membershipRejected,
  promotionApproved,
  promotionRejected,
  membershipRequest,
  postPending,
  commentPending,
  reportCreated,
  communityInvitation,
  communityRoleChanged,
  rewardRequest,
  rewardRequestApproved,
  rewardRequestRejected,
  rewardPayoutApproved,
  rewardPayoutRejected,
  rewardPayoutPaid,
}

class NotificationPreferences {
  const NotificationPreferences({
    this.postActivity = true,
    this.communityActivity = true,
    this.promotions = true,
  });

  final bool postActivity;
  final bool communityActivity;
  final bool promotions;
}

enum ContentNotificationMode { important, all, selected, muted }

class ScopedNotificationPreferences {
  const ScopedNotificationPreferences.communityDefaults()
    : this(mode: ContentNotificationMode.all);

  const ScopedNotificationPreferences({
    this.mode = ContentNotificationMode.important,
    this.selectedCategoryIds = const [],
    this.contentTypes = const ['posts'],
    this.pushEnabled = true,
  });

  final ContentNotificationMode mode;
  final List<String> selectedCategoryIds;
  final List<String> contentTypes;
  final bool pushEnabled;

  ScopedNotificationPreferences copyWith({
    ContentNotificationMode? mode,
    List<String>? selectedCategoryIds,
    List<String>? contentTypes,
    bool? pushEnabled,
  }) => ScopedNotificationPreferences(
    mode: mode ?? this.mode,
    selectedCategoryIds: selectedCategoryIds ?? this.selectedCategoryIds,
    contentTypes: contentTypes ?? this.contentTypes,
    pushEnabled: pushEnabled ?? this.pushEnabled,
  );
}

class CategoryActivity {
  const CategoryActivity({
    this.totalUnreadCount = 0,
    this.unreadByCategory = const {},
  });

  final int totalUnreadCount;
  final Map<String, int> unreadByCategory;
}

class WicchuUser {
  const WicchuUser({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.location,
  });

  final String id;
  final String name;
  final String? avatarUrl;
  final String? location;
}

class WicchuProfile {
  const WicchuProfile({
    required this.id,
    required this.name,
    required this.userName,
    required this.communityCount,
    required this.postCount,
    required this.savedPostCount,
    this.avatarUrl,
    this.location,
    this.platformModerator = false,
  });

  final String id;
  final String name;
  final String userName;
  final String? avatarUrl;
  final String? location;
  final int communityCount;
  final int postCount;
  final int savedPostCount;
  final bool platformModerator;
}

class PublicMemberProfile {
  const PublicMemberProfile({
    required this.id,
    required this.name,
    required this.userName,
    required this.postCount,
    required this.communityCount,
    this.avatarUrl,
    this.coverImageUrl,
    this.shortDescription = '',
    this.bio,
    this.location,
    this.followerCount,
    this.followingCount,
    this.followedByMe = false,
    this.followStatus = UserFollowStatus.none,
    this.isPrivate = false,
    this.canViewPersonalPosts = true,
    this.followRequestCount = 0,
    this.socialLinks = const SocialLinks(),
    this.isOnline = false,
    this.lastActiveAt,
    this.accentColor = 'teal',
    this.neonBordersEnabled = false,
    this.neonBorderAnimation = NeonBorderAnimation.staticGlow,
    this.neonAnimationDurationSeconds = 5,
  });
  final String id;
  final String name;
  final String userName;
  final String? avatarUrl;
  final String? coverImageUrl;
  final String shortDescription;
  final String? bio;
  final String? location;
  final int? followerCount;
  final int? followingCount;
  final bool followedByMe;
  final UserFollowStatus followStatus;
  final bool isPrivate;
  final bool canViewPersonalPosts;
  final int followRequestCount;
  final int postCount;
  final int communityCount;
  final SocialLinks socialLinks;
  final bool isOnline;
  final DateTime? lastActiveAt;
  final String accentColor;
  final bool neonBordersEnabled;
  final NeonBorderAnimation neonBorderAnimation;
  final double neonAnimationDurationSeconds;
}

enum UserFollowStatus { none, pending, accepted }

class UserFollowActionResult {
  const UserFollowActionResult({
    required this.status,
    required this.followerCount,
  });
  final UserFollowStatus status;
  final int followerCount;
}

class UserFollowProfile {
  const UserFollowProfile({
    required this.id,
    required this.name,
    required this.userName,
    this.avatarUrl,
  });
  final String id;
  final String name;
  final String userName;
  final String? avatarUrl;
}

class UserFollowPage {
  const UserFollowPage({required this.users, this.nextCursor});
  final List<UserFollowProfile> users;
  final String? nextCursor;
}

class CommunityShareResult {
  const CommunityShareResult({
    required this.communityId,
    required this.status,
    this.message = '',
  });
  final String communityId;
  final String status;
  final String message;
  bool get succeeded => status == 'published' || status == 'pending_approval';
}

class PeopleSearchResult {
  const PeopleSearchResult({
    required this.id,
    required this.name,
    required this.userName,
    required this.sharedCommunityCount,
    this.avatarUrl,
    this.distanceKm,
  });

  final String id;
  final String name;
  final String userName;
  final String? avatarUrl;
  final int sharedCommunityCount;
  final double? distanceKm;
}

class PeopleSearchPage {
  const PeopleSearchPage({required this.people, this.nextCursor});

  final List<PeopleSearchResult> people;
  final String? nextCursor;
}

class SocialLinks {
  const SocialLinks({
    this.whatsapp = '',
    this.facebook = '',
    this.instagram = '',
    this.email = '',
    this.showOnlineStatus = true,
  });
  final String whatsapp;
  final String facebook;
  final String instagram;
  final String email;
  final bool showOnlineStatus;
  bool get isEmpty =>
      whatsapp.isEmpty &&
      facebook.isEmpty &&
      instagram.isEmpty &&
      email.isEmpty;
}

class EditableMemberProfile {
  const EditableMemberProfile({
    required this.name,
    required this.userName,
    this.shortDescription = '',
    this.bio = '',
    this.location = '',
    this.socialLinks = const SocialLinks(),
    this.accentColor = 'teal',
    this.neonBordersEnabled = false,
    this.neonBorderAnimation = NeonBorderAnimation.staticGlow,
    this.neonAnimationDurationSeconds = 5,
    this.isPrivate = false,
  });

  final String name;
  final String userName;
  final String shortDescription;
  final String bio;
  final String location;
  final SocialLinks socialLinks;
  final String accentColor;
  final bool neonBordersEnabled;
  final NeonBorderAnimation neonBorderAnimation;
  final double neonAnimationDurationSeconds;
  final bool isPrivate;
}

class CommunityNotification {
  const CommunityNotification({
    required this.id,
    required this.actorName,
    required this.type,
    required this.postId,
    required this.message,
    required this.createdAt,
    required this.isRead,
    this.actorAvatarUrl,
    this.communityId = '',
    this.promotionId = '',
    this.orderId = '',
    this.requestId = '',
  });

  final String id;
  final String actorName;
  final String? actorAvatarUrl;
  final CommunityNotificationType type;
  final String postId;
  final String message;
  final DateTime createdAt;
  final bool isRead;
  final String communityId;
  final String promotionId;
  final String orderId;
  final String requestId;
}

class NotificationFeed {
  const NotificationFeed({required this.items, required this.unreadCount});

  final List<CommunityNotification> items;
  final int unreadCount;
}

class Town {
  const Town({required this.id, required this.name, required this.countryCode});

  final String id;
  final String name;
  final String countryCode;
}

class Community {
  const Community({
    required this.id,
    required this.name,
    this.slug = '',
    this.shortDescription = '',
    required this.description,
    required this.town,
    required this.visibility,
    required this.createdBy,
    required this.createdAt,
    this.imageUrl,
    this.coverImageUrl,
    this.memberCount = 0,
    this.myRole,
    this.approvalRequired = false,
    this.membersListVisible = true,
    this.showWeather = false,
    this.distanceKm,
    this.rules = const [],
    this.links = const [],
    this.type = CommunityType.community,
    this.scope = CommunityScope.local,
    this.profileCategory,
    this.businessServices = const [],
    this.businessLocation,
    this.businessHours = const [],
    this.businessFulfillmentOptions = const [],
    this.businessContact = const BusinessContact(),
    this.businessAcceptingOrders = false,
    this.businessAcceptingRequests = false,
    this.businessRequestCapabilities = const [],
    this.membershipStatus,
    this.banPublicReason,
    this.banExpiresAt,
    this.canManagePageInbox = false,
    this.canManagePageOrders = false,
    this.canManagePageServices = false,
    this.canViewPageAnalytics = false,
    this.canManageLocalNews = false,
    this.published = true,
    this.accentColor = 'teal',
    this.neonBordersEnabled = false,
    this.neonBorderAnimation = NeonBorderAnimation.staticGlow,
    this.neonAnimationDurationSeconds = 5,
    this.headerBorderEnabled = false,
  });

  final String id;
  final String name;
  final String slug;
  final String shortDescription;
  final String description;
  final Town town;
  final String? imageUrl;
  final String? coverImageUrl;
  final CommunityVisibility visibility;
  final String createdBy;
  final DateTime createdAt;
  final int memberCount;
  final CommunityRole? myRole;
  final bool approvalRequired;
  final bool membersListVisible;
  final bool showWeather;
  final double? distanceKm;
  final List<CommunityRule> rules;
  final List<CommunityLink> links;
  final CommunityType type;
  final CommunityScope scope;
  final ProfileCategory? profileCategory;
  final List<BusinessService> businessServices;
  final List<BusinessHour> businessHours;
  final List<BusinessFulfillmentOption> businessFulfillmentOptions;
  final BusinessContact businessContact;
  final bool businessAcceptingOrders;
  final bool businessAcceptingRequests;
  final List<BusinessRequestType> businessRequestCapabilities;

  String get spaceTypeLabel => isPublicProfile
      ? profileCategory?.label ?? 'Public profile'
      : 'Community';
  bool get isGlobal => scope == CommunityScope.global;
  final BusinessLocation? businessLocation;
  final MembershipStatus? membershipStatus;
  final String? banPublicReason;
  final DateTime? banExpiresAt;
  final bool canManagePageInbox;
  final bool canManagePageOrders;
  final bool canManagePageServices;
  final bool canViewPageAnalytics;

  /// Server-computed: the current user may manage Local News for this community.
  final bool canManageLocalNews;
  final bool published;
  final String accentColor;
  final bool neonBordersEnabled;
  final NeonBorderAnimation neonBorderAnimation;
  final double neonAnimationDurationSeconds;
  final bool headerBorderEnabled;

  bool get isJoined => myRole != null;
  bool get isBanned => membershipStatus == MembershipStatus.banned;

  String get profileSummary => shortDescription.trim();

  bool get canPublish =>
      isJoined &&
      (!isPublicProfile ||
          myRole == CommunityRole.owner ||
          myRole == CommunityRole.admin);
  bool get isPublicProfile => type == CommunityType.publicProfile;
  int get followerCount => memberCount;

  String roleLabel(CommunityRole role) => switch ((isPublicProfile, role)) {
    (true, CommunityRole.owner) => 'Page owner',
    (true, CommunityRole.admin) => 'Page administrator',
    (true, CommunityRole.moderator) => 'Page moderator',
    (true, CommunityRole.member) => 'Follower',
    (false, CommunityRole.owner) => 'Community owner',
    (false, CommunityRole.admin) => 'Community administrator',
    (false, CommunityRole.moderator) => 'Community moderator',
    (false, CommunityRole.member) => 'Member',
  };
}

class BusinessLocation {
  const BusinessLocation({
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.showExactAddress,
  });

  final String address;
  final double? latitude;
  final double? longitude;
  final bool showExactAddress;
  bool get hasCoordinates => latitude != null && longitude != null;
}

class BusinessHour {
  const BusinessHour({
    required this.day,
    this.open = '',
    this.close = '',
    this.closed = false,
  });

  final String day;
  final String open;
  final String close;
  final bool closed;
}

class BusinessContact {
  const BusinessContact({this.phone = '', this.whatsapp = ''});

  final String phone;
  final String whatsapp;
}

class CommunityLink {
  const CommunityLink({required this.label, required this.url});
  final String label;
  final String url;
}

class CommunityWeather {
  const CommunityWeather({
    required this.townName,
    required this.temperature,
    required this.apparentTemperature,
    required this.minTemperature,
    required this.maxTemperature,
    required this.weatherCode,
    required this.description,
    required this.isDay,
    required this.observedAt,
    required this.provider,
  });

  final String townName;
  final double temperature;
  final double apparentTemperature;
  final double minTemperature;
  final double maxTemperature;
  final int weatherCode;
  final String description;
  final bool isDay;
  final DateTime? observedAt;
  final String provider;
}

class CommunityInvitation {
  const CommunityInvitation({
    required this.id,
    required this.communityId,
    this.type = 'email',
    this.email,
    required this.status,
    required this.expiresAt,
    required this.createdAt,
    this.communityName,
    this.communityImageUrl,
    this.communityType = CommunityType.community,
    this.invitationUrl,
    this.invitedUserName,
    this.invitedUserAvatarUrl,
  });

  final String id;
  final String communityId;
  final String type;
  final String? email;
  final String status;
  final DateTime expiresAt;
  final DateTime createdAt;
  final String? communityName;
  final String? communityImageUrl;
  final CommunityType communityType;
  final String? invitationUrl;
  final String? invitedUserName;
  final String? invitedUserAvatarUrl;

  bool get isLink => type == 'link';
  bool get isAdminInvitation => type == 'admin_invitation';
  bool get isOwnershipTransfer => type == 'ownership_transfer';
  bool get isPublicProfile => communityType == CommunityType.publicProfile;
}

class CommunityAuditEntry {
  const CommunityAuditEntry({
    required this.id,
    required this.action,
    required this.createdAt,
    this.actorName = 'Wicchu administrator',
    this.targetName,
    this.reason = '',
    this.details = const {},
  });

  final String id;
  final String action;
  final DateTime createdAt;
  final String actorName;
  final String? targetName;
  final String reason;
  final Map<String, dynamic> details;
}

class CommunityHelpfulness {
  const CommunityHelpfulness({
    required this.responseCount,
    required this.minimumResponses,
    required this.isPublic,
    required this.eligible,
    this.helpfulPercentage,
    this.myVote,
    this.insights = const {},
  });

  final int responseCount;
  final int minimumResponses;
  final int? helpfulPercentage;
  final bool isPublic;
  final bool eligible;
  final CommunitySurveyResponse? myVote;
  final Map<String, CommunityFeedbackInsight> insights;
}

class CommunitySurveyResponse {
  const CommunitySurveyResponse({
    required this.helpful,
    this.locallyRelevant,
    this.safeParticipation,
    this.wellOrganized,
    this.recommend,
  });
  final bool helpful;
  final String? locallyRelevant;
  final String? safeParticipation;
  final String? wellOrganized;
  final bool? recommend;
}

class CommunityFeedbackInsight {
  const CommunityFeedbackInsight({required this.total, this.yesPercentage});
  final int total;
  final int? yesPercentage;
}

class CommunityRule {
  const CommunityRule({
    this.id = '',
    required this.title,
    required this.description,
    this.position = 0,
  });

  final String id;
  final String title;
  final String description;
  final int position;
}

class CommunityRules {
  const CommunityRules({
    required this.rules,
    required this.rulesVersion,
    required this.acceptedRulesVersion,
    required this.acceptanceRequired,
    required this.canManage,
  });

  final List<CommunityRule> rules;
  final int rulesVersion;
  final int acceptedRulesVersion;
  final bool acceptanceRequired;
  final bool canManage;
}

class CommunityMember {
  const CommunityMember({
    required this.userId,
    required this.communityId,
    required this.role,
    required this.status,
    required this.joinedAt,
    this.name = 'Wicchu member',
    this.avatarUrl,
    this.isOnline = false,
    this.lastActiveAt,
    this.isAnonymous = false,
    this.banPublicReason,
    this.banInternalNote,
    this.bannedAt,
    this.banExpiresAt,
    this.pageInboxAccess = false,
    this.canManageOrders = false,
    this.canManageServices = false,
    this.canViewPageAnalytics = false,
  });

  final String userId;
  final String communityId;
  final CommunityRole role;
  final MembershipStatus status;
  final DateTime joinedAt;
  final String name;
  final String? avatarUrl;
  final bool isOnline;
  final DateTime? lastActiveAt;
  final bool isAnonymous;
  final String? banPublicReason;
  final String? banInternalNote;
  final DateTime? bannedAt;
  final DateTime? banExpiresAt;
  final bool pageInboxAccess;
  final bool canManageOrders;
  final bool canManageServices;
  final bool canViewPageAnalytics;
}

class CommunityCategory {
  const CommunityCategory({
    required this.id,
    required this.communityId,
    required this.name,
    required this.icon,
    this.description = '',
    this.rules = const [],
  });

  final String id;
  final String communityId;
  final String name;
  final String description;
  final String icon;
  final List<String> rules;
}

class PostMedia {
  const PostMedia({
    required this.url,
    required this.type,
    this.blobName,
    this.thumbnailUrl,
    this.thumbnailBlobName,
  });

  final String url;
  final String type;
  final String? blobName;
  final String? thumbnailUrl;
  final String? thumbnailBlobName;

  String get previewUrl =>
      thumbnailUrl?.isNotEmpty == true ? thumbnailUrl! : url;
  String? get previewCacheKey => thumbnailBlobName ?? blobName;
}

class PostPromotion {
  const PostPromotion({
    required this.id,
    required this.startsAt,
    required this.endsAt,
  });

  final String id;
  final DateTime startsAt;
  final DateTime endsAt;
}

class PollOption {
  const PollOption({
    required this.id,
    required this.text,
    required this.voteCount,
  });
  final String id;
  final String text;
  final int voteCount;
}

class PostPoll {
  const PostPoll({required this.options, this.selectedOptionId});
  final List<PollOption> options;
  final String? selectedOptionId;
  int get totalVotes =>
      options.fold(0, (total, option) => total + option.voteCount);
}

enum BusinessFulfillmentOption {
  delivery('delivery', 'Delivery'),
  pickup('pickup', 'Pickup'),
  eatIn('eat_in', 'Eat in');

  const BusinessFulfillmentOption(this.apiValue, this.label);
  final String apiValue;
  final String label;

  static BusinessFulfillmentOption? fromApi(Object? value) {
    for (final option in values) {
      if (option.apiValue == value) return option;
    }
    return null;
  }
}

class BusinessCatalogCategory {
  const BusinessCatalogCategory({
    required this.id,
    required this.name,
    this.position = 0,
    this.active = true,
  });

  final String id;
  final String name;
  final int position;
  final bool active;
}

enum BusinessProductKind { product, dailyMenu }

class BusinessProductVariant {
  const BusinessProductVariant({
    required this.id,
    required this.name,
    this.sku = '',
    this.priceCents,
    this.available = true,
    this.quantityAvailable,
    this.attributes = const {},
  });

  final String id;
  final String name;
  final String sku;
  final int? priceCents;
  final bool available;
  final int? quantityAvailable;
  final Map<String, String> attributes;

  bool get canOrder =>
      available && (quantityAvailable == null || quantityAvailable! > 0);
}

class BusinessProduct {
  const BusinessProduct({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.priceCents,
    this.kind = BusinessProductKind.product,
    this.description = '',
    this.currency = 'USD',
    this.imageUrl,
    this.available = true,
    this.quantityAvailable,
    this.variants = const [],
    this.expiresAt,
    this.position = 0,
  });

  final String id;
  final String categoryId;
  final BusinessProductKind kind;
  final String name;
  final String description;
  final int priceCents;
  final String currency;
  final String? imageUrl;
  final bool available;
  final int? quantityAvailable;
  final List<BusinessProductVariant> variants;
  final DateTime? expiresAt;
  final int position;

  bool get isExpired =>
      expiresAt != null && !expiresAt!.isAfter(DateTime.now());
  bool get canOrder =>
      available &&
      !isExpired &&
      (variants.isNotEmpty
          ? variants.any((variant) => variant.canOrder)
          : quantityAvailable == null || quantityAvailable! > 0);
}

class BusinessCatalog {
  const BusinessCatalog({
    required this.businessId,
    required this.businessName,
    this.acceptingOrders = false,
    this.fulfillmentOptions = const [],
    this.whatsapp = '',
    this.currency = 'USD',
    this.categories = const [],
    this.products = const [],
  });

  final String businessId;
  final String businessName;
  final bool acceptingOrders;
  final List<BusinessFulfillmentOption> fulfillmentOptions;
  final String whatsapp;
  final String currency;
  final List<BusinessCatalogCategory> categories;
  final List<BusinessProduct> products;
}

enum BusinessOrderStatus {
  pending,
  accepted,
  preparing,
  ready,
  completed,
  rejected,
  cancelled;

  static BusinessOrderStatus fromApi(Object? value) => values.firstWhere(
    (status) => status.name == value,
    orElse: () => BusinessOrderStatus.pending,
  );
}

class BusinessOrderItem {
  const BusinessOrderItem({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.unitPriceCents,
    required this.totalCents,
    this.imageUrl,
    this.variantId,
    this.variantName = '',
    this.sku = '',
  });

  final String productId;
  final String name;
  final int quantity;
  final int unitPriceCents;
  final int totalCents;
  final String? imageUrl;
  final String? variantId;
  final String variantName;
  final String sku;
}

class BusinessOrder {
  const BusinessOrder({
    required this.id,
    required this.businessId,
    required this.orderNumber,
    required this.status,
    required this.fulfillmentMethod,
    required this.subtotalCents,
    required this.items,
    required this.createdAt,
    this.businessName = '',
    this.customerName = '',
    this.deliveryAddress = '',
    this.customerPhone = '',
    this.notes = '',
    this.currency = 'USD',
  });

  final String id;
  final String businessId;
  final String businessName;
  final int orderNumber;
  final BusinessOrderStatus status;
  final BusinessFulfillmentOption fulfillmentMethod;
  final String customerName;
  final String deliveryAddress;
  final String customerPhone;
  final String notes;
  final String currency;
  final int subtotalCents;
  final List<BusinessOrderItem> items;
  final DateTime createdAt;
}

enum BusinessRequestType {
  quote('quote', 'Request a quote'),
  appointment('appointment', 'Book appointment'),
  service('service', 'Request service'),
  taxi('taxi', 'Request taxi');

  const BusinessRequestType(this.apiValue, this.actionLabel);
  final String apiValue;
  final String actionLabel;

  static BusinessRequestType? fromApi(Object? value) {
    for (final type in values) {
      if (type.apiValue == value) return type;
    }
    return null;
  }
}

enum BusinessRequestStatus {
  pending,
  accepted,
  quoted,
  scheduled,
  inProgress,
  completed,
  rejected,
  cancelled;

  String get apiValue => this == inProgress ? 'in_progress' : name;

  static BusinessRequestStatus fromApi(Object? value) => values.firstWhere(
    (status) => status.apiValue == value,
    orElse: () => BusinessRequestStatus.pending,
  );
}

class BusinessRequestSettings {
  const BusinessRequestSettings({
    required this.businessId,
    required this.businessName,
    this.acceptingRequests = false,
    this.capabilities = const [],
  });

  final String businessId;
  final String businessName;
  final bool acceptingRequests;
  final List<BusinessRequestType> capabilities;
}

class BusinessRequestAttachment {
  const BusinessRequestAttachment({required this.url});
  final String url;
}

class BusinessRequest {
  const BusinessRequest({
    required this.id,
    required this.businessId,
    required this.requestNumber,
    required this.type,
    required this.status,
    required this.serviceName,
    required this.createdAt,
    this.businessName = '',
    this.customerName = '',
    this.description = '',
    this.contactPhone = '',
    this.location = '',
    this.destination = '',
    this.preferredAt,
    this.scheduledAt,
    this.quotedPriceCents,
    this.currency = 'USD',
    this.businessMessage = '',
    this.attachments = const [],
  });

  final String id;
  final String businessId;
  final String businessName;
  final int requestNumber;
  final BusinessRequestType type;
  final BusinessRequestStatus status;
  final String serviceName;
  final String customerName;
  final String description;
  final String contactPhone;
  final String location;
  final String destination;
  final DateTime? preferredAt;
  final DateTime? scheduledAt;
  final int? quotedPriceCents;
  final String currency;
  final String businessMessage;
  final List<BusinessRequestAttachment> attachments;
  final DateTime createdAt;
}

class TodayMenuDish {
  const TodayMenuDish({
    required this.name,
    this.price = '',
    this.available = true,
  });

  final String name;
  final String price;
  final bool available;
}

class TodayMenu {
  const TodayMenu({
    required this.dishes,
    required this.expiresAt,
    this.fulfillmentOptions = const [],
  });

  final List<TodayMenuDish> dishes;
  final List<BusinessFulfillmentOption> fulfillmentOptions;
  final DateTime expiresAt;
  bool get isExpired => !expiresAt.isAfter(DateTime.now());
}

enum BusinessPostFeatureType {
  retailOffer('retail_offer'),
  transportTrip('transport_trip'),
  realEstateListing('real_estate_listing'),
  professionalService('professional_service');

  const BusinessPostFeatureType(this.apiValue);
  final String apiValue;

  static BusinessPostFeatureType? fromApi(Object? value) {
    for (final type in values) {
      if (type.apiValue == value) return type;
    }
    return null;
  }
}

class BusinessPostFeature {
  const BusinessPostFeature({
    required this.type,
    this.title = '',
    this.price = '',
    this.available = true,
    this.fulfillmentOptions = const [],
    this.expiresAt,
    this.routeFrom = '',
    this.routeTo = '',
    this.departureAt,
    this.seatsAvailable,
    this.listingType = '',
    this.bedrooms,
    this.location = '',
    this.serviceArea = '',
  });

  final BusinessPostFeatureType type;
  final String title;
  final String price;
  final bool available;
  final List<BusinessFulfillmentOption> fulfillmentOptions;
  final DateTime? expiresAt;
  final String routeFrom;
  final String routeTo;
  final DateTime? departureAt;
  final int? seatsAvailable;
  final String listingType;
  final int? bedrooms;
  final String location;
  final String serviceArea;

  bool get isExpired {
    final deadline = type == BusinessPostFeatureType.transportTrip
        ? departureAt
        : expiresAt;
    return deadline != null && !deadline.isAfter(DateTime.now());
  }
}

class CommunityPost {
  const CommunityPost({
    required this.id,
    required this.communityId,
    required this.categoryId,
    required this.authorId,
    required this.text,
    required this.status,
    required this.createdAt,
    this.media = const [],
    this.authorName = 'Wicchu member',
    this.authorAvatarUrl,
    this.reactionCount = 0,
    this.commentCount = 0,
    this.reactedByMe = false,
    this.savedByMe = false,
    this.ownedByMe = false,
    this.canInteract = true,
    this.canShareToCommunities = false,
    this.editedAt,
    this.promotion,
    this.poll,
    this.todayMenu,
    this.businessFeature,
    this.businessViewCount = 0,
    this.businessContactCount = 0,
    this.mentionedUserIds = const [],
    this.isAnonymous = false,
    this.moderationReason = '',
    this.reviewedAt,
    this.destinationType = 'community',
    this.shareCaption = '',
    this.isCommunityShare = false,
    this.sourceCommunityId,
    this.importantAnnouncement = false,
    this.pinned = false,
    this.canPin = false,
  });

  final String id;
  final String communityId;
  final String categoryId;
  final String authorId;
  final String text;
  final List<PostMedia> media;
  final PostStatus status;
  final DateTime createdAt;
  final String authorName;
  final String? authorAvatarUrl;
  final int reactionCount;
  final int commentCount;
  final bool reactedByMe;
  final bool savedByMe;
  final bool ownedByMe;
  final bool canInteract;
  final bool canShareToCommunities;
  final DateTime? editedAt;
  final PostPromotion? promotion;
  final PostPoll? poll;
  final TodayMenu? todayMenu;
  final BusinessPostFeature? businessFeature;
  final int businessViewCount;
  final int businessContactCount;
  final List<String> mentionedUserIds;
  final bool isAnonymous;
  final String moderationReason;
  final DateTime? reviewedAt;
  final String destinationType;
  final String shareCaption;
  final bool isCommunityShare;

  /// Original page identity supplied by shared-post responses. communityId
  /// remains the destination, so category and moderation actions stay local.
  final String? sourceCommunityId;
  final bool importantAnnouncement;
  final bool pinned;
  final bool canPin;
  bool get isPersonal => destinationType == 'personal';
  String get displayText =>
      shareCaption.trim().isEmpty ? text : '${shareCaption.trim()}\n\n$text';
}

class PostTranslation {
  const PostTranslation({
    required this.postId,
    required this.targetLanguage,
    required this.translatedText,
    this.sourceLanguage = '',
    this.cached = false,
  });

  final String postId;
  final String targetLanguage;
  final String sourceLanguage;
  final String translatedText;
  final bool cached;
}

class CommunityAboutTranslation {
  const CommunityAboutTranslation({
    required this.communityId,
    required this.targetLanguage,
    required this.translatedShortDescription,
    required this.translatedDescription,
    this.sourceLanguage = '',
    this.cached = false,
  });

  final String communityId;
  final String targetLanguage;
  final String sourceLanguage;
  final String translatedShortDescription;
  final String translatedDescription;
  final bool cached;
}

class LocalNewsSource {
  const LocalNewsSource({
    required this.id,
    required this.name,
    required this.type,
    this.siteUrl = '',
    this.trusted = false,
    this.authorizedForAutoPublish = false,
  });

  final String id;
  final String name;
  final String type;
  final String siteUrl;
  final bool trusted;
  final bool authorizedForAutoPublish;
}

class LocalNewsSettings {
  const LocalNewsSettings({
    this.enabled = false,
    this.sourceIds = const [],
    this.categoryIds = const [],
    this.language = 'es',
    this.approvalMode = 'manual',
    this.subscriptionTier = 'free',
    this.monthlyLimit = 0,
    this.tierLimits = const {'free': 0, 'pro': 60, 'business': 200},
    this.plans = const [
      LocalNewsPlan(tier: 'free', priceEur: 0, priceUsd: 0),
      LocalNewsPlan(tier: 'pro', priceEur: 4.99, priceUsd: 4.99),
      LocalNewsPlan(tier: 'business', priceEur: 9.99, priceUsd: 9.99),
    ],
    this.access,
    this.usage = const LocalNewsUsage(),
    this.lastRun,
    this.application,
    this.dashboard,
  });

  final bool enabled;
  final List<String> sourceIds;
  final List<String> categoryIds;
  final String language;
  final String approvalMode;
  final String subscriptionTier;
  final int monthlyLimit;
  final Map<String, int> tierLimits;
  final List<LocalNewsPlan> plans;

  /// Server-resolved access. Null when talking to a backend that predates it.
  final LocalNewsAccess? access;
  final LocalNewsUsage usage;
  final LocalNewsLastRun? lastRun;
  final LocalNewsAccessApplication? application;
  final LocalNewsDashboard? dashboard;

  bool get entitled => access?.entitled ?? monthlyLimit > 0;
  bool get isPilot => access?.source == 'pilot';
}

class LocalNewsAccess {
  const LocalNewsAccess({
    this.entitled = false,
    this.source = 'none',
    this.tier = 'free',
    this.monthlyLimit = 0,
    this.dailyLimit = 1,
  });

  final bool entitled;

  /// `pilot`, `subscription` or `none`.
  final String source;
  final String tier;
  final int monthlyLimit;
  final int dailyLimit;
}

class LocalNewsUsage {
  const LocalNewsUsage({
    this.month = '',
    this.monthlyUsed = 0,
    this.monthlyLimit = 0,
    this.todayUsed = 0,
    this.dailyLimit = 1,
  });

  final String month;
  final int monthlyUsed;
  final int monthlyLimit;
  final int todayUsed;
  final int dailyLimit;
}

class LocalNewsLastRun {
  const LocalNewsLastRun({
    required this.status,
    required this.finishedAt,
    this.trigger = 'manual',
    this.errorReason,
    this.processed = 0,
    this.pendingApproval = 0,
    this.published = 0,
    this.skipped = 0,
    this.errors = 0,
    this.sourceErrors = 0,
  });

  /// `success`, `partial`, `daily_limit_reached` or `error`.
  final String status;
  final DateTime finishedAt;
  final String trigger;

  /// Public reason such as `sources_unavailable`; never a provider error code.
  final String? errorReason;
  final int processed;
  final int pendingApproval;
  final int published;
  final int skipped;
  final int errors;
  final int sourceErrors;
}

/// Operational summary from GET admin/news-settings. Times are UTC instants.
class LocalNewsDashboard {
  const LocalNewsDashboard({
    required this.status,
    required this.quotaResetsAt,
    this.reason,
    this.enabled = false,
    this.collecting = false,
    this.approvalMode = 'manual',
    this.nextCollectionAt,
    this.scheduleUnavailableReason,
    this.schedulerIntervalMinutes,
    this.timezone = 'UTC',
    this.pendingApproval = 0,
    this.todayUsed = 0,
    this.publishedToday = 0,
    this.dailyLimit = 1,
    this.monthlyUsed = 0,
    this.monthlyLimit = 0,
    this.lastRun,
  });

  /// `scheduled`, `collecting`, `awaiting_approval`, `daily_limit_reached`,
  /// `configuration_needed`, `paused` or `error`.
  final String status;
  final String? reason;
  final bool enabled;
  final bool collecting;
  final String approvalMode;

  /// Next time Wicchu will look for news. Null when it cannot be determined.
  final DateTime? nextCollectionAt;
  final String? scheduleUnavailableReason;
  final int? schedulerIntervalMinutes;

  /// Timezone of the quota day boundaries.
  final String timezone;
  final DateTime quotaResetsAt;
  final int pendingApproval;

  /// News collected today that counts toward the daily limit (published or waiting).
  final int todayUsed;
  final int publishedToday;
  final int dailyLimit;
  final int monthlyUsed;
  final int monthlyLimit;
  final LocalNewsLastRun? lastRun;

  bool get dailyLimitReached => todayUsed >= dailyLimit;
}

class LocalNewsAccessApplication {
  const LocalNewsAccessApplication({
    required this.id,
    required this.status,
    required this.requestedAt,
    this.message = '',
    this.reviewNote = '',
    this.reviewedAt,
  });

  final String id;

  /// `pending`, `approved`, `rejected` or `cancelled`.
  final String status;
  final DateTime requestedAt;
  final String message;
  final String reviewNote;
  final DateTime? reviewedAt;

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
}

class LocalNewsPlan {
  const LocalNewsPlan({
    required this.tier,
    required this.priceEur,
    required this.priceUsd,
  });

  final String tier;
  final double priceEur;
  final double priceUsd;
}

class LocalNewsArticle {
  const LocalNewsArticle({
    required this.id,
    required this.title,
    required this.status,
    required this.createdAt,
    this.sourceUrl = '',
    this.skipReason = '',
    this.errorCode = '',
  });

  final String id;
  final String title;
  final String status;
  final DateTime createdAt;
  final String sourceUrl;
  final String skipReason;
  final String errorCode;
}

class LocalNewsRunResult {
  const LocalNewsRunResult({
    this.collected = 0,
    this.processed = 0,
    this.pendingApproval = 0,
    this.published = 0,
    this.skipped = 0,
    this.errors = 0,
  });

  final int collected;
  final int processed;
  final int pendingApproval;
  final int published;
  final int skipped;
  final int errors;
}

enum PromotionStatus { pending, active, rejected, completed, cancelled }

class PromotionEligibility {
  const PromotionEligibility({
    required this.eligible,
    required this.trialStarted,
    required this.trialDays,
    required this.maxCampaignDays,
    this.startedAt,
    this.expiresAt,
    this.activeCampaignId,
    this.townId,
  });

  final bool eligible;
  final bool trialStarted;
  final int trialDays;
  final int maxCampaignDays;
  final DateTime? startedAt;
  final DateTime? expiresAt;
  final String? activeCampaignId;
  final String? townId;
}

class PromotionCampaign {
  const PromotionCampaign({
    required this.id,
    required this.postId,
    required this.communityId,
    required this.status,
    required this.durationDays,
    required this.impressionCount,
    required this.clickCount,
    required this.createdAt,
    this.startsAt,
    this.endsAt,
    this.rejectionReason = '',
  });

  final String id;
  final String postId;
  final String communityId;
  final PromotionStatus status;
  final int durationDays;
  final int impressionCount;
  final int clickCount;
  final DateTime createdAt;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String rejectionReason;
}

class SharedPostPreview {
  const SharedPostPreview({
    required this.post,
    required this.communityId,
    required this.communityName,
    required this.communityDescription,
    required this.categoryName,
    required this.categoryIcon,
    this.communityImageUrl,
  });

  final CommunityPost post;
  final String communityId;
  final String communityName;
  final String communityDescription;
  final String? communityImageUrl;
  final String categoryName;
  final String categoryIcon;
}

class PostShareKit {
  const PostShareKit({
    required this.canonicalUrl,
    required this.message,
    required this.whatsappUrl,
    required this.facebookUrl,
    required this.instagramFeedImageUrl,
    required this.instagramStoryImageUrl,
  });

  final String canonicalUrl;
  final String message;
  final String whatsappUrl;
  final String facebookUrl;
  final String instagramFeedImageUrl;
  final String instagramStoryImageUrl;
}

class Comment {
  const Comment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.text,
    required this.createdAt,
    this.authorName = 'Wicchu member',
    this.authorAvatarUrl,
    this.parentCommentId,
    this.replyToCommentId,
    this.replyToUserId,
    this.replyToName,
    this.reactionCount = 0,
    this.reactedByMe = false,
  });

  final String id;
  final String postId;
  final String authorId;
  final String text;
  final DateTime createdAt;
  final String authorName;
  final String? authorAvatarUrl;
  final String? parentCommentId;
  final String? replyToCommentId;
  final String? replyToUserId;
  final String? replyToName;
  final int reactionCount;
  final bool reactedByMe;
}

class Reaction {
  const Reaction({
    required this.userId,
    required this.targetId,
    required this.type,
  });

  final String userId;
  final String targetId;
  final String type;
}

class CommunityReport {
  const CommunityReport({
    required this.id,
    required this.reporterId,
    required this.communityId,
    required this.targetType,
    required this.targetId,
    required this.category,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.reporterName,
    this.reporterAvatarUrl,
    this.targetAuthorName,
    this.targetAuthorAvatarUrl,
    this.targetText,
    this.targetStatus,
    this.targetPostId,
    this.targetMediaCount = 0,
  });

  final String id;
  final String reporterId;
  final String communityId;
  final ModerationTargetType targetType;
  final String targetId;
  final String category;
  final String reason;
  final ReportStatus status;
  final DateTime createdAt;
  final String? reporterName;
  final String? reporterAvatarUrl;
  final String? targetAuthorName;
  final String? targetAuthorAvatarUrl;
  final String? targetText;
  final String? targetStatus;
  final String? targetPostId;
  final int targetMediaCount;
}

enum PlatformReportTargetType {
  community,
  communityAdmin,
  message,
  post,
  comment,
  user,
}

class PlatformReport {
  const PlatformReport({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.communityId,
    required this.communityName,
    required this.reporterName,
    required this.targetName,
    required this.category,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.evidence = const {},
    this.actions = const [],
    this.resolvedAt,
    this.resolvedByName,
  });

  final String id;
  final PlatformReportTargetType targetType;
  final String targetId;
  final String communityId;
  final String communityName;
  final String reporterName;
  final String targetName;
  final String category;
  final String reason;
  final String status;
  final DateTime createdAt;
  final Map<String, dynamic> evidence;
  final List<PlatformModerationAction> actions;
  final DateTime? resolvedAt;
  final String? resolvedByName;
}

class PlatformModerationAction {
  const PlatformModerationAction({
    required this.action,
    required this.moderatorName,
    required this.createdAt,
    this.note = '',
  });

  final String action;
  final String moderatorName;
  final String note;
  final DateTime createdAt;
}

class ModerationAction {
  const ModerationAction({
    required this.id,
    required this.moderatorId,
    required this.communityId,
    required this.action,
    required this.targetId,
    required this.reason,
    required this.createdAt,
  });

  final String id;
  final String moderatorId;
  final String communityId;
  final String action;
  final String targetId;
  final String reason;
  final DateTime createdAt;
}

class MembershipRequest {
  const MembershipRequest({
    required this.userId,
    required this.userName,
    required this.createdAt,
  });

  final String userId;
  final String userName;
  final DateTime createdAt;
}

class BlockedUser {
  const BlockedUser({required this.userId, required this.name, this.avatarUrl});
  final String userId;
  final String name;
  final String? avatarUrl;
}

class DirectConversation {
  const DirectConversation({
    required this.id,
    required this.otherUser,
    required this.unreadCount,
    this.lastMessagePreview = '',
    this.lastMessageAt,
    this.lastMessageMine = false,
    this.lastMessageRemoved = false,
    this.requestStatus = MessageRequestStatus.accepted,
    this.requestedByMe = false,
    this.canSendMessage = true,
    this.pageId,
    this.pageName,
    this.viewingAsPage = false,
    this.otherIsPage = false,
    this.communityInbox = false,
    this.label = ConversationLabel.newConversation,
    this.isOnline = false,
    this.lastActiveAt,
  });

  final String id;
  final WicchuUser otherUser;
  final String lastMessagePreview;
  final DateTime? lastMessageAt;
  final bool lastMessageMine;
  final bool lastMessageRemoved;
  final int unreadCount;
  final MessageRequestStatus requestStatus;
  final bool requestedByMe;
  final bool canSendMessage;
  final String? pageId;
  final String? pageName;
  final bool viewingAsPage;
  final bool otherIsPage;
  final bool communityInbox;
  final ConversationLabel label;
  final bool isOnline;
  final DateTime? lastActiveAt;
}

enum MessageRequestStatus { pending, accepted, declined }

enum ConversationLabel {
  newConversation,
  inProgress,
  customer,
  order,
  quote,
  completed,
}

class DirectMessage {
  const DirectMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.recipientId,
    required this.body,
    required this.createdAt,
    this.readAt,
    this.removedAt,
    this.sentByMe = false,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String recipientId;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;
  final DateTime? removedAt;
  final bool sentByMe;

  DirectMessage copyWith({
    DateTime? readAt,
    DateTime? removedAt,
    String? body,
    bool? sentByMe,
  }) => DirectMessage(
    id: id,
    conversationId: conversationId,
    senderId: senderId,
    recipientId: recipientId,
    body: body ?? this.body,
    createdAt: createdAt,
    readAt: readAt ?? this.readAt,
    removedAt: removedAt ?? this.removedAt,
    sentByMe: sentByMe ?? this.sentByMe,
  );
}

class DirectMessagePage {
  const DirectMessagePage({required this.messages, this.nextCursor});

  final List<DirectMessage> messages;
  final String? nextCursor;
}

enum MessagingPrivacy { everyone, sharedCommunities, nobody }
