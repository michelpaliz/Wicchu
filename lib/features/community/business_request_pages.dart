import 'business_dialog.dart';
import '../../services/post_image_preparation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../config/business_features.dart';
import '../../localization/app_language.dart';
import '../../theme/wicchu_icons.dart';
import '../../widgets/wicchu_network_image.dart';
import 'business_order_pages.dart';

String _requestMoney(int cents) => '\$${(cents / 100).toStringAsFixed(2)}';

class BusinessTransactionsPage extends StatefulWidget {
  const BusinessTransactionsPage({
    super.key,
    required this.businessId,
    required this.businessName,
    required this.repository,
  });

  final String businessId;
  final String businessName;
  final CommunityRepository repository;

  @override
  State<BusinessTransactionsPage> createState() =>
      _BusinessTransactionsPageState();
}

typedef _DashboardData = ({
  bool canManageOrders,
  bool canManageServices,
  List<BusinessOrder> orders,
  List<BusinessRequest> requests,
  Community business,
  BusinessCatalog catalog,
  BusinessRequestSettings settings,
});

class _BusinessTransactionsPageState extends State<BusinessTransactionsPage> {
  late Future<_DashboardData> _transactions = _load();

  Future<_DashboardData> _load() async {
    final business = await widget.repository.getCommunity(widget.businessId);
    final owner = business.myRole == CommunityRole.owner && !business.isBanned;
    final admin = business.myRole == CommunityRole.admin && !business.isBanned;
    final canManageOrders = owner || (admin && business.canManagePageOrders);
    final canManageServices =
        owner || (admin && business.canManagePageServices);
    final values = await Future.wait<Object>([
      canManageOrders && businessOrderingEnabled
          ? widget.repository.listManagedBusinessOrders(widget.businessId)
          : Future.value(<BusinessOrder>[]),
      canManageServices
          ? widget.repository.listManagedBusinessRequests(widget.businessId)
          : Future.value(<BusinessRequest>[]),
      canManageOrders
          ? widget.repository.getBusinessCatalog(
              widget.businessId,
              manage: true,
            )
          : Future.value(
              BusinessCatalog(
                businessId: widget.businessId,
                businessName: business.name,
              ),
            ),
      canManageServices
          ? widget.repository.getBusinessRequestSettings(widget.businessId)
          : Future.value(
              BusinessRequestSettings(
                businessId: widget.businessId,
                businessName: business.name,
              ),
            ),
    ]);
    return (
      canManageOrders: canManageOrders,
      canManageServices: canManageServices,
      orders: values[0] as List<BusinessOrder>,
      requests: values[1] as List<BusinessRequest>,
      business: business,
      catalog: values[2] as BusinessCatalog,
      settings: values[3] as BusinessRequestSettings,
    );
  }

  Future<void> _reload() async {
    if (!mounted) return;
    final next = _load();
    setState(() {
      _transactions = next;
    });
    try {
      await next;
    } catch (_) {
      // FutureBuilder displays the load error and retry action.
    }
  }

