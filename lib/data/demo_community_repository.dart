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

  static const _towns = [Town(id: 'town-1', name: 'Town X', countryCode: 'EC')];

  @override
  Future<List<Town>> listTowns() async => _towns;

  @override
  Future<List<Community>> listManagedCommunities() async =>
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
  Future<List<CommunityCategory>> listCategories(String communityId) async =>
      List.unmodifiable(_categories[communityId] ?? const []);

  @override
  Future<AdminAttentionSummary> getAdminAttention(String communityId) async =>
      const AdminAttentionSummary();

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
