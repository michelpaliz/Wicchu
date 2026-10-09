import 'package:wicchu/theme/wicchu_icons.dart';
import '../../widgets/explore_result_card.dart';
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
    this.onLocationChanged,
    this.externalFilters = false,
    this.externalCategories = false,
    this.onCategoriesChanged,
  });

  final CommunityRepository repository;
  final String initialQuery;
  final bool externalFilters;
  final bool externalCategories;
  final VoidCallback? onCategoriesChanged;
  final void Function(String? townId, Position? position, double radiusKm)?
  onLocationChanged;

  @override
  State<LocalDiscoveryView> createState() => LocalDiscoveryViewState();
}

class LocalDiscoveryViewState extends State<LocalDiscoveryView> {
  late Future<_DiscoveryData> _data = _initialize();
  final _categories = <_DiscoveryCategory>{};
  _DiscoveryCategory get _category =>
      _categories.length == 1 ? _categories.first : _DiscoveryCategory.all;
  set _category(_DiscoveryCategory value) {
    _categories.clear();
    if (value != _DiscoveryCategory.all) _categories.add(value);
  }

  bool _selected(_DiscoveryCategory value) => value == _DiscoveryCategory.all
      ? _categories.isEmpty
      : _categories.contains(value);
  bool _includes(_DiscoveryCategory value) =>
      _categories.isEmpty || _categories.contains(value);
  void _toggleCategory(_DiscoveryCategory value) {
    if (value == _DiscoveryCategory.all) {
      _categories.clear();
    } else if (!_categories.remove(value)) {
      _categories.add(value);
    }
    _showFoodBusinesses = false;
    if (!_includes(_DiscoveryCategory.food) &&
        !_includes(_DiscoveryCategory.retail)) {
      _delivery = false;
      _pickup = false;
    }
    if (!_includes(_DiscoveryCategory.food)) _openNow = false;
    if (!_includes(_DiscoveryCategory.transport)) _departureDay = 0;
    if (!_includes(_DiscoveryCategory.properties)) _listingType = '';
  }