  Future<void> _open(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) await _reload();
  }

  Widget _catalogPage() => BusinessCatalogManagementPage(
    businessId: widget.businessId,
    businessName: widget.businessName,
    repository: widget.repository,
  );

  Widget _requestsPage() => BusinessRequestManagementPage(
    businessId: widget.businessId,
    businessName: widget.businessName,
    repository: widget.repository,
  );

  String _requestTitle(List<BusinessRequestType> types) {
    if (types.length != 1) return 'Service requests';
    return switch (types.single) {
      BusinessRequestType.quote => 'Quotes and services',
      BusinessRequestType.appointment => 'Appointments and bookings',
      BusinessRequestType.taxi => 'Ride requests',
      BusinessRequestType.service => 'Service requests',
    };
  }

  String _requestSubtitle(List<BusinessRequestType> types) {
    if (types.isEmpty) return 'Manage existing requests';
    if (types.length != 1) {
      return 'Manage customer requests and their status.';
    }
    return switch (types.single) {
      BusinessRequestType.quote => 'Manage quotes and services',
      BusinessRequestType.appointment => 'Manage appointments',
      BusinessRequestType.taxi => 'Manage ride requests',
      BusinessRequestType.service => 'Manage service requests',
    };
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        context.tr('Business dashboard'),
        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
      ),
    ),
    body: FutureBuilder<_DashboardData>(
      future: _transactions,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _RequestError(error: snapshot.error, onRetry: _reload);
        }
        final data = snapshot.data!;
        if (!data.canManageOrders && !data.canManageServices) {
          return Center(
            child: Text(
              context.tr('You do not have permission to manage this business.'),
            ),
          );
        }
        final orders = businessOrderingEnabled
            ? data.orders
            : const <BusinessOrder>[];
        final requests = data.requests;
        final food = data.business.businessServices.contains(
          BusinessService.food,
        );
        final retail = data.business.businessServices.contains(
          BusinessService.retail,
        );
        final productsEnabled =
            food ||
            retail ||
            data.catalog.products.isNotEmpty ||
            (businessOrderingEnabled && data.catalog.acceptingOrders);
        final requestsEnabled =
            data.settings.capabilities.isNotEmpty || requests.isNotEmpty;
        final productTitle = food
            ? (businessOrderingEnabled ? 'Menu and orders' : 'Menu')
            : (businessOrderingEnabled ? 'Products and sales' : 'Catalog');
        final pending =
            orders
                .where((o) => o.status == BusinessOrderStatus.pending)
                .length +
            requests
                .where((r) => r.status == BusinessRequestStatus.pending)
                .length;
        final scheduled = requests
            .where((r) => r.status == BusinessRequestStatus.scheduled)
            .length;
        final completed =
            orders
                .where((o) => o.status == BusinessOrderStatus.completed)
                .length +
            requests
                .where((r) => r.status == BusinessRequestStatus.completed)
                .length;
        final theme = Theme.of(context);
        Widget heading(String text) => Text(
          context.tr(text),
          style: theme.textTheme.titleSmall?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        );
        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              heading(
                businessOrderingEnabled
                    ? 'Overall activity'
                    : 'Request activity',
              ),
              const SizedBox(height: 4),
              Text(
                context.tr(
                  businessOrderingEnabled
                      ? 'Orders and service requests combined'
                      : 'Service requests and bookings',
                ),
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _DashboardCount(
                      label: context.tr('Pending items'),
                      count: pending,
                    ),
                  ),
                  Expanded(
                    child: _DashboardCount(
                      label: context.tr('Scheduled items'),
                      count: scheduled,
                    ),
                  ),
                  Expanded(
                    child: _DashboardCount(
                      label: context.tr('Completed items'),
                      count: completed,
                    ),
                  ),
                ],
              ),
              if (orders.isEmpty && requests.isEmpty) ...[
                const SizedBox(height: 20),
                heading('No requests yet'),
                const SizedBox(height: 4),
                Text(
                  context.tr(
                    businessOrderingEnabled
                        ? 'Customer orders and service requests will appear here.'
                        : 'Customer requests will appear here.',
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 13),
                ),
              ],
              const SizedBox(height: 24),
              heading('Manage business'),
              const SizedBox(height: 8),
              if (data.canManageOrders && productsEnabled)
                _destination(
                  icon: food ? WicchuIcons.forkKnife : WicchuIcons.receipt,
                  title: productTitle,
                  subtitle: food
                      ? (businessOrderingEnabled
                            ? 'Menus, catalog and orders'
                            : 'Menus, categories and availability')
                      : (businessOrderingEnabled
                            ? 'Catalog and customer orders'
                            : 'Products, categories and availability'),
                  count: businessOrderingEnabled ? orders.length : null,
                  page: _catalogPage(),
                ),
              if (data.canManageServices && requestsEnabled)
                _destination(
                  icon: WicchuIcons.clipboardText,
                  title: _requestTitle(data.settings.capabilities),
                  subtitle: _requestSubtitle(data.settings.capabilities),
                  count: requests.length,
                  page: _requestsPage(),
                ),
              if ((data.canManageOrders && !productsEnabled) ||
                  (data.canManageServices && !requestsEnabled)) ...[
                const SizedBox(height: 16),
                heading('Set up business features'),
                if (data.canManageOrders && !productsEnabled)
                  _destination(
                    icon: WicchuIcons.receipt,
                    title: businessOrderingEnabled
                        ? 'Set up product sales'
                        : 'Set up catalog',
                    subtitle: businessOrderingEnabled
                        ? 'Enable only if your business sells products.'
                        : 'Add products or menu items customers can browse.',
                    page: _catalogPage(),
                  ),
                if (data.canManageServices && !requestsEnabled)
                  _destination(
                    icon: WicchuIcons.clipboardText,
                    title: 'Set up service requests',
                    subtitle: 'Choose the services customers can request.',
                    page: BusinessRequestSettingsPage(
                      businessId: widget.businessId,
                      repository: widget.repository,
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    ),
  );

  Widget _destination({
    required IconData icon,
    required String title,
    required String subtitle,
    int? count,
    required Widget page,
  }) {
    final theme = Theme.of(context);
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          minVerticalPadding: 12,
          minTileHeight: 48,
          leading: Icon(icon, size: 22, color: theme.colorScheme.primary),
          title: Text(
            context.tr(title),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            context.tr(subtitle),
            style: const TextStyle(fontSize: 12, height: 1.4),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (count != null && count > 0) ...[
                Text('$count'),
                const SizedBox(width: 8),
              ],
              const Icon(WicchuIcons.caretRight, size: 18),
            ],
          ),
          onTap: () => _open(page),
        ),
        Divider(
          height: 1,
          thickness: .5,
          indent: 38,
          color: theme.colorScheme.onSurface.withValues(alpha: .1),
        ),
      ],
    );
  }
}

