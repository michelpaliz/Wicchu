enum CommunityVisibility { public, private }

enum CommunityRole { owner, admin, moderator, member }

enum MembershipStatus { active, pending, banned }

enum PostStatus { published, pendingApproval, removed }

enum ReportStatus { open, reviewing, resolved, dismissed }

enum ModerationTargetType { post, comment, member }

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
}

class CommunityMember {
  const CommunityMember({
    required this.userId,
    required this.communityId,
    required this.role,
    required this.status,
    required this.joinedAt,
  });

  final String userId;
  final String communityId;
  final CommunityRole role;
  final MembershipStatus status;
  final DateTime joinedAt;
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
  const PostMedia({required this.url, required this.type});

  final String url;
  final String type;
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
  });

  final String id;
  final String communityId;
  final String categoryId;
  final String authorId;
  final String text;
  final List<PostMedia> media;
  final PostStatus status;
  final DateTime createdAt;
}

class Comment {
  const Comment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String postId;
  final String authorId;
  final String text;
  final DateTime createdAt;
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