  Future<void> _saveBusinessFilters() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'business_filter_categories',
      _categories.map((item) => item.name).toList(),
    );
    await prefs.setBool('business_filter_delivery', _delivery);
    await prefs.setBool('business_filter_pickup', _pickup);
    await prefs.setBool('business_filter_open', _openNow);
    await prefs.setInt('business_filter_departure', _departureDay);
    await prefs.setString('business_filter_listing', _listingType);
    if (_maxPrice == null) {
      await prefs.remove('business_filter_price');
    } else {
      await prefs.setDouble('business_filter_price', _maxPrice!);
    }
  }

  _DiscoveryLocationMode _locationMode = _DiscoveryLocationMode.anywhere;
  String? _townId;
  String? _townName;
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

  @override
  void didUpdateWidget(covariant LocalDiscoveryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialQuery != widget.initialQuery) _data = _load();
  }

  Widget buildCategoryBar() {
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final item in _DiscoveryCategory.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                selected: _selected(item),
                side: BorderSide(
                  color: _selected(item)
                      ? colors.primary
                      : colors.outlineVariant.withValues(alpha: .3),
                ),
                shape: const StadiumBorder(),
                backgroundColor: colors.surface,
                selectedColor: colors.primary,
                showCheckmark: false,
                avatar: item == _DiscoveryCategory.all
                    ? Icon(
                        WicchuIcons.squaresFour,
                        size: 18,
                        color: _selected(item)
                            ? colors.onPrimary
                            : colors.primary,
                      )
                    : Icon(
                        _categoryIcon(item),
                        size: 18,
                        color: _selected(item)
                            ? colors.onPrimary
                            : colors.primary,
                      ),
                labelStyle: TextStyle(
                  color: _selected(item) ? colors.onPrimary : colors.onSurface,
                ),
                label: Text(context.tr(_categoryLabel(item))),
                onSelected: (_) => setState(() {
                  _toggleCategory(item);
                  _saveBusinessFilters();
                  widget.onCategoriesChanged?.call();
                }),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> openFilters({bool locationOnly = false}) async {
    try {
      final data = await _data;
      if (mounted) {
        await _showFilters(data.towns, locationOnly: locationOnly);
        if (mounted) widget.onCategoriesChanged?.call();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Could not load local discovery.')),
          ),
        );
      }
    }
  }

  Future<_DiscoveryData> _initialize() async {
    final preferences = await SharedPreferences.getInstance();
    final savedCategories =
        preferences.getStringList('business_filter_categories') ?? [];
    _categories.addAll(
      _DiscoveryCategory.values.where(
        (item) =>
            item != _DiscoveryCategory.all &&
            savedCategories.contains(item.name),
      ),
    );
    _delivery = preferences.getBool('business_filter_delivery') ?? false;
    _pickup = preferences.getBool('business_filter_pickup') ?? false;
    _openNow = preferences.getBool('business_filter_open') ?? false;
    _departureDay = preferences.getInt('business_filter_departure') ?? 0;
    _listingType = preferences.getString('business_filter_listing') ?? '';
    _maxPrice = preferences.getDouble('business_filter_price');
    _townId = preferences.getString('business_discovery_town_id');
    _radiusKm = preferences.getDouble('business_discovery_radius_km') ?? 10;
    _locationMode = switch (preferences.getString(
      'business_discovery_location_mode',
    )) {
      'nearby' => _DiscoveryLocationMode.nearby,
      'town' => _DiscoveryLocationMode.town,
      _ => _DiscoveryLocationMode.anywhere,
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
    _townName = town.name;
    if (mounted &&
        (_locationMode != _DiscoveryLocationMode.nearby || _position != null)) {
      widget.onLocationChanged?.call(
        _locationMode == _DiscoveryLocationMode.town ? town.id : null,
        _locationMode == _DiscoveryLocationMode.nearby ? _position : null,
        _radiusKm,
      );
    }
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
    if (value == null) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('business_discovery_town_id', value);
    await preferences.setString('business_discovery_location_mode', 'town');
    if (!mounted) return;
    setState(() {
      _townId = value;
      _locationMode = _DiscoveryLocationMode.town;
      _locationError = null;
      widget.onLocationChanged?.call(value, null, _radiusKm);
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
        if (position != null) {
          widget.onLocationChanged?.call(null, position, _radiusKm);
        }
        _data = _load();
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _locationMode = mode;
      _locationError = null;
      widget.onLocationChanged?.call(
        mode == _DiscoveryLocationMode.town ? _townId : null,
        null,
        _radiusKm,
      );
      _data = _load();
    });
  }

  Future<void> _selectRadius(double radiusKm) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setDouble('business_discovery_radius_km', radiusKm);
    if (!mounted) return;
    setState(() {
      _radiusKm = radiusKm;
      widget.onLocationChanged?.call(null, _position, radiusKm);
      _data = _load();
    });
  }

  bool _matchesCategory(CommunityPost post) =>
      _categories.isEmpty ||
      _categories.any((category) => _matchesCategoryValue(post, category));

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
          icon: WicchuIcons.cloudSlash,
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
          icon: WicchuIcons.mapPinSlash,
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
      final theme = Theme.of(context);
      final colors = theme.colorScheme;
      return Theme(
        data: theme.copyWith(
          chipTheme: theme.chipTheme.copyWith(
            shape: const StadiumBorder(),
            side: BorderSide(
              color: colors.outlineVariant.withValues(alpha: .5),
            ),
            backgroundColor: colors.surface,
            selectedColor: colors.primary,
            showCheckmark: false,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            labelStyle: theme.textTheme.labelLarge,
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            key: const ValueKey('local-discovery-results'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
            children: [
              if (!widget.externalFilters)
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    key: const ValueKey('discovery-location-filters'),
                    tooltip: context.tr('Location'),
                    onPressed: () => openFilters(locationOnly: true),
                    icon: const Icon(WicchuIcons.mapPin),
                  ),
                ),
              if (_locationError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        WicchuIcons.mapPinSlash,
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

              if (_locationError != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => _chooseLocation(data.towns),
                    child: Text(context.tr('Choose town')),
                  ),
                ),
              if (!widget.externalCategories) buildCategoryBar(),
              SizedBox(height: widget.externalCategories ? 2 : 8),
              if (_category == _DiscoveryCategory.food) ...[
                if (!_showFoodBusinesses)
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      key: const ValueKey('discovery-filters'),
                      tooltip: context.tr('Filters'),
                      onPressed: () => openFilters(),
                      icon: const Icon(WicchuIcons.slidersHorizontal),
                    ),
                  ),
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(
                      value: false,
                      icon: const Icon(WicchuIcons.forkKnife),
                      label: Text(context.tr("Today's menus")),
                    ),
                    ButtonSegment(
                      value: true,
                      icon: const Icon(WicchuIcons.storefront),
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
                ..._businessDirectory(businesses),
                if (_category == _DiscoveryCategory.all)
                  ..._overviewSections(posts, communityById)
                else if (posts.isNotEmpty)
                  ...posts.map(
                    (post) => _postCard(post, communityById[post.communityId]),
                  ),
              ],
            ],
          ),
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

  bool _matchesBusinessCategory(Community business) =>
      _categories.isEmpty ||
      _categories.any((category) => _businessHasCategory(business, category));

  bool _businessHasCategory(Community business, _DiscoveryCategory category) {
    final services = business.businessServices;
    return switch (category) {
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
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${context.trCount(filtered.length, singular: '{count} business found', plural: '{count} businesses found')}'
                '${_locationMode == _DiscoveryLocationMode.town && _townName != null
                    ? ' · $_townName'
                    : _locationMode == _DiscoveryLocationMode.nearby
                    ? ' · ${context.tr('Near me')}'
                    : ''}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            IconButton(
              key: const ValueKey('discovery-filters'),
              tooltip: context.tr('Filters'),
              onPressed: () => openFilters(),
              icon: Badge(
                isLabelVisible: _activeFilters > 0,
                label: Text('$_activeFilters'),
                child: Icon(
                  WicchuIcons.slidersHorizontal,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
      if (filtered.isEmpty)
        _emptyBusinesses()
      else
        ...filtered.map(_businessCard),
    ];
  }

  int get _activeFilters => [
    _delivery,
    _pickup,
    _openNow,
    _departureDay != 0,
    _listingType.isNotEmpty,
    _maxPrice != null,
  ].where((value) => value).length;

  Future<void> _chooseLocation(List<Town> towns) {
    var query = '';
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, refresh) => ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * .7,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(title: Text(context.tr('Choose town'))),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: context.tr('Search towns'),
                    prefixIcon: const Icon(WicchuIcons.magnifyingGlass),
                  ),
                  onChanged: (value) =>
                      refresh(() => query = value.trim().toLowerCase()),
                ),
              ),

              ListTile(
                leading: const Icon(WicchuIcons.globe),
                title: Text(context.tr('Anywhere')),
                onTap: () async {
                  await _selectLocationMode(_DiscoveryLocationMode.anywhere);
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
              ),
              for (final town in towns.where(
                (town) => town.name.toLowerCase().contains(query),
              ))
                ListTile(
                  leading: const Icon(WicchuIcons.mapPin),
                  title: Text(town.name),
                  trailing:
                      _townId == town.id &&
                          _locationMode == _DiscoveryLocationMode.town
                      ? const Icon(WicchuIcons.check)
                      : null,
                  onTap: () async {
                    await _selectTown(town.id);
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showFilters(
    List<Town> towns, {
    bool locationOnly = false,
  }) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, sheetState) {
        void update(VoidCallback change) {
          setState(change);
          sheetState(() {});
        }

        final theme = Theme.of(context);
        final colors = theme.colorScheme;
        Widget heading(String title) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            context.tr(title),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        );
        Widget divider() => Divider(
          height: 20,
          color: colors.outlineVariant.withValues(alpha: .5),
        );
        Future<void> mode(_DiscoveryLocationMode value) async {
          final result = _selectLocationMode(value);
          sheetState(() {});
          await result;
          if (context.mounted) sheetState(() {});
        }

        Widget location(
          String label,
          IconData icon,
          bool selected,
          VoidCallback? action,
        ) => OutlinedButton.icon(
          onPressed: action,
          icon: Icon(icon, size: 18),
          label: Text(label, textAlign: TextAlign.center),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 46),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            foregroundColor: selected ? colors.onPrimary : colors.primary,
            backgroundColor: selected ? colors.primary : colors.surface,
            side: BorderSide(
              color: selected ? colors.primary : colors.outlineVariant,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: theme.textTheme.labelMedium,
          ),
        );
        return Theme(
          data: theme.copyWith(
            chipTheme: theme.chipTheme.copyWith(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              side: BorderSide(color: colors.outlineVariant),
              backgroundColor: colors.surface,
              selectedColor: colors.primary,
              secondarySelectedColor: colors.primary,
              secondaryLabelStyle: TextStyle(color: colors.onPrimary),
              checkmarkColor: colors.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            ),
          ),
          child: SizedBox(
            height:
                MediaQuery.sizeOf(context).height * (locationOnly ? .58 : .45),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          locationOnly
                              ? context.tr('Location')
                              : '${context.tr('Filters')}${_activeFilters == 0 ? '' : ' ($_activeFilters)'}',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          update(() {
                            if (locationOnly) {
                              _radiusKm = 10;
                            } else {
                              _resetFilterValues();
                            }
                          });
                          if (!locationOnly) return;
                          final preferences =
                              await SharedPreferences.getInstance();
                          await preferences.setDouble(
                            'business_discovery_radius_km',
                            10,
                          );
                          await mode(_DiscoveryLocationMode.town);
                        },
                        child: Text(context.tr('Reset filters')),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (locationOnly) ...[
                          heading('Location'),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: location(
                                  context.tr('Near me'),
                                  WicchuIcons.crosshair,
                                  _locationMode ==
                                      _DiscoveryLocationMode.nearby,
                                  _locating
                                      ? null
                                      : () =>
                                            mode(_DiscoveryLocationMode.nearby),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: location(
                                  towns
                                          .where((town) => town.id == _townId)
                                          .firstOrNull
                                          ?.name ??
                                      context.tr('Choose town'),
                                  WicchuIcons.mapPin,
                                  _locationMode == _DiscoveryLocationMode.town,
                                  () async {
                                    await _chooseLocation(towns);
                                    if (context.mounted) sheetState(() {});
                                  },
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: location(
                                  context.tr('Anywhere'),
                                  WicchuIcons.globe,
                                  _locationMode ==
                                      _DiscoveryLocationMode.anywhere,
                                  () => mode(_DiscoveryLocationMode.anywhere),
                                ),
                              ),
                            ],
                          ),
                          if (_locating) const LinearProgressIndicator(),
                          if (_locationError != null)
                            Text(context.tr(_locationError!)),
                        ],
                        if (!locationOnly) ...[
                          heading('Services'),
                          _filterBar(update),
                        ],
                        if (locationOnly &&
                            _locationMode == _DiscoveryLocationMode.nearby) ...[
                          divider(),
                          heading('Search radius'),
                          Row(
                            children: [
                              for (final radius in [1.0, 10.0, 50.0])
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: ChoiceChip(
                                      label: Center(
                                        child: Text('${radius.toInt()} km'),
                                      ),
                                      labelStyle: TextStyle(
                                        color: _radiusKm == radius
                                            ? colors.onPrimary
                                            : colors.onSurface,
                                      ),
                                      selected: _radiusKm == radius,
                                      onSelected: (_) async {
                                        await _selectRadius(radius);
                                        if (context.mounted) sheetState(() {});
                                      },
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 50),
                        ),
                        onPressed: () => Navigator.pop(sheetContext),
                        child: Text(context.tr('Show results')),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  ).whenComplete(_saveBusinessFilters);

  Widget _filterBar(StateSetter update) {
    final chips = <Widget>[];
    if (_includes(_DiscoveryCategory.food) ||
        _includes(_DiscoveryCategory.retail)) {
      chips.addAll([
        FilterChip(
          avatar: Icon(
            WicchuIcons.truck,
            size: 19,
            color: Theme.of(context).colorScheme.primary,
          ),
          showCheckmark: false,
          selectedColor: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: .1),
          labelStyle: TextStyle(
            color: _delivery
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface,
          ),
          label: Text(context.tr('Delivery')),
          selected: _delivery,
          onSelected: (value) => update(() => _delivery = value),
        ),
        FilterChip(
          avatar: Icon(
            WicchuIcons.tote,
            size: 19,
            color: Theme.of(context).colorScheme.primary,
          ),
          showCheckmark: false,
          selectedColor: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: .1),
          labelStyle: TextStyle(
            color: _pickup
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface,
          ),
          label: Text(context.tr('Pickup')),
          selected: _pickup,
          onSelected: (value) => update(() => _pickup = value),
        ),
      ]);
    }
    if (_includes(_DiscoveryCategory.food)) {
      chips.add(
        FilterChip(
          avatar: Icon(
            WicchuIcons.clock,
            size: 19,
            color: Theme.of(context).colorScheme.primary,
          ),
          showCheckmark: false,
          selectedColor: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: .1),
          labelStyle: TextStyle(
            color: _openNow
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface,
          ),
          label: Text(context.tr('Open now')),
          selected: _openNow,
          onSelected: (value) => update(() => _openNow = value),
        ),
      );
    }
    if (_category == _DiscoveryCategory.transport) {
      chips.addAll([
        ChoiceChip(
          label: Text(context.tr('Upcoming')),
          selected: _departureDay == 0,
          onSelected: (_) => update(() => _departureDay = 0),
        ),
        ChoiceChip(
          label: Text(context.tr('Today')),
          selected: _departureDay == 1,
          onSelected: (_) => update(() => _departureDay = 1),
        ),
        ChoiceChip(
          label: Text(context.tr('Tomorrow')),
          selected: _departureDay == 2,
          onSelected: (_) => update(() => _departureDay = 2),
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
            onSelected: (_) => update(() => _listingType = entry.key),
          ),
        );
      }
    }
    if (_category != _DiscoveryCategory.beauty &&
        _category != _DiscoveryCategory.health) {
      chips.add(
        ActionChip(
          avatar: const Icon(WicchuIcons.money, size: 18),
          label: Text(
            _maxPrice == null
                ? context.tr('Price')
                : context.tr('Up to {price}', {
                    'price': '\$${_maxPrice!.toStringAsFixed(0)}',
                  }),
          ),
          onPressed: () async {
            await _priceFilter();
            if (mounted) update(() {});
          },
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final chip in chips)
            SizedBox(width: (constraints.maxWidth - 8) / 2, child: chip),
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
              const Icon(WicchuIcons.caretRight),
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
    final distance =
        _locationMode == _DiscoveryLocationMode.nearby &&
            business.businessLocation?.hasCoordinates == true &&
            business.distanceKm != null &&
            business.distanceKm!.isFinite &&
            business.distanceKm! >= 0
        ? business.distanceKm
        : null;
    final subtitle = distance == null
        ? '${services.isEmpty ? context.tr('Local business') : services} · ${business.town.name}'
        : '${services.isEmpty ? context.tr('Local business') : services} · ${context.tr('{distance} km away', {'distance': distance.toStringAsFixed(distance < 10 ? 1 : 0)})}';
    final colors = Theme.of(context).colorScheme;
    final image = business.imageUrl?.trim().isNotEmpty == true
        ? business.imageUrl!
        : (business.coverImageUrl ?? '');
    Widget fallback() => Container(
      color: colors.primary.withValues(alpha: .09),
      child: Icon(WicchuIcons.storefront, color: colors.primary, size: 30),
    );
    return ExploreResultCard(
      margin: const EdgeInsets.only(bottom: 9),
      child: InkWell(
        onTap: () => openResponsiveSidePanel<void>(
          context,
          builder: (_) => CommunityProfilePage(
            community: business,
            repository: widget.repository,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 68,
                  height: 76,
                  child: image.isEmpty
                      ? fallback()
                      : WicchuNetworkImage(
                          url: image,
                          fit: BoxFit.cover,
                          decodeWidth: 240,
                          errorBuilder: (_) => fallback(),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      business.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    if (business.businessHours.isNotEmpty &&
                        _isOpenNow(business)) ...[
                      const SizedBox(height: 3),
                      Text(
                        '● ${context.tr('Open now')}',
                        style: TextStyle(fontSize: 12, color: colors.primary),
                      ),
                    ],
                    if (business.shortDescription.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        business.shortDescription.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (business.businessFulfillmentOptions.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          for (final option
                              in business.businessFulfillmentOptions)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colors.primary.withValues(alpha: .06),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                context.tr(option.label),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 4, left: 4),
                child: Icon(WicchuIcons.caretRight, size: 20),
              ),
            ],
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
          WicchuIcons.forkKnife,
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
    _DiscoveryCategory.all => WicchuIcons.compass,
    _DiscoveryCategory.food => WicchuIcons.forkKnife,
    _DiscoveryCategory.transport => WicchuIcons.bus,
    _DiscoveryCategory.retail => WicchuIcons.storefront,
    _DiscoveryCategory.properties => WicchuIcons.buildings,
    _DiscoveryCategory.services => WicchuIcons.briefcase,
    _DiscoveryCategory.beauty => WicchuIcons.leaf,
    _DiscoveryCategory.health => WicchuIcons.shieldPlus,
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