class _DashboardCount extends StatelessWidget {
  const _DashboardCount({required this.label, required this.count});
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
    child: Column(
      children: [
        Text(
          '$count',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    ),
  );
}

class BusinessRequestComposerPage extends StatefulWidget {
  const BusinessRequestComposerPage({
    super.key,
    required this.businessId,
    required this.repository,
    this.initialCapabilities = const [],
  });

  final String businessId;
  final CommunityRepository repository;
  final List<BusinessRequestType> initialCapabilities;

  @override
  State<BusinessRequestComposerPage> createState() =>
      _BusinessRequestComposerPageState();
}

class _BusinessRequestComposerPageState
    extends State<BusinessRequestComposerPage> {
  late Future<BusinessRequestSettings> _settings = widget.repository
      .getBusinessRequestSettings(widget.businessId);
  final _service = TextEditingController();
  final _description = TextEditingController();
  final _phone = TextEditingController();
  final _location = TextEditingController();
  final _destination = TextEditingController();
  final List<PostMedia> _photos = [];
  BusinessRequestType? _type;
  DateTime? _preferredAt;
  bool _sending = false;

  @override
  void dispose() {
    _service.dispose();
    _description.dispose();
    _phone.dispose();
    _location.dispose();
    _destination.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<BusinessRequestSettings>(
    future: _settings,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (snapshot.hasError) {
        return Scaffold(
          appBar: AppBar(),
          body: _RequestError(error: snapshot.error, onRetry: _reload),
        );
      }
      final settings = snapshot.data!;
      final capabilities = settings.capabilities.isNotEmpty
          ? settings.capabilities
          : widget.initialCapabilities;
      _type ??= capabilities.isEmpty ? null : capabilities.first;
      final businessName = settings.businessName == 'Local business'
          ? context.tr('Local business')
          : settings.businessName;
      return Scaffold(
        appBar: AppBar(title: Text(businessName)),
        body: !settings.acceptingRequests || capabilities.isEmpty
            ? _RequestEmpty(
                icon: WicchuIcons.clock,
                title: context.tr('Requests are currently closed'),
                body: context.tr(
                  'You can still contact or follow this business for updates.',
                ),
              )
            : _form(capabilities),
      );
    },
  );

  void _reload() => setState(
    () => _settings = widget.repository.getBusinessRequestSettings(
      widget.businessId,
    ),
  );

  Widget _form(List<BusinessRequestType> capabilities) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
    children: [
      Text(
        context.tr(_type?.actionLabel ?? 'Request service'),
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 14),
      if (capabilities.length > 1)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final type in capabilities)
              ChoiceChip(
                label: Text(context.tr(type.actionLabel)),
                selected: _type == type,
                onSelected: (_) => setState(() {
                  _type = type;
                  _preferredAt = null;
                }),
              ),
          ],
        ),
      if (capabilities.length > 1) const SizedBox(height: 14),
      TextField(
        controller: _service,
        maxLength: 120,
        decoration: InputDecoration(
          labelText: context.tr(_serviceLabel(_type!)),
          prefixIcon: Icon(_typeIcon(_type!)),
        ),
      ),
      if (_type == BusinessRequestType.taxi) ...[
        TextField(
          controller: _location,
          maxLength: 500,
          decoration: InputDecoration(
            labelText: context.tr('Pickup location'),
            prefixIcon: const Icon(WicchuIcons.mapPin),
          ),
        ),
        TextField(
          controller: _destination,
          maxLength: 500,
          decoration: InputDecoration(
            labelText: context.tr('Destination'),
            prefixIcon: const Icon(WicchuIcons.path),
          ),
        ),
      ] else ...[
        TextField(
          controller: _description,
          minLines: 3,
          maxLines: 6,
          maxLength: 2000,
          decoration: InputDecoration(
            labelText: context.tr('Describe what you need'),
            alignLabelWithHint: true,
          ),
        ),
        TextField(
          controller: _location,
          maxLength: 500,
          decoration: InputDecoration(
            labelText: context.tr('Service location (optional)'),
            prefixIcon: const Icon(WicchuIcons.mapPin),
          ),
        ),
      ],
      TextField(
        controller: _phone,
        keyboardType: TextInputType.phone,
        maxLength: 30,
        decoration: InputDecoration(
          labelText: context.tr('Contact phone (optional)'),
          prefixIcon: const Icon(WicchuIcons.phone),
        ),
      ),
      if (_type == BusinessRequestType.appointment ||
          _type == BusinessRequestType.service ||
          _type == BusinessRequestType.quote ||
          _type == BusinessRequestType.taxi)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(WicchuIcons.calendarBlank),
          title: Text(
            context.tr(
              _type == BusinessRequestType.taxi
                  ? 'When do you need the taxi?'
                  : 'Preferred date and time',
            ),
          ),
          subtitle: Text(
            _preferredAt == null
                ? context.tr(
                    _type == BusinessRequestType.appointment
                        ? 'Required'
                        : 'As soon as possible',
                  )
                : MaterialLocalizations.of(
                    context,
                  ).formatMediumDate(_preferredAt!),
          ),
          trailing: _preferredAt == null
              ? const Icon(WicchuIcons.caretRight)
              : IconButton(
                  onPressed: () => setState(() => _preferredAt = null),
                  icon: const Icon(WicchuIcons.xCircle),
                ),
          onTap: _chooseDateTime,
        ),
      if (_type != BusinessRequestType.taxi) ...[
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _sending || _photos.length >= 5 ? null : _addPhoto,
          icon: const Icon(WicchuIcons.imageSquare),
          label: Text(
            context.tr(
              _photos.isEmpty
                  ? 'Add photos (optional)'
                  : '{count} photos selected',
              {'count': '${_photos.length}'},
            ),
          ),
        ),
      ],
      const SizedBox(height: 20),
      FilledButton.icon(
        onPressed: _sending ? null : _submit,
        icon: _sending
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(WicchuIcons.paperPlaneTilt),
        label: Text(context.tr(_sending ? 'Sending…' : 'Send request')),
      ),
    ],
  );

  Future<void> _chooseDateTime() async {
    final now = DateTime.now();
    final day = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
      initialDate: _preferredAt ?? now,
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: _preferredAt == null
          ? TimeOfDay.now()
          : TimeOfDay.fromDateTime(_preferredAt!),
    );
    if (time == null || !mounted) return;
    setState(
      () => _preferredAt = DateTime(
        day.year,
        day.month,
        day.day,
        time.hour,
        time.minute,
      ),
    );
  }

  Future<void> _addPhoto() async {
    if (_sending || _photos.length >= 5) return;
    setState(() => _sending = true);
    try {
      final files = await ImagePicker().pickMultiImage(
        maxWidth: 4096,
        maxHeight: 4096,
        requestFullMetadata: false,
        limit: 5 - _photos.length,
      );
      if (!mounted) return;
      for (final file in files.take(5 - _photos.length)) {
        final prepared = await preparePostImage(
          await file.readAsBytes(),
          file.name,
        );
        if (!mounted) return;
        final media = await widget.repository.uploadPostMedia(
          bytes: prepared.bytes,
          filename: prepared.filename,
          mimeType: prepared.mimeType,
        );
        if (!mounted) return;
        setState(() => _photos.add(media));
      }
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _submit() async {
    if (_sending) return;
    final type = _type!;
    if (_service.text.trim().isEmpty ||
        (type == BusinessRequestType.taxi &&
            (_location.text.trim().isEmpty ||
                _destination.text.trim().isEmpty)) ||
        (type != BusinessRequestType.taxi &&
            type != BusinessRequestType.appointment &&
            _description.text.trim().isEmpty) ||
        (type == BusinessRequestType.appointment && _preferredAt == null)) {
      _showError(context.tr('Complete the required fields.'));
      return;
    }
    setState(() => _sending = true);
    try {
      final request = await widget.repository.createBusinessRequest(
        widget.businessId,
        BusinessRequestInput(
          type: type,
          serviceName: _service.text.trim(),
          description: _description.text.trim(),
          contactPhone: _phone.text.trim(),
          location: _location.text.trim(),
          destination: _destination.text.trim(),
          preferredAt: _preferredAt,
          attachmentBlobNames: _photos
              .map((photo) => photo.blobName)
              .whereType<String>()
              .toList(),
        ),
      );
      if (!mounted) return;
      setState(() => _sending = false);
      await showBusinessDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(WicchuIcons.checkCircle),
          title: Text(context.tr('Request sent')),
          content: Text(
            context.tr(
              'Request #{number} is waiting for the business to respond.',
              {'number': '${request.requestNumber}'},
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.tr('Done')),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context, request);
    } catch (error) {
      if (!mounted) return;
      setState(() => _sending = false);
      _showError(error);
    }
  }

  void _showError(Object error) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(context.trError(error))));
}

