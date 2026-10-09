import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';
import '../../theme/wicchu_icons.dart';

class PageLocationDraft {
  const PageLocationDraft(
    this.town,
    this.address,
    this.latitude,
    this.longitude,
    this.showExactAddress,
  );
  final Town town;
  final String address;
  final double? latitude;
  final double? longitude;
  final bool showExactAddress;
}

class PageLocationSettingsPage extends StatefulWidget {
  const PageLocationSettingsPage({
    super.key,
    required this.community,
    required this.repository,
    required this.initial,
  });
  final Community community;
  final CommunityRepository repository;
  final PageLocationDraft initial;
  @override
  State<PageLocationSettingsPage> createState() =>
      _PageLocationSettingsPageState();
}

class _PageLocationSettingsPageState extends State<PageLocationSettingsPage> {
  late Town _town = widget.initial.town;
  late final _businessAddress = TextEditingController(
    text: widget.initial.address,
  );
  late double? _businessLatitude = widget.initial.latitude;
  late double? _businessLongitude = widget.initial.longitude;
  late bool _showExactBusinessAddress = widget.initial.showExactAddress;
  late Future<List<Town>> _towns = widget.repository.listTowns();
  bool _locatingTown = false;
  bool _locatingBusiness = false;
  bool _allowPop = false;
  bool _confirming = false;
  bool get _saving => _locatingTown || _locatingBusiness;
  bool get _dirty =>
      _town.id != widget.initial.town.id ||
      _businessAddress.text != widget.initial.address ||
      _businessLatitude != widget.initial.latitude ||
      _businessLongitude != widget.initial.longitude ||
      _showExactBusinessAddress != widget.initial.showExactAddress;

  @override
  void initState() {
    super.initState();
    _businessAddress.addListener(_changed);
  }

  void _changed() => setState(() {});
  @override
  void dispose() {
    _businessAddress.dispose();
    super.dispose();
  }

  void _finish(bool apply) {
    final result = apply
        ? PageLocationDraft(
            _town,
            _businessAddress.text,
            _businessLatitude,
            _businessLongitude,
            _showExactBusinessAddress,
          )
        : null;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context, result);
    });
  }

  Future<void> _leave() async {
    if (_saving || _confirming) return;
    if (!_dirty) {
      _finish(false);
      return;
    }
    _confirming = true;
    final apply = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Unsaved changes')),
        content: Text(context.tr('Finish by saving changes in settings.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('Keep editing')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('Discard')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('Apply')),
          ),
        ],
      ),
    );
    _confirming = false;
    if (mounted && apply != null) _finish(apply);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop || (!_dirty && !_saving),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _leave();
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Location')),
        leading: BackButton(onPressed: _leave),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            context.tr(
              widget.community.isPublicProfile
                  ? 'Business location'
                  : 'Community location',
            ),
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: FutureBuilder<List<Town>>(
                  future: _towns,
                  builder: (context, snapshot) {
                    final towns = <Town>[
                      _town,
                      for (final town in snapshot.data ?? const <Town>[])
                        if (town.id != _town.id) town,
                    ];
                    return DropdownButtonFormField<Town>(
                      key: ValueKey(_town.id),
                      initialValue: _town,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: context.tr('Town'),
                        isDense: true,
                        prefixIcon: const Icon(WicchuIcons.buildings, size: 20),
                      ),
                      items: [
                        for (final town in towns)
                          DropdownMenuItem(
                            value: town,
                            child: Text(
                              '${town.name} · ${town.countryCode}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: _saving
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() => _town = value);
                              }
                            },
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: context.tr('Use my current town'),
                onPressed: _locatingTown || _saving ? null : _useCurrentTown,
                color: Theme.of(context).colorScheme.primary,
                icon: _locatingTown
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(WicchuIcons.crosshair, size: 22),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 12),
            child: Text(
              context.tr(
                widget.community.isPublicProfile
                    ? 'Helps nearby people find your profile.'
                    : 'This location is used for discovery and local weather.',
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (widget.community.isPublicProfile) ...[
            TextFormField(
              controller: _businessAddress,
              maxLength: 300,
              decoration: InputDecoration(
                labelText: context.tr('Business address'),
                isDense: true,
                counterText: '',
                suffixIcon: IconButton(
                  tooltip: context.tr('Use my current location'),
                  onPressed: _locatingBusiness || _saving
                      ? null
                      : _useCurrentBusinessLocation,
                  color: Theme.of(context).colorScheme.primary,
                  icon: _locatingBusiness
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(WicchuIcons.crosshair, size: 22),
                ),
                prefixIcon: Icon(
                  WicchuIcons.mapPin,
                  color: Theme.of(context).colorScheme.primary,
                ),
                hintText: context.tr('Street, town, province'),
              ),
            ),
            if (_businessLatitude != null && _businessLongitude != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  context.tr('Map pin saved'),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(context.tr('Public exact location')),
              subtitle: Text(
                context.tr(
                  'When disabled, visitors only see the profile town.',
                ),
              ),
              value: _showExactBusinessAddress,
              onChanged: (value) =>
                  setState(() => _showExactBusinessAddress = value),
            ),
          ],

          const SizedBox(height: 16),
          Text(
            context.tr('Finish by saving changes in settings.'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton(
          onPressed: _saving ? null : () => _finish(true),
          child: Text(context.tr('Apply')),
        ),
      ),
    ),
  );
  Future<void> _useCurrentTown() async {
    setState(() => _locatingTown = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Turn on location services and try again.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission is required.');
      }
      final position = await Geolocator.getCurrentPosition();
      final town = await widget.repository.locateTown(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (!mounted) return;
      setState(() {
        _town = town;
        _towns = widget.repository.listTowns();
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    } finally {
      if (mounted) setState(() => _locatingTown = false);
    }
  }

  Future<void> _useCurrentBusinessLocation() async {
    setState(() => _locatingBusiness = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission is required.');
      }
      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _businessLatitude = position.latitude;
          _businessLongitude = position.longitude;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    } finally {
      if (mounted) setState(() => _locatingBusiness = false);
    }
  }
}
