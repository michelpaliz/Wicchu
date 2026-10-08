import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';
import '../../widgets/responsive_side_panel.dart';
import '../../widgets/wicchu_network_image.dart';
import 'community_avatar.dart';
import 'community_profile_page.dart';
import 'post_detail_page.dart';

enum _DiscoveryCategory {
  all,
  food,
  transport,
  retail,
  properties,
  services,
  beauty,
  health,
}

enum _DiscoveryLocationMode { town, nearby, anywhere }

class LocalDiscoveryView extends StatefulWidget {
  const LocalDiscoveryView({
    super.key,
    required this.repository,
    this.initialQuery = '',
  });

  final CommunityRepository repository;
  final String initialQuery;

  @override
  State<LocalDiscoveryView> createState() => _LocalDiscoveryViewState();
}

class _LocalDiscoveryViewState extends State<LocalDiscoveryView> {
  late Future<_DiscoveryData> _data = _initialize();
  _DiscoveryCategory _category = _DiscoveryCategory.all;
  _DiscoveryLocationMode _locationMode = _DiscoveryLocationMode.town;
  String? _townId;
  Position? _position;
  double _radiusKm = 10;
  bool _locating = false;
  String? _locationError;
  int _locationSettingsAction = 0;
  bool _delivery = false;
  bool _pickup = false;
  bool _openNow = false;
  int _departureDay = 0;
  String _listingType = '';
  double? _maxPrice;
  bool _showFoodBusinesses = false;

  Future<_DiscoveryData> _initialize() async {
    final preferences = await SharedPreferences.getInstance();
    _townId = preferences.getString('business_discovery_town_id');
    _radiusKm = preferences.getDouble('business_discovery_radius_km') ?? 10;
    _locationMode = switch (preferences.getString(
      'business_discovery_location_mode',
    )) {
      'nearby' => _DiscoveryLocationMode.nearby,
      'anywhere' => _DiscoveryLocationMode.anywhere,
      _ => _DiscoveryLocationMode.town,
    };
    if (_locationMode == _DiscoveryLocationMode.nearby) {
      _position = await _currentPosition(requestPermission: false);
    }
    return _load();
  }

  Future<_DiscoveryData> _load() async {
    final results = await Future.wait<dynamic>([
      widget.repository.listTowns(),
      widget.repository.listJoinedCommunities(),
    ]);
    final towns = results[0] as List<Town>;
    final joined = results[1] as List<Community>;
    if (towns.isEmpty) {
      return const _DiscoveryData(towns: [], communities: [], posts: []);
    }
    final preferredTownId = _townId ?? joined.firstOrNull?.town.id;
    final town =
        towns.where((item) => item.id == preferredTownId).firstOrNull ??
        towns.first;
    _townId = town.id;
    final communities = switch (_locationMode) {
      _DiscoveryLocationMode.town =>
        await widget.repository.listLocalBusinesses(townId: town.id),
      _DiscoveryLocationMode.anywhere =>
        await widget.repository.listLocalBusinesses(),
      _DiscoveryLocationMode.nearby when _position != null =>
        await widget.repository.listNearbyBusinesses(
          latitude: _position!.latitude,
          longitude: _position!.longitude,
          radiusKm: _radiusKm,
        ),
      _ => const <Community>[],
    };
    final posts = await widget.repository.listBusinessPosts(
      communities.map((business) => business.id).toList(growable: false),
      query: widget.initialQuery.trim().isEmpty ? null : widget.initialQuery,
    );
    return _DiscoveryData(towns: towns, communities: communities, posts: posts);
  }