class MyBusinessRequestsPage extends StatefulWidget {
  const MyBusinessRequestsPage({super.key, required this.repository});
  final CommunityRepository repository;

  @override
  State<MyBusinessRequestsPage> createState() => _MyBusinessRequestsPageState();
}

class _MyBusinessRequestsPageState extends State<MyBusinessRequestsPage> {
  late Future<List<BusinessRequest>> _requests = _load();
  Future<List<BusinessRequest>> _load() =>
      widget.repository.listMyBusinessRequests();
  void _reload() {
    if (!mounted) return;
    setState(() {
      _requests = _load();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('My requests'))),
    body: FutureBuilder<List<BusinessRequest>>(
      future: _requests,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _RequestError(error: snapshot.error, onRetry: _reload);
        }
        final requests = snapshot.data!;
        if (requests.isEmpty) {
          return _RequestEmpty(
            icon: WicchuIcons.clipboardText,
            title: context.tr('No requests yet'),
            body: context.tr('Your service requests will appear here.'),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final request in requests)
                _BusinessRequestCard(
                  request: request,
                  customerView: true,
                  onAction: _canCustomerCancel(request.status)
                      ? (_) async {
                          try {
                            await widget.repository.cancelBusinessRequest(
                              request.id,
                            );
                            _reload();
                          } catch (error) {
                            if (mounted) _showRequestError(this.context, error);
                          }
                        }
                      : null,
                ),
            ],
          ),
        );
      },
    ),
  );
}

