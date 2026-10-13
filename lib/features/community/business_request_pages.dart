import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
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

class _BusinessTransactionsPageState extends State<BusinessTransactionsPage> {
  late Future<(List<BusinessOrder>, List<BusinessRequest>)> _transactions =
      _load();

  Future<(List<BusinessOrder>, List<BusinessRequest>)> _load() async => (
    await widget.repository.listManagedBusinessOrders(widget.businessId),
    await widget.repository.listManagedBusinessRequests(widget.businessId),
  );

  void _reload() => setState(() => _transactions = _load());

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('Business dashboard'))),
    body: FutureBuilder<(List<BusinessOrder>, List<BusinessRequest>)>(
      future: _transactions,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _RequestError(error: snapshot.error, onRetry: _reload);
        }
        final (orders, requests) = snapshot.data!;
        final pending =
            orders
                .where((order) => order.status == BusinessOrderStatus.pending)
                .length +
            requests
                .where(
                  (request) => request.status == BusinessRequestStatus.pending,
                )
                .length;
        final scheduled = requests
            .where(
              (request) => request.status == BusinessRequestStatus.scheduled,
            )
            .length;
        final completed =
            orders
                .where((order) => order.status == BusinessOrderStatus.completed)
                .length +
            requests
                .where(
                  (request) =>
                      request.status == BusinessRequestStatus.completed,
                )
                .length;
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _DashboardCount(
                      label: context.tr('Pending'),
                      count: pending,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DashboardCount(
                      label: context.tr('Scheduled'),
                      count: scheduled,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DashboardCount(
                      label: context.tr('Completed'),
                      count: completed,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _transactionDestination(
                context,
                icon: WicchuIcons.receipt,
                title: 'Products and orders',
                count: orders.length,
                subtitle: 'Manage menus, products and customer orders.',
                page: BusinessCatalogManagementPage(
                  businessId: widget.businessId,
                  businessName: widget.businessName,
                  repository: widget.repository,
                ),
              ),
              _transactionDestination(
                context,
                icon: WicchuIcons.clipboardText,
                title: 'Service requests',
                count: requests.length,
                subtitle: 'Manage quotes, bookings and taxi requests.',
                page: BusinessRequestManagementPage(
                  businessId: widget.businessId,
                  businessName: widget.businessName,
                  repository: widget.repository,
                ),
              ),
            ],
          ),
        );
      },
    ),
  );

  Widget _transactionDestination(
    BuildContext context, {
    required IconData icon,
    required String title,
    required int count,
    required String subtitle,
    required Widget page,
  }) => Card(
    child: ListTile(
      leading: CircleAvatar(child: Icon(icon)),
      title: Text(context.tr(title)),
      subtitle: Text('$count · ${context.tr(subtitle)}'),
      trailing: const Icon(WicchuIcons.caretRight),
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
        _reload();
      },
    ),
  );
}

class _DashboardCount extends StatelessWidget {
  const _DashboardCount({required this.label, required this.count});
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Column(
        children: [
          Text(
            '$count',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
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
      return Scaffold(
        appBar: AppBar(title: Text(settings.businessName)),
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
    if (time == null) return;
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
    final files = await ImagePicker().pickMultiImage(
      maxWidth: 1800,
      imageQuality: 88,
      limit: 5 - _photos.length,
    );
    if (files.isEmpty) return;
    setState(() => _sending = true);
    try {
      for (final file in files.take(5 - _photos.length)) {
        final extension = file.name.split('.').last.toLowerCase();
        final media = await widget.repository.uploadPostMedia(
          bytes: await file.readAsBytes(),
          filename: file.name,
          mimeType: extension == 'png' ? 'image/png' : 'image/jpeg',
        );
        _photos.add(media);
      }
      if (mounted) setState(() => _sending = false);
    } catch (error) {
      if (!mounted) return;
      setState(() => _sending = false);
      _showError(error);
    }
  }

  Future<void> _submit() async {
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
      await showDialog<void>(
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
  void _reload() => setState(() => _requests = _load());

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
  late Future<List<BusinessRequest>> _requests = _load();
  Future<List<BusinessRequest>> _load() =>
      widget.repository.listManagedBusinessRequests(widget.businessId);
  void _reload() => setState(() => _requests = _load());

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.tr('Business requests')),
      actions: [
        IconButton(
          tooltip: context.tr('Request settings'),
          onPressed: () async {
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
          },
          icon: const Icon(WicchuIcons.gearSix),
        ),
      ],
    ),
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
            body: context.tr(
              'Enable request types in settings so customers can contact you.',
            ),
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
                  onAction: (status) => _changeStatus(request, status),
                ),
            ],
          ),
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
            onRetry: () => setState(
              () => _settings = widget.repository.getBusinessRequestSettings(
                widget.businessId,
              ),
            ),
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
  final result = await showDialog<String>(
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