  Future<Position?> _currentPosition({required bool requestPermission}) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (!(preferences.getBool('location_discovery') ?? true)) {
        _locationError = 'Enable nearby discovery in Settings first.';
        _locationSettingsAction = 0;
        return null;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        _locationError = 'Enable location services to find businesses nearby.';
        _locationSettingsAction = 1;
        return null;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && requestPermission) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _locationError = 'Location permission is required for Near me.';
        _locationSettingsAction = permission == LocationPermission.deniedForever
            ? 2
            : 0;
        return null;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          timeLimit: Duration(seconds: 15),
        ),
      );
      _locationError = null;
      _locationSettingsAction = 0;
      return position;
    } on TimeoutException {
      _locationError = 'Could not get your location. Try again.';
      _locationSettingsAction = 0;
      return null;
    } catch (_) {
      _locationError = 'Could not get your location. Try again.';
      _locationSettingsAction = 0;
      return null;
    }
  }

  Future<void> _refresh() async {
    setState(() => _data = _load());
    try {
      await _data;
    } catch (_) {}
  }

  Future<void> _selectTown(String? value) async {
    if (value == null || value == _townId) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('business_discovery_town_id', value);
    if (!mounted) return;
    setState(() {
      _townId = value;
      _data = _load();
    });
  }

  Future<void> _selectLocationMode(_DiscoveryLocationMode mode) async {
    if (_locating) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('business_discovery_location_mode', mode.name);
    if (mode == _DiscoveryLocationMode.nearby) {
      if (mounted) setState(() => _locating = true);
      final position = await _currentPosition(requestPermission: true);
      if (!mounted) return;
      setState(() {
        _locationMode = mode;
        _position = position;
        _locating = false;
        _data = _load();
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _locationMode = mode;
      _locationError = null;
      _data = _load();
    });
  }

  Future<void> _selectRadius(double radiusKm) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setDouble('business_discovery_radius_km', radiusKm);
    if (!mounted) return;
    setState(() {
      _radiusKm = radiusKm;
      _data = _load();
    });
  }

  bool _matchesCategory(CommunityPost post) => switch (_category) {
    _DiscoveryCategory.all => true,
    _DiscoveryCategory.food => post.todayMenu != null,
    _DiscoveryCategory.transport =>
      post.businessFeature?.type == BusinessPostFeatureType.transportTrip,
    _DiscoveryCategory.retail =>
      post.businessFeature?.type == BusinessPostFeatureType.retailOffer,
    _DiscoveryCategory.properties =>
      post.businessFeature?.type == BusinessPostFeatureType.realEstateListing,
    _DiscoveryCategory.services =>
      post.businessFeature?.type == BusinessPostFeatureType.professionalService,
    _DiscoveryCategory.beauty || _DiscoveryCategory.health => false,
  };

  bool _matchesFilters(CommunityPost post, Community? business) {
    if (!_matchesCategory(post)) return false;
    final menu = post.todayMenu;
    final feature = post.businessFeature;
    final fulfillment =
        menu?.fulfillmentOptions ?? feature?.fulfillmentOptions ?? const [];
    if (_delivery &&
        !fulfillment.contains(BusinessFulfillmentOption.delivery)) {
      return false;
    }
    if (_pickup && !fulfillment.contains(BusinessFulfillmentOption.pickup)) {
      return false;
    }
    if (_openNow && (business == null || !_isOpenNow(business))) return false;
    if (_listingType.isNotEmpty && feature?.listingType != _listingType) {
      return false;
    }
    if (_departureDay != 0 && feature?.departureAt != null) {
      final departure = feature!.departureAt!.toLocal();
      final now = DateTime.now();
      final expected = DateTime(
        now.year,
        now.month,
        now.day + _departureDay - 1,
      );
      if (departure.year != expected.year ||
          departure.month != expected.month ||
          departure.day != expected.day) {
        return false;
      }
    }
    if (_maxPrice != null) {
      final price = _priceValue(post);
      if (price == null || price > _maxPrice!) return false;
    }
    if (menu != null &&
        (menu.isExpired || !menu.dishes.any((dish) => dish.available))) {
      return false;
    }
    if (feature != null && (feature.isExpired || !feature.available)) {
      return false;
    }
    if (feature?.type == BusinessPostFeatureType.transportTrip &&
        (feature?.seatsAvailable ?? 0) <= 0) {
      return false;
    }
    return true;
  }

  double? _priceValue(CommunityPost post) {
    final source = post.businessFeature?.price.isNotEmpty == true
        ? post.businessFeature!.price
        : post.todayMenu?.dishes
                  .where((dish) => dish.price.isNotEmpty)
                  .firstOrNull
                  ?.price ??
              '';
    final match = RegExp(r'\d+(?:[.,]\d+)?').firstMatch(source);
    return double.tryParse((match?.group(0) ?? '').replaceAll(',', '.'));
  }

  bool _isOpenNow(Community business) {
    final now = DateTime.now();
    const days = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];
    final today = business.businessHours
        .where((item) => item.day == days[now.weekday - 1])
        .firstOrNull;
    if (today == null ||
        today.closed ||
        today.open.isEmpty ||
        today.close.isEmpty) {
      return false;
    }
    int minutes(String value) {
      final parts = value.split(':');
      return parts.length == 2
          ? (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0)
          : 0;
    }

    final current = now.hour * 60 + now.minute;
    return current >= minutes(today.open) && current < minutes(today.close);
  }

  void _resetFilterValues() {
    _delivery = false;
    _pickup = false;
    _openNow = false;
    _departureDay = 0;
    _listingType = '';
    _maxPrice = null;
  }

  void _clearFilters() => setState(_resetFilterValues);

  Future<void> _priceFilter() async {
    final controller = TextEditingController(text: _maxPrice?.toString() ?? '');
    final value = await showModalBottomSheet<double?>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.tr('Maximum price'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  prefixText: r'$ ',
                  labelText: context.tr('Price'),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(
                  sheetContext,
                  double.tryParse(controller.text.trim().replaceAll(',', '.')),
                ),
                child: Text(context.tr('Apply filters')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(sheetContext, -1),
                child: Text(context.tr('Any price')),
              ),
            ],
          ),
        ),
      ),
    );
    controller.dispose();
    if (!mounted || value == null) return;
    setState(() => _maxPrice = value < 0 ? null : value);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_DiscoveryData>(
    future: _data,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return _DiscoveryMessage(
          icon: Icons.cloud_off_outlined,
          title: context.tr('Could not load local discovery.'),
          action: TextButton(
            onPressed: _refresh,
            child: Text(context.tr('Try again')),
          ),
        );
      }
      final data = snapshot.data!;
      if (data.towns.isEmpty) {
        return _DiscoveryMessage(
          icon: Icons.location_off_outlined,
          title: context.tr('No towns are available yet.'),
        );
      }
      final communityById = {
        for (final item in data.communities) item.id: item,
      };
      final posts = data.posts
          .where(
            (post) => _matchesFilters(post, communityById[post.communityId]),
          )
          .toList(growable: false);
      final businesses = data.communities
          .where(
            (item) =>
                (_locationMode != _DiscoveryLocationMode.town ||
                    item.town.id == _townId) &&
                item.profileCategory == ProfileCategory.localBusiness &&
                _matchesBusinessCategory(item) &&
                _matchesBusinessQuery(item),
          )
          .toList(growable: false);
      final town =
          data.towns.where((item) => item.id == _townId).firstOrNull ??
          data.towns.first;
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          key: const ValueKey('local-discovery-results'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Text(
              context.tr('Discover local businesses'),
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(_locationSummary(town)),
            const SizedBox(height: 14),
            Text(
              context.tr('Location'),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final mode in _DiscoveryLocationMode.values)
                  ChoiceChip(
                    selected: _locationMode == mode,
                    avatar: _locating && mode == _DiscoveryLocationMode.nearby
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(_locationModeIcon(mode), size: 18),
                    label: Text(context.tr(_locationModeLabel(mode))),
                    onSelected: (_) => _selectLocationMode(mode),
                  ),
              ],
            ),
            if (_locationMode == _DiscoveryLocationMode.town) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _townId,
                decoration: InputDecoration(
                  labelText: context.tr('Town'),
                  prefixIcon: const Icon(Icons.location_on_outlined),
                ),
                items: [
                  for (final item in data.towns)
                    DropdownMenuItem(value: item.id, child: Text(item.name)),
                ],
                onChanged: _selectTown,
              ),
            ],
            if (_locationMode == _DiscoveryLocationMode.nearby) ...[
              const SizedBox(height: 12),
              Text(
                context.tr('Search radius'),
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  for (final radius in const [1.0, 10.0, 50.0])
                    ChoiceChip(
                      selected: _radiusKm == radius,
                      label: Text('${radius.toStringAsFixed(0)} km'),
                      onSelected: (_) => _selectRadius(radius),
                    ),
                ],
              ),
              if (_locationError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.location_off_outlined,
                        size: 18,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(context.tr(_locationError!))),
                      TextButton(
                        onPressed: _locationSettingsAction == 1
                            ? Geolocator.openLocationSettings
                            : _locationSettingsAction == 2
                            ? Geolocator.openAppSettings
                            : () => _selectLocationMode(
                                _DiscoveryLocationMode.nearby,
                              ),
                        child: Text(
                          context.tr(
                            _locationSettingsAction == 0
                                ? 'Try again'
                                : 'Open settings',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in _DiscoveryCategory.values)
                  ChoiceChip(
                    selected: _category == item,
                    avatar: Icon(_categoryIcon(item), size: 18),
                    label: Text(context.tr(_categoryLabel(item))),
                    onSelected: (_) => setState(() {
                      _category = item;
                      _showFoodBusinesses = false;
                      _resetFilterValues();
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _filterBar(),
            const SizedBox(height: 16),
            if (_category == _DiscoveryCategory.food) ...[
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                    value: false,
                    icon: const Icon(Icons.restaurant_menu_outlined),
                    label: Text(context.tr("Today's menus")),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: const Icon(Icons.storefront_outlined),
                    label: Text(context.tr('Restaurants')),
                  ),
                ],
                selected: {_showFoodBusinesses},
                onSelectionChanged: (value) =>
                    setState(() => _showFoodBusinesses = value.first),
              ),
              const SizedBox(height: 16),
              if (_showFoodBusinesses)
                ..._businessDirectory(businesses)
              else if (posts.isEmpty)
                _emptyPublications()
              else
                ...posts.map(
                  (post) => _postCard(post, communityById[post.communityId]),
                ),
            ] else ...[
              if (_category == _DiscoveryCategory.all)
                ..._overviewSections(posts, communityById)
              else if (posts.isNotEmpty)
                ...posts.map(
                  (post) => _postCard(post, communityById[post.communityId]),
                ),
              ..._businessDirectory(businesses),
            ],
          ],
        ),
      );
    },
  );

  bool _matchesBusinessQuery(Community business) {
    final query = widget.initialQuery.trim().toLowerCase();
    if (query.isEmpty) return true;
    return business.name.toLowerCase().contains(query) ||
        business.shortDescription.toLowerCase().contains(query) ||
        business.description.toLowerCase().contains(query) ||
        business.businessServices.any(
          (service) => service.label.toLowerCase().contains(query),
        );
  }

  bool _matchesBusinessCategory(Community business) {
    final services = business.businessServices;
    return switch (_category) {
      _DiscoveryCategory.all => true,
      _DiscoveryCategory.food => services.contains(BusinessService.food),
      _DiscoveryCategory.transport => services.contains(
        BusinessService.transport,
      ),
      _DiscoveryCategory.retail => services.contains(BusinessService.retail),
      _DiscoveryCategory.properties => services.contains(
        BusinessService.realEstate,
      ),
      _DiscoveryCategory.beauty => services.contains(BusinessService.beauty),
      _DiscoveryCategory.health => services.contains(BusinessService.health),
      _DiscoveryCategory.services => services.any(
        const {
          BusinessService.gardening,
          BusinessService.pools,
          BusinessService.concierge,
          BusinessService.cleaning,
          BusinessService.maintenance,
          BusinessService.construction,
          BusinessService.education,
          BusinessService.professionalServices,
          BusinessService.other,
        }.contains,
      ),
    };
  }

  bool _matchesBusinessFilters(Community business) {
    if (_openNow && !_isOpenNow(business)) return false;
    if (_delivery &&
        !business.businessFulfillmentOptions.contains(
          BusinessFulfillmentOption.delivery,
        )) {
      return false;
    }
    if (_pickup &&
        !business.businessFulfillmentOptions.contains(
          BusinessFulfillmentOption.pickup,
        )) {
      return false;
    }
    return true;
  }

  List<Widget> _businessDirectory(List<Community> businesses) {
    final filtered = businesses.where(_matchesBusinessFilters).toList();
    if (filtered.isEmpty) {
      return [if (_category != _DiscoveryCategory.all) _emptyBusinesses()];
    }
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                context.tr(
                  _category == _DiscoveryCategory.food
                      ? 'Restaurants'
                      : 'Local businesses',
                ),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            if (_locationMode == _DiscoveryLocationMode.nearby)
              Text(
                context.tr('Nearest first'),
                style: Theme.of(context).textTheme.labelMedium,
              ),
          ],
        ),
      ),
      ...filtered.map(_businessCard),
    ];
  }

  Widget _filterBar() {
    final chips = <Widget>[];
    if (_category == _DiscoveryCategory.food ||
        _category == _DiscoveryCategory.retail ||
        _category == _DiscoveryCategory.all) {
      chips.addAll([
        FilterChip(
          label: Text(context.tr('Delivery')),
          selected: _delivery,
          onSelected: (value) => setState(() => _delivery = value),
        ),
        FilterChip(
          label: Text(context.tr('Pickup')),
          selected: _pickup,
          onSelected: (value) => setState(() => _pickup = value),
        ),
      ]);
    }
    if (_category == _DiscoveryCategory.food ||
        _category == _DiscoveryCategory.all) {
      chips.add(
        FilterChip(
          label: Text(context.tr('Open now')),
          selected: _openNow,
          onSelected: (value) => setState(() => _openNow = value),
        ),
      );
    }
    if (_category == _DiscoveryCategory.transport) {
      chips.addAll([
        ChoiceChip(
          label: Text(context.tr('Upcoming')),
          selected: _departureDay == 0,
          onSelected: (_) => setState(() => _departureDay = 0),
        ),
        ChoiceChip(
          label: Text(context.tr('Today')),
          selected: _departureDay == 1,
          onSelected: (_) => setState(() => _departureDay = 1),
        ),
        ChoiceChip(
          label: Text(context.tr('Tomorrow')),
          selected: _departureDay == 2,
          onSelected: (_) => setState(() => _departureDay = 2),
        ),
      ]);
    }
    if (_category == _DiscoveryCategory.properties) {
      for (final entry in const {
        '': 'All',
        'rent': 'For rent',
        'sale': 'For sale',
      }.entries) {
        chips.add(
          ChoiceChip(
            label: Text(context.tr(entry.value)),
            selected: _listingType == entry.key,
            onSelected: (_) => setState(() => _listingType = entry.key),
          ),
        );
      }
    }
    if (_category != _DiscoveryCategory.beauty &&
        _category != _DiscoveryCategory.health) {
      chips.add(
        ActionChip(
          avatar: const Icon(Icons.payments_outlined, size: 18),
          label: Text(
            _maxPrice == null
                ? context.tr('Price')
                : context.tr('Up to {price}', {
                    'price': '\$${_maxPrice!.toStringAsFixed(0)}',
                  }),
          ),
          onPressed: _priceFilter,
        ),
      );
    }
    if (_delivery ||
        _pickup ||
        _openNow ||
        _departureDay != 0 ||
        _listingType.isNotEmpty ||
        _maxPrice != null) {
      chips.add(
        ActionChip(
          label: Text(context.tr('Reset filters')),
          onPressed: _clearFilters,
        ),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final chip in chips)
            Padding(padding: const EdgeInsets.only(right: 8), child: chip),
        ],
      ),
    );
  }

  List<Widget> _overviewSections(
    List<CommunityPost> posts,
    Map<String, Community> communityById,
  ) {
    final sections = <(_DiscoveryCategory, String)>[
      (_DiscoveryCategory.food, "Today's menus"),
      (_DiscoveryCategory.transport, 'Upcoming transport'),
      (_DiscoveryCategory.retail, 'Shop local'),
      (_DiscoveryCategory.properties, 'Properties'),
      (_DiscoveryCategory.services, 'Local services'),
    ];
    return [
      for (final section in sections)
        if (posts.any((post) => _matchesCategoryValue(post, section.$1))) ...[
          _sectionHeader(section.$2, section.$1),
          for (final post
              in posts
                  .where((post) {
                    final type = post.businessFeature?.type;
                    return switch (section.$1) {
                      _DiscoveryCategory.food => post.todayMenu != null,
                      _DiscoveryCategory.transport =>
                        type == BusinessPostFeatureType.transportTrip,
                      _DiscoveryCategory.retail =>
                        type == BusinessPostFeatureType.retailOffer,
                      _DiscoveryCategory.properties =>
                        type == BusinessPostFeatureType.realEstateListing,
                      _DiscoveryCategory.services =>
                        type == BusinessPostFeatureType.professionalService,
                      _ => false,
                    };
                  })
                  .take(3))
            _postCard(post, communityById[post.communityId]),
          const SizedBox(height: 12),
        ],
    ];
  }

  bool _matchesCategoryValue(CommunityPost post, _DiscoveryCategory category) {
    final type = post.businessFeature?.type;
    return switch (category) {
      _DiscoveryCategory.all => true,
      _DiscoveryCategory.food => post.todayMenu != null,
      _DiscoveryCategory.transport =>
        type == BusinessPostFeatureType.transportTrip,
      _DiscoveryCategory.retail => type == BusinessPostFeatureType.retailOffer,
      _DiscoveryCategory.properties =>
        type == BusinessPostFeatureType.realEstateListing,
      _DiscoveryCategory.services =>
        type == BusinessPostFeatureType.professionalService,
      _DiscoveryCategory.beauty || _DiscoveryCategory.health => false,
    };
  }

  Widget _sectionHeader(String title, _DiscoveryCategory category) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Expanded(
          child: Text(
            context.tr(title),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        TextButton(
          onPressed: () => setState(() => _category = category),
          child: Text(context.tr('See all')),
        ),
      ],
    ),
  );

  Widget _postCard(CommunityPost post, Community? business) {
    final feature = post.businessFeature;
    final menu = post.todayMenu;
    final title = menu != null
        ? menu.dishes
              .where((dish) => dish.available)
              .map((dish) => dish.name)
              .take(3)
              .join(' · ')
        : feature?.type == BusinessPostFeatureType.transportTrip
        ? '${feature!.routeFrom} → ${feature.routeTo}'
        : feature?.title.isNotEmpty == true
        ? feature!.title
        : post.text.split('\n').first;
    final price = feature?.price.isNotEmpty == true
        ? feature!.price
        : menu?.dishes
                  .where((dish) => dish.price.isNotEmpty)
                  .firstOrNull
                  ?.price ??
              '';
    final detail = feature?.type == BusinessPostFeatureType.transportTrip
        ? '${_dateTime(feature?.departureAt)} · ${feature?.seatsAvailable ?? 0} ${context.tr('seats')}'
        : feature?.type == BusinessPostFeatureType.realEstateListing
        ? '${context.tr(feature?.listingType == 'rent' ? 'For rent' : 'For sale')} · ${feature?.bedrooms ?? 0} ${context.tr('bedrooms')}'
        : feature?.type == BusinessPostFeatureType.professionalService
        ? feature?.serviceArea ?? ''
        : menu != null
        ? context.tr('Available today')
        : context.tr('Currently available');
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openResponsiveSidePanel<void>(
          context,
          width: 620,
          builder: (_) => PostDetailPage(
            postId: post.id,
            initialPost: post,
            repository: widget.repository,
            community: business?.name ?? post.authorName,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (post.media.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: WicchuNetworkImage(
                    url: post.media.first.previewUrl,
                    cacheKey: post.media.first.previewCacheKey,
                    width: 72,
                    height: 72,
                    decodeWidth: 240,
                    fit: BoxFit.cover,
                    loadingBuilder: (_) => const SizedBox.square(
                      dimension: 72,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    errorBuilder: (_) => CommunityAvatar(
                      community: business ?? _fallbackBusiness(post),
                      radius: 26,
                    ),
                  ),
                )
              else
                CommunityAvatar(
                  community: business ?? _fallbackBusiness(post),
                  radius: 26,
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      business?.name ?? post.authorName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 5),
                    Text(detail, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              if (price.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  price,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Community _fallbackBusiness(CommunityPost post) => Community(
    id: post.communityId,
    name: post.authorName,
    description: '',
    town: const Town(id: '', name: '', countryCode: ''),
    visibility: CommunityVisibility.public,
    createdBy: post.authorId,
    createdAt: post.createdAt,
  );

  Widget _businessCard(Community business) {
    final services = business.businessServices
        .map((service) => context.tr(service.label))
        .take(3)
        .join(' · ');
    final distance = business.distanceKm;
    final subtitle = distance == null
        ? '${services.isEmpty ? context.tr('Local business') : services} · ${business.town.name}'
        : '${services.isEmpty ? context.tr('Local business') : services} · ${context.tr('{distance} km away', {'distance': distance.toStringAsFixed(distance < 10 ? 1 : 0)})}';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CommunityAvatar(community: business, radius: 25),
        title: Text(business.name),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => openResponsiveSidePanel<void>(
          context,
          builder: (_) => CommunityProfilePage(
            community: business,
            repository: widget.repository,
          ),
        ),
      ),
    );
  }

  Widget _emptyPublications() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 36),
    child: Column(
      children: [
        Icon(
          Icons.restaurant_menu_outlined,
          size: 56,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 12),
        Text(
          context.tr('No menus are available today.'),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );

  Widget _emptyBusinesses() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 36),
    child: Text(
      context.tr('No businesses match this category.'),
      textAlign: TextAlign.center,
    ),
  );

  String _dateTime(DateTime? value) {
    if (value == null) return '';
    final local = value.toLocal();
    return '${MaterialLocalizations.of(context).formatMediumDate(local)} · ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
  }

  String _locationSummary(Town town) => switch (_locationMode) {
    _DiscoveryLocationMode.town => context.tr(
      'Profiles and useful updates from {town}',
      {'town': town.name},
    ),
    _DiscoveryLocationMode.nearby => context.tr(
      'Businesses within {radius} km of your current location',
      {'radius': _radiusKm.toStringAsFixed(0)},
    ),
    _DiscoveryLocationMode.anywhere => context.tr(
      'Explore local businesses from every available town',
    ),
  };

  String _locationModeLabel(_DiscoveryLocationMode mode) => switch (mode) {
    _DiscoveryLocationMode.town => 'Choose town',
    _DiscoveryLocationMode.nearby => 'Near me',
    _DiscoveryLocationMode.anywhere => 'Anywhere',
  };

  IconData _locationModeIcon(_DiscoveryLocationMode mode) => switch (mode) {
    _DiscoveryLocationMode.town => Icons.location_city_outlined,
    _DiscoveryLocationMode.nearby => Icons.my_location_outlined,
    _DiscoveryLocationMode.anywhere => Icons.public_outlined,
  };

  String _categoryLabel(_DiscoveryCategory value) => switch (value) {
    _DiscoveryCategory.all => 'All',
    _DiscoveryCategory.food => 'Food',
    _DiscoveryCategory.transport => 'Transport',
    _DiscoveryCategory.retail => 'Shops',
    _DiscoveryCategory.properties => 'Properties',
    _DiscoveryCategory.services => 'Services',
    _DiscoveryCategory.beauty => 'Beauty',
    _DiscoveryCategory.health => 'Health',
  };

  IconData _categoryIcon(_DiscoveryCategory value) => switch (value) {
    _DiscoveryCategory.all => Icons.explore_outlined,
    _DiscoveryCategory.food => Icons.restaurant_outlined,
    _DiscoveryCategory.transport => Icons.directions_bus_outlined,
    _DiscoveryCategory.retail => Icons.storefront_outlined,
    _DiscoveryCategory.properties => Icons.apartment_outlined,
    _DiscoveryCategory.services => Icons.home_repair_service_outlined,
    _DiscoveryCategory.beauty => Icons.spa_outlined,
    _DiscoveryCategory.health => Icons.health_and_safety_outlined,
  };
}

class _DiscoveryData {
  const _DiscoveryData({
    required this.towns,
    required this.communities,
    required this.posts,
  });
  final List<Town> towns;
  final List<Community> communities;
  final List<CommunityPost> posts;
}

class _DiscoveryMessage extends StatelessWidget {
  const _DiscoveryMessage({
    required this.icon,
    required this.title,
    this.action,
  });
  final IconData icon;
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.all(40),
    children: [
      Icon(icon, size: 64),
      const SizedBox(height: 16),
      Text(title, textAlign: TextAlign.center),
      ?action,
    ],
  );
}