class BusinessRequestManagementPage extends StatefulWidget {
  const BusinessRequestManagementPage({
    super.key,
    required this.businessId,
    required this.businessName,
    required this.repository,
  });

  final String businessId;
  final String businessName;
  final CommunityRepository repository;

  @override
  State<BusinessRequestManagementPage> createState() =>
      _BusinessRequestManagementPageState();
}

class _BusinessRequestManagementPageState
    extends State<BusinessRequestManagementPage> {
  late Future<(List<BusinessRequest>, BusinessRequestSettings)> _requests =
      _load();
  BusinessRequestStatus? _filter;
  Future<(List<BusinessRequest>, BusinessRequestSettings)> _load() async {
    final values = await Future.wait<Object>([
      widget.repository.listManagedBusinessRequests(widget.businessId),
      widget.repository.getBusinessRequestSettings(widget.businessId),
    ]);
    return (
      values[0] as List<BusinessRequest>,
      values[1] as BusinessRequestSettings,
    );
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _requests = _load();
    });
  }

  Future<void> _configure() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BusinessRequestSettingsPage(
          businessId: widget.businessId,
          repository: widget.repository,
        ),
      ),
    );
    _reload();
  }

  Widget _empty(String title, String body, {bool configure = false}) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            WicchuIcons.clipboardText,
            size: 32,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            context.tr(title),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr(body),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
          if (configure) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _configure,
              child: Text(context.tr('Configure requests')),
            ),
          ],
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        context.tr('Business requests'),
        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
      ),
      actions: [
        IconButton(
          tooltip: context.tr('Request settings'),
          onPressed: _configure,
          icon: const Icon(WicchuIcons.gearSix),
        ),
      ],
    ),
    body: FutureBuilder<(List<BusinessRequest>, BusinessRequestSettings)>(
      future: _requests,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(context.tr('Could not load requests')),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _reload,
                  child: Text(context.tr('Retry')),
                ),
              ],
            ),
          );
        }
        final (requests, settings) = snapshot.data!;
        if (requests.isEmpty) {
          if (settings.capabilities.isEmpty) {
            return _empty(
              'Enable your services to receive requests',
              'Choose which services to offer to start receiving customer requests.',
              configure: true,
            );
          }
          if (!settings.acceptingRequests) {
            return _empty(
              'Requests are paused',
              'Enable requests when you are ready to receive customers.',
              configure: true,
            );
          }
          return _empty(
            'You have not received any requests yet',
            settings.capabilities
                .map((type) => context.tr(type.actionLabel))
                .join(' · '),
          );
        }
        final visible = requests
            .where((r) => _filter == null || r.status == _filter)
            .toList();
        return Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  for (final entry in <BusinessRequestStatus?, String>{
                    null: 'All',
                    BusinessRequestStatus.pending: 'Pending items',
                    BusinessRequestStatus.scheduled: 'Scheduled items',
                  }.entries)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Builder(
                        builder: (context) {
                          final selected = _filter == entry.key;
                          final colors = Theme.of(context).colorScheme;
                          return ChoiceChip(
                            label: Text(context.tr(entry.value)),
                            labelStyle: TextStyle(
                              fontSize: 13,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: selected
                                  ? colors.onPrimaryContainer
                                  : colors.onSurfaceVariant,
                            ),
                            selected: selected,
                            showCheckmark: false,
                            side: BorderSide.none,
                            backgroundColor: Colors.transparent,
                            selectedColor: colors.primaryContainer,
                            visualDensity: VisualDensity.compact,
                            shape: const StadiumBorder(),
                            onSelected: (_) =>
                                setState(() => _filter = entry.key),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: visible.isEmpty
                  ? _empty(
                      'No requests in this category',
                      'Choose another status to see your requests.',
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        _reload();
                        await _requests;
                      },
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          for (final request in visible)
                            _BusinessRequestCard(
                              request: request,
                              onAction: (status) =>
                                  _changeStatus(request, status),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        );
      },
    ),
  );

  Future<void> _changeStatus(
    BusinessRequest request,
    BusinessRequestStatus status,
  ) async {
    String message = '';
    DateTime? scheduledAt;
    int? quote;
    if (status == BusinessRequestStatus.rejected) {
      message =
          await _requestTextDialog(
            context,
            title: context.tr('Reject request'),
            label: context.tr('Reason for the customer'),
          ) ??
          '';
      if (message.isEmpty) return;
    } else if (status == BusinessRequestStatus.quoted) {
      final value = await _requestTextDialog(
        context,
        title: context.tr('Send quote'),
        label: context.tr('Price (USD)'),
        number: true,
      );
      final amount = double.tryParse(value?.replaceAll(',', '.') ?? '');
      if (amount == null || amount < 0) return;
      quote = (amount * 100).round();
    } else if (status == BusinessRequestStatus.scheduled) {
      scheduledAt = await _pickRequestDateTime(context);
      if (scheduledAt == null) return;
    }
    try {
      await widget.repository.updateBusinessRequestStatus(
        request.id,
        status,
        message: message,
        scheduledAt: scheduledAt,
        quotedPriceCents: quote,
      );
      _reload();
    } catch (error) {
      if (mounted) _showRequestError(context, error);
    }
  }
}

