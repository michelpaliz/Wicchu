enum CommunityVisibility { public, private }

enum CommunityRole { owner, admin, moderator, member }

enum MembershipStatus { active, pending, banned }

enum PostStatus { published, pendingApproval, removed }

enum ReportStatus { open, reviewing, resolved, dismissed }

enum ModerationTargetType { post, comment, member }

enum CommunityNotificationType {
  postReaction,
  commentReaction,
  postComment,
  commentReply,
  postApproved,
  postRejected,
  postRemoved,
  postRestored,
  commentApproved,
  commentRejected,
  commentRemoved,
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
  });

  final String id;
  final String name;
  final String userName;
  final String? avatarUrl;
  final String? location;
  final int communityCount;
  final int postCount;
  final int savedPostCount;
}

class PublicMemberProfile {
  const PublicMemberProfile({
    required this.id,
    required this.name,
    required this.userName,
    required this.postCount,
    required this.communityCount,
    this.avatarUrl,
    this.socialLinks = const SocialLinks(),
    this.isOnline = false,
    this.lastActiveAt,
  });
  final String id;
  final String name;
  final String userName;
  final String? avatarUrl;
  final int postCount;
  final int communityCount;
  final SocialLinks socialLinks;
  final bool isOnline;
  final DateTime? lastActiveAt;
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
  bool get isEmpty => whatsapp.isEmpty && facebook.isEmpty && instagram.isEmpty && email.isEmpty;
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
    required this.description,
    required this.town,
    required this.visibility,
    required this.createdBy,
    required this.createdAt,
    this.imageUrl,
    this.memberCount = 0,
    this.myRole,
    this.approvalRequired = false,
    this.showWeather = false,
    this.distanceKm,
    this.rules = const [],
  });

  final String id;
  final String name;
  final String description;
  final Town town;
  final String? imageUrl;
  final CommunityVisibility visibility;
  final String createdBy;
  final DateTime createdAt;
  final int memberCount;
  final CommunityRole? myRole;
  final bool approvalRequired;
  final bool showWeather;
  final double? distanceKm;
  final List<CommunityRule> rules;

  bool get isJoined => myRole != null;
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
    this.invitationUrl,
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
  final String? invitationUrl;

  bool get isLink => type == 'link';
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
  const PostMedia({required this.url, required this.type, this.blobName});

  final String url;
  final String type;
  final String? blobName;
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
    this.editedAt,
    this.promotion,
    this.poll,
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
  final DateTime? editedAt;
  final PostPromotion? promotion;
  final PostPoll? poll;
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
    required this.reason,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String reporterId;
  final String communityId;
  final ModerationTargetType targetType;
  final String targetId;
  final String reason;
  final ReportStatus status;
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
