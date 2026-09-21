import 'community_models.dart';

class CreateCommunityInput {
  const CreateCommunityInput({
    required this.name,
    required this.description,
    required this.town,
    required this.visibility,
    required this.categoryNames,
  });

  final String name;
  final String description;
  final Town town;
  final CommunityVisibility visibility;
  final List<String> categoryNames;
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

abstract interface class CommunityRepository {
  Future<List<Town>> listTowns();
  Future<List<Community>> listManagedCommunities();
  Future<Community> createCommunity(CreateCommunityInput input);
  Future<List<CommunityCategory>> listCategories(String communityId);
  Future<AdminAttentionSummary> getAdminAttention(String communityId);
}