class BusinessRequestSettingsPage extends StatefulWidget {
  const BusinessRequestSettingsPage({
    super.key,
    required this.businessId,
    required this.repository,
  });

  final String businessId;
  final CommunityRepository repository;

  @override
  State<BusinessRequestSettingsPage> createState() =>
      _BusinessRequestSettingsPageState();
}

class _BusinessRequestSettingsPageState
    extends State<BusinessRequestSettingsPage> {
  late Future<BusinessRequestSettings> _settings = widget.repository
      .getBusinessRequestSettings(widget.businessId);
  bool _saving = false;

  @override
  Widget build(BuildContext context) => FutureBuilder<BusinessRequestSettings>(
    future: _settings,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (snapshot.hasError) {
        return Scaffold(
          appBar: AppBar(),
          body: _RequestError(
            error: snapshot.error,
            onRetry: () => setState(() {
              _settings = widget.repository.getBusinessRequestSettings(
                widget.businessId,
              );
            }),
          ),
        );
      }
      return _settingsBody(snapshot.data!);
    },
  );

  Widget _settingsBody(BusinessRequestSettings initial) {
    var accepting = initial.acceptingRequests;
    final selected = initial.capabilities.toSet();
    return StatefulBuilder(
      builder: (context, setPageState) => Scaffold(
        appBar: AppBar(title: Text(context.tr('Request settings'))),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: accepting,
              title: Text(context.tr('Accepting requests')),
              subtitle: Text(
                context.tr('Customers can submit the enabled request types.'),
              ),
              onChanged: _saving
                  ? null
                  : (value) => setPageState(() => accepting = value),
            ),
            const Divider(),
            Text(
              context.tr('Supported actions'),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            for (final type in BusinessRequestType.values)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: selected.contains(type),
                title: Text(context.tr(type.actionLabel)),
                secondary: Icon(_typeIcon(type)),
                onChanged: _saving
                    ? null
                    : (value) => setPageState(() {
                        if (value == true) {
                          selected.add(type);
                        } else {
                          selected.remove(type);
                          if (selected.isEmpty) accepting = false;
                        }
                      }),
              ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _saving
                ? null
                : () async {
                    if (accepting && selected.isEmpty) {
                      _showRequestError(
                        context,
                        context.tr('Enable at least one request type.'),
                      );
                      return;
                    }
                    setPageState(() => _saving = true);
                    try {
                      await widget.repository.updateBusinessRequestSettings(
                        widget.businessId,
                        acceptingRequests: accepting,
                        capabilities: selected.toList(),
                      );
                      if (context.mounted) Navigator.pop(context);
                    } catch (error) {
                      setPageState(() => _saving = false);
                      if (context.mounted) _showRequestError(context, error);
                    }
                  },
            icon: const Icon(WicchuIcons.floppyDisk),
            label: Text(context.tr('Save')),
          ),
        ),
      ),
    );
  }
}

