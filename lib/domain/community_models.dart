enum CommunityVisibility { public, private }

enum CommunityRole { owner, admin, moderator, member }

enum MembershipStatus { active, pending, banned }

enum PostStatus { published, pendingApproval, removed }

enum ReportStatus { open, reviewing, resolved, dismissed }

enum ModerationTargetType { post, comment, member }

enum CommunityNotificationType { postReaction, postComment }

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
  });

  final String id;
  final String actorName;
  final String? actorAvatarUrl;
  final CommunityNotificationType type;
  final String postId;
  final String message;
  final DateTime createdAt;
  final bool isRead;
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
    this.distanceKm,
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
  final double? distanceKm;

  bool get isJoined => myRole != null;
}

class CommunityMember {
  const CommunityMember({
    required this.userId,
    required this.communityId,
    required this.role,
    required this.status,
    required this.joinedAt,
    this.name = 'Wicchu member',
  });

  final String userId;
  final String communityId;
  final CommunityRole role;
  final MembershipStatus status;
  final DateTime joinedAt;
  final String name;
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
    this.reactionCount = 0,
    this.commentCount = 0,
    this.reactedByMe = false,
    this.savedByMe = false,
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
  final int reactionCount;
  final int commentCount;
  final bool reactedByMe;
  final bool savedByMe;
}

class Comment {
  const Comment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.text,
    required this.createdAt,
    this.authorName = 'Wicchu member',
  });

  final String id;
  final String postId;
  final String authorId;
  final String text;
  final DateTime createdAt;
  final String authorName;
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