class _BusinessRequestCard extends StatelessWidget {
  const _BusinessRequestCard({
    required this.request,
    this.onAction,
    this.customerView = false,
  });

  final BusinessRequest request;
  final ValueChanged<BusinessRequestStatus>? onAction;
  final bool customerView;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_typeIcon(request.type)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${request.businessName.isNotEmpty ? '${request.businessName} · ' : ''}#BR-${request.requestNumber}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Chip(
                label: Text(context.tr(_requestStatusLabel(request.status))),
              ),
            ],
          ),
          Text(
            request.serviceName,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (request.customerName.isNotEmpty) Text(request.customerName),
          if (request.description.isNotEmpty) Text(request.description),
          if (request.location.isNotEmpty)
            Text('${context.tr('Location')}: ${request.location}'),
          if (request.destination.isNotEmpty)
            Text('${context.tr('Destination')}: ${request.destination}'),
          if (request.quotedPriceCents case final price?)
            Text(
              '${context.tr('Quote')}: ${_requestMoney(price)}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          if (request.businessMessage.isNotEmpty) Text(request.businessMessage),
          if (request.attachments.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 70,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: request.attachments.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, index) => ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: WicchuNetworkImage(
                    url: request.attachments[index].url,
                    width: 70,
                    height: 70,
                    decodeWidth: 200,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ],
          if (onAction != null) ...[
            const SizedBox(height: 12),
            if (customerView)
              OutlinedButton(
                onPressed: () => onAction!(BusinessRequestStatus.cancelled),
                child: Text(context.tr('Cancel request')),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final status in _managerActions(request))
                    status == BusinessRequestStatus.rejected
                        ? OutlinedButton(
                            onPressed: () => onAction!(status),
                            child: Text(context.tr('Reject')),
                          )
                        : FilledButton.tonal(
                            onPressed: () => onAction!(status),
                            child: Text(
                              context.tr(_requestActionLabel(status)),
                            ),
                          ),
                ],
              ),
          ],
        ],
      ),
    ),
  );
}

List<BusinessRequestStatus> _managerActions(BusinessRequest request) =>
    switch (request.status) {
      BusinessRequestStatus.pending => [
        BusinessRequestStatus.accepted,
        if (request.type == BusinessRequestType.quote ||
            request.type == BusinessRequestType.service)
          BusinessRequestStatus.quoted,
        if (request.type == BusinessRequestType.appointment ||
            request.type == BusinessRequestType.taxi)
          BusinessRequestStatus.scheduled,
        BusinessRequestStatus.rejected,
      ],
      BusinessRequestStatus.accepted => [
        if (request.type == BusinessRequestType.quote ||
            request.type == BusinessRequestType.service)
          BusinessRequestStatus.quoted,
        BusinessRequestStatus.scheduled,
        BusinessRequestStatus.inProgress,
      ],
      BusinessRequestStatus.quoted => [
        BusinessRequestStatus.scheduled,
        BusinessRequestStatus.inProgress,
      ],
      BusinessRequestStatus.scheduled => [BusinessRequestStatus.inProgress],
      BusinessRequestStatus.inProgress => [BusinessRequestStatus.completed],
      _ => const [],
    };

bool _canCustomerCancel(BusinessRequestStatus status) => !{
  BusinessRequestStatus.inProgress,
  BusinessRequestStatus.completed,
  BusinessRequestStatus.rejected,
  BusinessRequestStatus.cancelled,
}.contains(status);

String _serviceLabel(BusinessRequestType type) => switch (type) {
  BusinessRequestType.quote => 'What service do you need?',
  BusinessRequestType.appointment => 'Choose a service',
  BusinessRequestType.service => 'What service do you need?',
  BusinessRequestType.taxi => 'Ride request',
};

IconData _typeIcon(BusinessRequestType type) => switch (type) {
  BusinessRequestType.quote => WicchuIcons.note,
  BusinessRequestType.appointment => WicchuIcons.calendarBlank,
  BusinessRequestType.service => WicchuIcons.hammer,
  BusinessRequestType.taxi => WicchuIcons.moped,
};

String _requestStatusLabel(BusinessRequestStatus status) => switch (status) {
  BusinessRequestStatus.pending => 'Pending',
  BusinessRequestStatus.accepted => 'Accepted',
  BusinessRequestStatus.quoted => 'Quote sent',
  BusinessRequestStatus.scheduled => 'Scheduled',
  BusinessRequestStatus.inProgress => 'In progress',
  BusinessRequestStatus.completed => 'Completed',
  BusinessRequestStatus.rejected => 'Rejected',
  BusinessRequestStatus.cancelled => 'Cancelled',
};

String _requestActionLabel(BusinessRequestStatus status) => switch (status) {
  BusinessRequestStatus.accepted => 'Accept',
  BusinessRequestStatus.quoted => 'Send quote',
  BusinessRequestStatus.scheduled => 'Schedule',
  BusinessRequestStatus.inProgress => 'Start work',
  BusinessRequestStatus.completed => 'Complete',
  _ => status.name,
};

Future<String?> _requestTextDialog(
  BuildContext context, {
  required String title,
  required String label,
  bool number = false,
}) async {
  final controller = TextEditingController();
  final result = await showBusinessDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        maxLength: number ? null : 500,
        decoration: InputDecoration(labelText: label),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.tr('Cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: Text(context.tr('Continue')),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}

Future<DateTime?> _pickRequestDateTime(BuildContext context) async {
  final now = DateTime.now();
  final date = await showDatePicker(
    context: context,
    firstDate: DateTime(now.year, now.month, now.day),
    lastDate: now.add(const Duration(days: 365)),
    initialDate: now,
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.now(),
  );
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

void _showRequestError(BuildContext context, Object error) =>
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.trError(error))));

class _RequestEmpty extends StatelessWidget {
  const _RequestEmpty({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 46),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(body, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class _RequestError extends StatelessWidget {
  const _RequestError({required this.error, required this.onRetry});
  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(WicchuIcons.warning, size: 42),
          const SizedBox(height: 10),
          Text(context.trError(error ?? 'Unable to load.')),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: Text(context.tr('Retry'))),
        ],
      ),
    ),
  );
}
