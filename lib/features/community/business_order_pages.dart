import 'business_dialog.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../config/business_features.dart';
import '../../localization/app_language.dart';
import '../../theme/wicchu_icons.dart';
import '../../widgets/wicchu_network_image.dart';

String _money(int cents) => '\$${(cents / 100).toStringAsFixed(2)}';

class _CartLine {
  const _CartLine({
    required this.product,
    this.variant,
    required this.quantity,
  });

  final BusinessProduct product;
  final BusinessProductVariant? variant;
  final int quantity;

  int get unitPriceCents => variant?.priceCents ?? product.priceCents;
  int? get quantityAvailable =>
      variant?.quantityAvailable ?? product.quantityAvailable;
  String get key => '${product.id}:${variant?.id ?? ''}';

  _CartLine copyWith({required int quantity}) =>
      _CartLine(product: product, variant: variant, quantity: quantity);
}

class BusinessMenuPage extends StatefulWidget {
  const BusinessMenuPage({
    super.key,
    required this.businessId,
    required this.repository,
  });

  final String businessId;
  final CommunityRepository repository;

  @override
  State<BusinessMenuPage> createState() => _BusinessMenuPageState();
}

class _BusinessMenuPageState extends State<BusinessMenuPage> {
  late Future<BusinessCatalog> _catalog = _load();
  late final Future<Community> _business = widget.repository.getCommunity(
    widget.businessId,
  );
  final Map<String, _CartLine> _cart = {};
  bool _placingOrder = false;

  Future<BusinessCatalog> _load() =>
      widget.repository.getBusinessCatalog(widget.businessId);

  void _reload() {
    if (!mounted) return;
    setState(() {
      _catalog = _load();
    });
  }

  void _changeQuantity(
    BusinessProduct product,
    BusinessProductVariant? variant,
    int delta,
  ) {
    final key = '${product.id}:${variant?.id ?? ''}';
    final current = _cart[key]?.quantity ?? 0;
    final maximum =
        variant?.quantityAvailable ?? product.quantityAvailable ?? 99;
    final next = (current + delta).clamp(0, maximum);
    setState(() {
      if (next == 0) {
        _cart.remove(key);
      } else {
        _cart[key] = _CartLine(
          product: product,
          variant: variant,
          quantity: next,
        );
      }
    });
  }

  int _total(BusinessCatalog catalog) => _cart.values.fold(
    0,
    (total, line) => total + line.unitPriceCents * line.quantity,
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<BusinessCatalog>(
    future: _catalog,
    builder: (context, snapshot) {
      final catalog = snapshot.data;
      return Scaffold(
        appBar: AppBar(
          title: Text(catalog?.businessName ?? context.tr('Menu')),
          actions: [
            if (businessOrderingEnabled)
              IconButton(
                tooltip: context.tr('My orders'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        MyBusinessOrdersPage(repository: widget.repository),
                  ),
                ),
                icon: const Icon(WicchuIcons.receipt),
              ),
          ],
        ),
        body: switch (snapshot.connectionState) {
          ConnectionState.waiting => const Center(
            child: CircularProgressIndicator(),
          ),
          _ when snapshot.hasError => _ErrorState(
            error: snapshot.error,
            onRetry: _reload,
          ),
          _ => _catalogBody(catalog!),
        },
        bottomNavigationBar:
            businessOrderingEnabled && catalog != null && _cart.isNotEmpty
            ? _cartAction(catalog)
            : null,
      );
    },
  );

  Widget _cartAction(BusinessCatalog catalog) => FutureBuilder<Community>(
    future: _business,
    builder: (context, snapshot) {
      final role = snapshot.data?.myRole;
      final canManage =
          role == CommunityRole.owner ||
          (role == CommunityRole.admin && snapshot.data!.canManagePageOrders);
      final ready =
          catalog.acceptingOrders && catalog.fulfillmentOptions.isNotEmpty;
      return SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton.icon(
          onPressed: _placingOrder
              ? null
              : ready
              ? () => _checkout(catalog)
              : canManage
              ? () => _openCatalogManagement(catalog)
              : () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      context.tr(
                        'Ordering is temporarily unavailable because delivery and pickup are not configured.',
                      ),
                    ),
                  ),
                ),
          icon: Icon(
            canManage && !ready ? WicchuIcons.gearSix : WicchuIcons.receipt,
          ),
          label: Text(
            context.tr(
                  ready
                      ? 'Review order'
                      : canManage
                      ? 'Configure order methods'
                      : 'Ordering temporarily unavailable',
                ) +
                (ready ? ' · ${_money(_total(catalog))}' : ''),
          ),
        ),
      );
    },
  );

  Future<void> _openCatalogManagement(BusinessCatalog catalog) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => BusinessCatalogManagementPage(
          businessId: widget.businessId,
          businessName: catalog.businessName,
          repository: widget.repository,
        ),
      ),
    );
    _reload();
  }

  Widget _catalogBody(BusinessCatalog catalog) {
    if (catalog.categories.isEmpty || catalog.products.isEmpty) {
      return FutureBuilder<Community>(
        future: _business,
        builder: (context, snapshot) {
          final role = snapshot.data?.myRole;
          final canManage =
              role == CommunityRole.owner ||
              (role == CommunityRole.admin &&
                  snapshot.data!.canManagePageOrders);
          return _EmptyState(
            icon: WicchuIcons.forkKnife,
            title: context.tr('The menu is being prepared'),
            body: context.tr('This business has not published products yet.'),
            actionLabel: canManage ? context.tr('Manage catalog') : null,
            onAction: canManage ? () => _openCatalogManagement(catalog) : null,
          );
        },
      );
    }
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          businessOrderingEnabled ? 120 : 24,
        ),
        children: [
          if (businessOrderingEnabled) _catalogStatus(catalog),
          for (final category in catalog.categories) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
              child: Text(
                category.name,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            for (final product in catalog.products.where(
              (product) => product.categoryId == category.id,
            ))
              _ProductCard(
                product: product,
                quantities: {
                  for (final line in _cart.values)
                    if (line.product.id == product.id)
                      line.variant?.id ?? '': line.quantity,
                },
                enabled:
                    businessOrderingEnabled &&
                    catalog.acceptingOrders &&
                    catalog.fulfillmentOptions.isNotEmpty,
                onChanged: (variant, delta) =>
                    _changeQuantity(product, variant, delta),
              ),
          ],
        ],
      ),
    );
  }

  Widget _catalogStatus(BusinessCatalog catalog) {
    final incomplete =
        catalog.acceptingOrders && catalog.fulfillmentOptions.isEmpty;
    return FutureBuilder<Community>(
      future: _business,
      builder: (context, snapshot) {
        final role = snapshot.data?.myRole;
        final canManage =
            role == CommunityRole.owner ||
            (role == CommunityRole.admin && snapshot.data!.canManagePageOrders);
        if (incomplete && !canManage) return const SizedBox.shrink();
        return Card(
          child: ListTile(
            leading: Icon(
              catalog.acceptingOrders && !incomplete
                  ? WicchuIcons.checkCircle
                  : WicchuIcons.clock,
            ),
            title: Text(
              context.tr(
                incomplete
                    ? 'Ordering setup incomplete'
                    : catalog.acceptingOrders
                    ? 'Accepting orders'
                    : 'Orders are currently closed',
              ),
            ),
            subtitle: incomplete
                ? Text(
                    context.tr(
                      'Delivery, pickup or eat-in must be configured before customers can order.',
                    ),
                  )
                : catalog.fulfillmentOptions.isEmpty
                ? null
                : Text(
                    catalog.fulfillmentOptions
                        .map((option) => context.tr(option.label))
                        .join(' · '),
                  ),
          ),
        );
      },
    );
  }

  Future<void> _checkout(BusinessCatalog catalog) async {
    if (catalog.fulfillmentOptions.isEmpty) return;
    final address = TextEditingController();
    final phone = TextEditingController();
    final notes = TextEditingController();
    var method = catalog.fulfillmentOptions.first;
    var saving = false;
    var addressMissing = false;
    final route = ModalBottomSheetRoute<void>(
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            4,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.tr('Review your order'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                for (final line in _cart.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${line.quantity} × ${line.product.name}${line.variant == null ? '' : ' · ${line.variant!.name}'}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _money(line.unitPriceCents * line.quantity),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final option in catalog.fulfillmentOptions)
                      ChoiceChip(
                        label: Text(context.tr(option.label)),
                        selected: method == option,
                        onSelected: saving
                            ? null
                            : (_) => setSheetState(() => method = option),
                      ),
                  ],
                ),
                if (method == BusinessFulfillmentOption.delivery) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: address,
                    onChanged: (_) {
                      if (addressMissing) {
                        setSheetState(() => addressMissing = false);
                      }
                    },
                    maxLength: 500,
                    decoration: InputDecoration(
                      labelText: context.tr('Delivery address'),
                      errorText: addressMissing
                          ? context.tr('Enter a delivery address.')
                          : null,
                      prefixIcon: const Icon(WicchuIcons.mapPin),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: context.tr('Phone number (optional)'),
                    prefixIcon: const Icon(WicchuIcons.phone),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notes,
                  maxLines: 2,
                  maxLength: 500,
                  decoration: InputDecoration(
                    labelText: context.tr('Order notes (optional)'),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${context.tr('Subtotal')}: ${_money(_total(catalog))}',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (method == BusinessFulfillmentOption.delivery &&
                              address.text.trim().isEmpty) {
                            setSheetState(() => addressMissing = true);
                            return;
                          }
                          setSheetState(() => saving = true);
                          setState(() => _placingOrder = true);
                          try {
                            final order = await widget.repository
                                .createBusinessOrder(
                                  widget.businessId,
                                  BusinessOrderInput(
                                    fulfillmentMethod: method,
                                    lines: _cart.values
                                        .map(
                                          (line) => BusinessOrderLineInput(
                                            productId: line.product.id,
                                            variantId: line.variant?.id,
                                            quantity: line.quantity,
                                          ),
                                        )
                                        .toList(growable: false),
                                    deliveryAddress: address.text.trim(),
                                    customerPhone: phone.text.trim(),
                                    notes: notes.text.trim(),
                                  ),
                                );
                            if (!mounted) return;
                            if (sheetContext.mounted) {
                              Navigator.pop(sheetContext);
                            }
                            setState(() {
                              _cart.clear();
                              _placingOrder = false;
                            });
                            _reload();
                            await showBusinessDialog<void>(
                              context: this.context,
                              builder: (context) => AlertDialog(
                                icon: const Icon(WicchuIcons.checkCircle),
                                title: Text(context.tr('Order sent')),
                                content: Text(
                                  context.tr(
                                    'Order #{number} is waiting for confirmation.',
                                    {'number': '${order.orderNumber}'},
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text(context.tr('Done')),
                                  ),
                                ],
                              ),
                            );
                          } catch (error) {
                            if (!mounted) return;
                            setState(() => _placingOrder = false);
                            if (sheetContext.mounted) {
                              setSheetState(() => saving = false);
                            }
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text(this.context.trError(error)),
                              ),
                            );
                          }
                        },
                  child: Text(
                    saving ? context.tr('Sending…') : context.tr('Place order'),
                  ),
                ),
                if (catalog.whatsapp.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: saving ? null : () => _orderOnWhatsApp(catalog),
                    icon: const Icon(WicchuIcons.chatCircle),
                    label: Text(context.tr('Order through WhatsApp')),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    await Navigator.of(context).push(route);
    await route.completed;
    address.dispose();
    phone.dispose();
    notes.dispose();
  }

  Future<void> _orderOnWhatsApp(BusinessCatalog catalog) async {
    final number = catalog.whatsapp.replaceAll(RegExp(r'[^0-9]'), '');
    final lines = _cart.values
        .map(
          (line) =>
              '${line.quantity}× ${line.product.name}${line.variant == null ? '' : ' · ${line.variant!.name}'} (${_money(line.unitPriceCents * line.quantity)})',
        )
        .join('\n');
    final text =
        '${context.tr('Hello, I would like to order:')}\n$lines\n${context.tr('Subtotal')}: ${_money(_total(catalog))}';
    await launchUrl(
      Uri.parse('https://wa.me/$number?text=${Uri.encodeComponent(text)}'),
      mode: LaunchMode.externalApplication,
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.quantities,
    required this.enabled,
    required this.onChanged,
  });

  final BusinessProduct product;
  final Map<String, int> quantities;
  final bool enabled;
  final void Function(BusinessProductVariant? variant, int delta) onChanged;

  Widget _quantityControl(
    BuildContext context, {
    required BusinessProductVariant? variant,
  }) {
    final quantity = quantities[variant?.id ?? ''] ?? 0;
    final maximum = variant?.quantityAvailable ?? product.quantityAvailable;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: quantity == 0 ? null : () => onChanged(variant, -1),
          icon: const Icon(WicchuIcons.minusCircle),
        ),
        Text('$quantity', style: const TextStyle(fontWeight: FontWeight.w800)),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: maximum != null && quantity >= maximum
              ? null
              : () => onChanged(variant, 1),
          icon: const Icon(WicchuIcons.plusCircle),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (product.imageUrl case final imageUrl?)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: WicchuNetworkImage(
                    url: imageUrl,
                    width: 82,
                    height: 82,
                    decodeWidth: 240,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Container(
                  width: 82,
                  height: 82,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(WicchuIcons.forkKnife),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    if (product.description.isNotEmpty)
                      Text(
                        product.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      _money(product.priceCents),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (!product.canOrder)
                      Text(
                        context.tr('Unavailable'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
              if (enabled && product.canOrder && product.variants.isEmpty)
                _quantityControl(context, variant: null),
            ],
          ),
          if (product.variants.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            for (final variant in product.variants)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: variant.name,
                          children: [
                            if (variant.sku.isNotEmpty)
                              TextSpan(
                                text: ' · ${variant.sku}',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                            TextSpan(
                              text:
                                  ' · ${_money(variant.priceCents ?? product.priceCents)}',
                            ),
                          ],
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (!variant.canOrder)
                      Text(
                        context.tr('Unavailable'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      )
                    else if (enabled)
                      _quantityControl(context, variant: variant),
                  ],
                ),
              ),
          ],
        ],
      ),
    ),
  );
}

class MyBusinessOrdersPage extends StatefulWidget {
  const MyBusinessOrdersPage({super.key, required this.repository});
  final CommunityRepository repository;

  @override
  State<MyBusinessOrdersPage> createState() => _MyBusinessOrdersPageState();
}

class _MyBusinessOrdersPageState extends State<MyBusinessOrdersPage> {
  late Future<List<BusinessOrder>> _orders = widget.repository
      .listMyBusinessOrders();

  void _reload() {
    if (!mounted) return;
    setState(() {
      _orders = widget.repository.listMyBusinessOrders();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('My orders'))),
    body: FutureBuilder<List<BusinessOrder>>(
      future: _orders,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ErrorState(error: snapshot.error, onRetry: _reload);
        }
        final orders = snapshot.data!;
        if (orders.isEmpty) {
          return _EmptyState(
            icon: WicchuIcons.receipt,
            title: context.tr('No orders yet'),
            body: context.tr('Your orders from local businesses appear here.'),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) => _OrderCard(
              order: orders[index],
              onStatus: orders[index].status == BusinessOrderStatus.pending
                  ? (status) async {
                      try {
                        await widget.repository.cancelBusinessOrder(
                          orders[index].id,
                        );
                        if (mounted) _reload();
                      } catch (error) {
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text(this.context.trError(error)),
                            ),
                          );
                        }
                      }
                    }
                  : null,
              customerView: true,
            ),
          ),
        );
      },
    ),
  );
}

class BusinessOrderManagementPage extends StatefulWidget {
  const BusinessOrderManagementPage({
    super.key,
    required this.businessId,
    required this.businessName,
    required this.repository,
    this.embedded = false,
  });

  final bool embedded;
  final String businessId;
  final String businessName;
  final CommunityRepository repository;

  @override
  State<BusinessOrderManagementPage> createState() =>
      _BusinessOrderManagementPageState();
}

class _BusinessOrderManagementPageState
    extends State<BusinessOrderManagementPage> {
  late Future<List<BusinessOrder>> _orders = _load();
  Future<List<BusinessOrder>> _load() =>
      widget.repository.listManagedBusinessOrders(widget.businessId);
  void _reload() {
    if (!mounted) return;
    setState(() {
      _orders = _load();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: widget.embedded ? null : AppBar(title: Text(context.tr('Orders'))),
    body: FutureBuilder<List<BusinessOrder>>(
      future: _orders,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ErrorState(error: snapshot.error, onRetry: _reload);
        }
        final orders = snapshot.data!;
        if (orders.isEmpty) {
          return _EmptyState(
            icon: WicchuIcons.receipt,
            title: context.tr('No orders yet'),
            body: context.tr('New customer orders will appear here.'),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) => _OrderCard(
              order: orders[index],
              onStatus: (status) => _changeStatus(orders[index], status),
            ),
          ),
        );
      },
    ),
  );

  Future<void> _changeStatus(
    BusinessOrder order,
    BusinessOrderStatus status,
  ) async {
    var reason = '';
    if (status == BusinessOrderStatus.rejected) {
      reason =
          await _textDialog(
            context,
            title: context.tr('Reject order'),
            label: context.tr('Reason for the customer'),
          ) ??
          '';
      if (reason.isEmpty) return;
    }
    try {
      await widget.repository.updateBusinessOrderStatus(
        order.id,
        status,
        reason: reason,
      );
      _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.trError(error))));
    }
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    this.onStatus,
    this.customerView = false,
  });

  final BusinessOrder order;
  final ValueChanged<BusinessOrderStatus>? onStatus;
  final bool customerView;

  @override
  Widget build(BuildContext context) {
    final next = switch (order.status) {
      BusinessOrderStatus.pending => BusinessOrderStatus.accepted,
      BusinessOrderStatus.accepted => BusinessOrderStatus.preparing,
      BusinessOrderStatus.preparing => BusinessOrderStatus.ready,
      BusinessOrderStatus.ready => BusinessOrderStatus.completed,
      _ => null,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${customerView && order.businessName.isNotEmpty ? '${order.businessName} · ' : ''}${context.tr('Order')} #${order.orderNumber}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                Chip(label: Text(context.tr(_statusLabel(order.status)))),
              ],
            ),
            if (order.customerName.isNotEmpty) Text(order.customerName),
            Text(context.tr(order.fulfillmentMethod.label)),
            if (order.deliveryAddress.isNotEmpty) Text(order.deliveryAddress),
            const Divider(),
            for (final item in order.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${item.quantity}× ${item.name}${item.variantName.isEmpty ? '' : ' · ${item.variantName}'}',
                      ),
                    ),
                    Text(_money(item.totalCents)),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                _money(order.subtotalCents),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            if (onStatus != null &&
                (next != null ||
                    order.status == BusinessOrderStatus.pending)) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  if (!customerView && next != null)
                    Expanded(
                      child: FilledButton(
                        onPressed: () => onStatus!(next),
                        child: Text(context.tr(_statusAction(next))),
                      ),
                    ),
                  if (!customerView &&
                      order.status == BusinessOrderStatus.pending) ...[
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => onStatus!(BusinessOrderStatus.rejected),
                      child: Text(context.tr('Reject')),
                    ),
                  ],
                  if (customerView &&
                      order.status == BusinessOrderStatus.pending)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            onStatus!(BusinessOrderStatus.cancelled),
                        child: Text(context.tr('Cancel order')),
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
}

class BusinessCatalogManagementPage extends StatefulWidget {
  const BusinessCatalogManagementPage({
    super.key,
    required this.businessId,
    required this.businessName,
    required this.repository,
  });

  final String businessId;
  final String businessName;
  final CommunityRepository repository;

  @override
  State<BusinessCatalogManagementPage> createState() =>
      _BusinessCatalogManagementPageState();
}

class _BusinessCatalogManagementPageState
    extends State<BusinessCatalogManagementPage> {
  late Future<BusinessCatalog> _catalog = _load();
  bool _savingOrders = false;
  bool _savingFulfillment = false;
  int _tab = 0;
  Future<BusinessCatalog> _load() =>
      widget.repository.getBusinessCatalog(widget.businessId, manage: true);
  void _reload() {
    if (!mounted) return;
    setState(() {
      _catalog = _load();
    });
  }

  Future<void> _setAccepting(bool value, BusinessCatalog catalog) async {
    if (value && catalog.fulfillmentOptions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Select at least one order method.')),
        ),
      );
      return;
    }
    setState(() => _savingOrders = true);
    try {
      await widget.repository.setBusinessAcceptingOrders(
        widget.businessId,
        accepting: value,
      );
      _reload();
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _savingOrders = false);
    }
  }

  Future<void> _setFulfillmentOption(
    BusinessCatalog catalog,
    BusinessFulfillmentOption option,
    bool selected,
  ) async {
    final options = {...catalog.fulfillmentOptions};
    selected ? options.add(option) : options.remove(option);
    setState(() => _savingFulfillment = true);
    try {
      await widget.repository.setBusinessAcceptingOrders(
        widget.businessId,
        accepting: catalog.acceptingOrders,
        fulfillmentOptions: options.toList(growable: false),
      );
      _reload();
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _savingFulfillment = false);
    }
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: businessOrderingEnabled ? 2 : 1,
    child: FutureBuilder<BusinessCatalog>(
      future: _catalog,
      builder: (context, snapshot) {
        final catalog = snapshot.data;
        return Scaffold(
          appBar: AppBar(
            title: Text(
              context.tr(
                businessOrderingEnabled ? 'Products and orders' : 'Catalog',
              ),
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
            ),
          ),
          floatingActionButton:
              _tab == 0 && catalog != null && catalog.products.isNotEmpty
              ? FloatingActionButton.small(
                  tooltip: context.tr('Add product'),
                  onPressed: () => _editProduct(null),
                  child: const Icon(WicchuIcons.plus),
                )
              : null,
          body: Column(
            children: [
              if (businessOrderingEnabled && catalog != null)
                SwitchListTile.adaptive(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  value: catalog.acceptingOrders,
                  title: Text(
                    context.tr('Accept orders'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    context.tr(
                      catalog.acceptingOrders
                          ? 'Customers can submit new orders.'
                          : 'Customers can view the catalog but cannot order.',
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                  onChanged: _savingOrders
                      ? null
                      : (value) => _setAccepting(value, catalog),
                ),
              if (businessOrderingEnabled && catalog != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('Order methods'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.tr(
                          'Choose how customers can receive their orders.',
                        ),
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (final option in BusinessFulfillmentOption.values)
                            FilterChip(
                              label: Text(context.tr(option.label)),
                              selected: catalog.fulfillmentOptions.contains(
                                option,
                              ),
                              showCheckmark: false,
                              side: BorderSide.none,
                              backgroundColor: Colors.transparent,
                              selectedColor: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              onSelected: _savingFulfillment || _savingOrders
                                  ? null
                                  : (selected) => _setFulfillmentOption(
                                      catalog,
                                      option,
                                      selected,
                                    ),
                            ),
                        ],
                      ),
                      if (catalog.fulfillmentOptions.isEmpty)
                        Text(
                          context.tr(
                            'Select at least one method before accepting orders.',
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                    ],
                  ),
                ),
              if (businessOrderingEnabled)
                TabBar(
                  onTap: (index) => setState(() => _tab = index),
                  tabs: [
                    Tab(text: context.tr('Catalog')),
                    Tab(text: context.tr('Orders')),
                  ],
                ),
              Expanded(
                child: TabBarView(
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    snapshot.connectionState == ConnectionState.waiting
                        ? const Center(child: CircularProgressIndicator())
                        : snapshot.hasError
                        ? _ErrorState(error: snapshot.error, onRetry: _reload)
                        : RefreshIndicator(
                            onRefresh: () async {
                              _reload();
                              await _catalog;
                            },
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                              children: [
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    context.tr('Categories'),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  trailing: TextButton.icon(
                                    onPressed: _addCategory,
                                    icon: const Icon(
                                      WicchuIcons.plus,
                                      size: 18,
                                    ),
                                    label: Text(context.tr('Add category')),
                                  ),
                                ),
                                if (catalog!.categories.isEmpty)
                                  Text(
                                    context.tr(
                                      'No categories yet. Add one to organize your products.',
                                    ),
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    for (final category in catalog.categories)
                                      InputChip(
                                        label: Text(category.name),
                                        onDeleted: () =>
                                            _deleteCategory(category),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        context.tr('Products'),
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      context.trCount(
                                        catalog.products.length,
                                        singular: '{count} product',
                                        plural: '{count} products',
                                      ),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (catalog.products.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 24,
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(
                                          WicchuIcons.tote,
                                          size: 32,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          context.tr('Your catalog is empty'),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          context.tr(
                                            'Add products with photos, prices and availability for customers to discover.',
                                          ),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                        const SizedBox(height: 16),
                                        FilledButton.icon(
                                          onPressed: () => _editProduct(null),
                                          icon: const Icon(WicchuIcons.plus),
                                          label: Text(
                                            context.tr('Add product'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                for (final product in catalog.products)
                                  Card(
                                    child: ListTile(
                                      leading: product.imageUrl == null
                                          ? const CircleAvatar(
                                              child: Icon(
                                                WicchuIcons.forkKnife,
                                              ),
                                            )
                                          : ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: WicchuNetworkImage(
                                                url: product.imageUrl!,
                                                width: 48,
                                                height: 48,
                                                decodeWidth: 160,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                      title: Text(product.name),
                                      subtitle: Text(
                                        '${_money(product.priceCents)} · ${product.available ? context.tr('Available') : context.tr('Unavailable')}',
                                      ),
                                      onTap: () => _editProduct(product),
                                      trailing: IconButton(
                                        tooltip: context.tr('Delete'),
                                        onPressed: () =>
                                            _deleteProduct(product),
                                        icon: const Icon(WicchuIcons.trash),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                    if (businessOrderingEnabled)
                      BusinessOrderManagementPage(
                        businessId: widget.businessId,
                        businessName: widget.businessName,
                        repository: widget.repository,
                        embedded: true,
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );

  Future<void> _addCategory() async {
    final name = await _textDialog(
      context,
      title: context.tr('Add category'),
      label: context.tr('Category name'),
    );
    if (name == null || name.trim().isEmpty) return;
    try {
      await widget.repository.createBusinessCatalogCategory(
        widget.businessId,
        name.trim(),
      );
      _reload();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _deleteCategory(BusinessCatalogCategory category) async {
    try {
      await widget.repository.deleteBusinessCatalogCategory(
        widget.businessId,
        category.id,
      );
      _reload();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _deleteProduct(BusinessProduct product) async {
    try {
      await widget.repository.deleteBusinessProduct(
        widget.businessId,
        product.id,
      );
      _reload();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _editProduct(BusinessProduct? product) async {
    final catalog = await _catalog;
    if (!mounted) return;
    if (catalog.categories.isEmpty) {
      await _addCategory();
      if (!mounted) return;
      final updated = await _catalog;
      if (mounted && updated.categories.isNotEmpty) await _editProduct(product);
      return;
    }
    final name = TextEditingController(text: product?.name ?? '');
    final description = TextEditingController(text: product?.description ?? '');
    final price = TextEditingController(
      text: product == null
          ? ''
          : (product.priceCents / 100).toStringAsFixed(2),
    );
    final quantity = TextEditingController(
      text: product?.quantityAvailable?.toString() ?? '',
    );
    var variants = (product?.variants ?? const <BusinessProductVariant>[])
        .map(
          (variant) => BusinessProductVariantInput(
            id: variant.id,
            name: variant.name,
            sku: variant.sku,
            priceCents: variant.priceCents,
            available: variant.available,
            quantityAvailable: variant.quantityAvailable,
            attributes: variant.attributes,
          ),
        )
        .toList();
    var categoryId = product?.categoryId ?? catalog.categories.first.id;
    var kind = product?.kind ?? BusinessProductKind.product;
    var available = product?.available ?? true;
    var trackStock = product?.quantityAvailable != null;
    PostMedia? image;
    var saving = false;
    var invalidName = false;
    var invalidPrice = false;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (editorContext) => StatefulBuilder(
          builder: (context, setEditorState) {
            final previewUrl = image?.previewUrl ?? product?.imageUrl;
            Future<void> choosePhoto() async {
              final file = await ImagePicker().pickImage(
                source: ImageSource.gallery,
                maxWidth: 1800,
                imageQuality: 88,
              );
              if (file == null || !editorContext.mounted) return;
              final extension = file.name.split('.').last.toLowerCase();
              final mime = extension == 'png'
                  ? 'image/png'
                  : extension == 'webp'
                  ? 'image/webp'
                  : 'image/jpeg';
              setEditorState(() => saving = true);
              try {
                final uploaded = await widget.repository.uploadPostMedia(
                  bytes: await file.readAsBytes(),
                  filename: file.name,
                  mimeType: mime,
                );
                if (!editorContext.mounted) return;
                setEditorState(() {
                  image = uploaded;
                  saving = false;
                });
              } catch (error) {
                if (editorContext.mounted) {
                  setEditorState(() => saving = false);
                }
                _showError(error);
              }
            }

            Future<void> save() async {
              final parsedPrice = double.tryParse(
                price.text.trim().replaceAll(',', '.'),
              );
              final nameMissing = name.text.trim().isEmpty;
              if (nameMissing || parsedPrice == null) {
                setEditorState(() {
                  invalidName = nameMissing;
                  invalidPrice = parsedPrice == null;
                });
                return;
              }
              setEditorState(() => saving = true);
              final input = BusinessProductInput(
                categoryId: categoryId,
                name: name.text.trim(),
                description: description.text.trim(),
                priceCents: (parsedPrice * 100).round(),
                kind: kind,
                image: image,
                available: available,
                quantityAvailable:
                    kind == BusinessProductKind.product &&
                        variants.isEmpty &&
                        trackStock
                    ? int.tryParse(quantity.text.trim())
                    : null,
                variants: kind == BusinessProductKind.product
                    ? variants
                    : const [],
                expiresAt: kind == BusinessProductKind.dailyMenu
                    ? DateTime.now().copyWith(hour: 23, minute: 59, second: 59)
                    : null,
              );
              try {
                if (product == null) {
                  await widget.repository.createBusinessProduct(
                    widget.businessId,
                    input,
                  );
                } else {
                  await widget.repository.updateBusinessProduct(
                    widget.businessId,
                    product.id,
                    input,
                  );
                }
                if (editorContext.mounted) {
                  Navigator.pop(editorContext, true);
                }
              } catch (error) {
                if (editorContext.mounted) {
                  setEditorState(() => saving = false);
                }
                _showError(error);
              }
            }

            return Scaffold(
              appBar: AppBar(
                title: Text(
                  context.tr(product == null ? 'Add product' : 'Edit product'),
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              body: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                children: [
                  Center(
                    child: InkWell(
                      onTap: saving ? null : choosePhoto,
                      borderRadius: BorderRadius.circular(16),
                      child: Ink(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: previewUrl == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    WicchuIcons.imageSquare,
                                    size: 38,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    context.tr('Add product photo'),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    context.tr('JPG, PNG or WebP'),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    WicchuNetworkImage(
                                      url: previewUrl,
                                      fit: BoxFit.cover,
                                      decodeWidth: 720,
                                    ),
                                    Align(
                                      alignment: Alignment.bottomCenter,
                                      child: ColoredBox(
                                        color: Colors.black.withValues(
                                          alpha: .58,
                                        ),
                                        child: SizedBox(
                                          width: double.infinity,
                                          child: Padding(
                                            padding: const EdgeInsets.all(8),
                                            child: Text(
                                              context.tr('Change photo'),
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    initialValue: categoryId,
                    decoration: InputDecoration(
                      labelText: context.tr('Category'),
                    ),
                    items: [
                      for (final category in catalog.categories)
                        DropdownMenuItem(
                          value: category.id,
                          child: Text(category.name),
                        ),
                    ],
                    onChanged: saving
                        ? null
                        : (value) => setEditorState(() => categoryId = value!),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.tr('Type'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SegmentedButton<BusinessProductKind>(
                    segments: [
                      ButtonSegment(
                        value: BusinessProductKind.product,
                        label: Text(context.tr('Product')),
                      ),
                      ButtonSegment(
                        value: BusinessProductKind.dailyMenu,
                        label: Text(context.tr("Today's menu")),
                      ),
                    ],
                    selected: {kind},
                    onSelectionChanged: saving
                        ? null
                        : (values) => setEditorState(() => kind = values.first),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: name,
                    enabled: !saving,
                    onChanged: (_) {
                      if (invalidName) {
                        setEditorState(() => invalidName = false);
                      }
                    },
                    decoration: InputDecoration(
                      labelText: context.tr('Name'),
                      errorText: invalidName
                          ? context.tr('Enter a product name.')
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: description,
                    enabled: !saving,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: context.tr('Description'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: price,
                    enabled: !saving,
                    onChanged: (_) {
                      if (invalidPrice) {
                        setEditorState(() => invalidPrice = false);
                      }
                    },
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: context.tr('Price (USD)'),
                      prefixText: r'$ ',
                      errorText: invalidPrice
                          ? context.tr('Enter a valid price.')
                          : null,
                    ),
                  ),
                  if (kind == BusinessProductKind.product) ...[
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: trackStock,
                      title: Text(
                        context.tr('Track stock'),
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(
                        context.tr('Optional'),
                        style: const TextStyle(fontSize: 12),
                      ),
                      onChanged: saving || variants.isNotEmpty
                          ? null
                          : (value) => setEditorState(() => trackStock = value),
                    ),
                    if (trackStock && variants.isEmpty) ...[
                      const SizedBox(height: 4),
                      TextField(
                        controller: quantity,
                        enabled: !saving,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: context.tr('Stock quantity'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: EdgeInsets.zero,
                      initiallyExpanded: variants.isNotEmpty,
                      title: Text(
                        context.tr('Variants and options'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        context.tr('Sizes, extras, flavors and colors'),
                        style: const TextStyle(fontSize: 12),
                      ),
                      children: [
                        for (var index = 0; index < variants.length; index++)
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(variants[index].name),
                            subtitle: Text(
                              [
                                if (variants[index].sku.isNotEmpty)
                                  variants[index].sku,
                                if (variants[index].priceCents
                                    case final cents?)
                                  _money(cents)
                                else
                                  context.tr('Uses product price'),
                                if (variants[index].quantityAvailable != null)
                                  '${variants[index].quantityAvailable} ${context.tr('available')}',
                              ].join(' · '),
                            ),
                            onTap: saving
                                ? null
                                : () async {
                                    final updated = await _editVariant(
                                      variants[index],
                                    );
                                    if (updated != null &&
                                        editorContext.mounted) {
                                      setEditorState(
                                        () => variants[index] = updated,
                                      );
                                    }
                                  },
                            trailing: IconButton(
                              tooltip: context.tr('Delete'),
                              onPressed: saving
                                  ? null
                                  : () => setEditorState(
                                      () => variants.removeAt(index),
                                    ),
                              icon: const Icon(WicchuIcons.trash),
                            ),
                          ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: saving || variants.length >= 50
                                ? null
                                : () async {
                                    final variant = await _editVariant(null);
                                    if (variant != null &&
                                        editorContext.mounted) {
                                      setEditorState(
                                        () => variants.add(variant),
                                      );
                                    }
                                  },
                            icon: const Icon(WicchuIcons.plus),
                            label: Text(context.tr('Add variant')),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: available,
                    title: Text(
                      context.tr('Available'),
                      style: const TextStyle(fontSize: 14),
                    ),
                    subtitle: Text(
                      context.tr('Visible to customers'),
                      style: const TextStyle(fontSize: 12),
                    ),
                    onChanged: saving
                        ? null
                        : (value) => setEditorState(() => available = value),
                  ),
                ],
              ),
              bottomNavigationBar: SafeArea(
                minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: FilledButton(
                  onPressed: saving ? null : save,
                  child: saving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(context.tr('Save product')),
                ),
              ),
            );
          },
        ),
      ),
    );
    if (saved == true) _reload();
    name.dispose();
    description.dispose();
    price.dispose();
    quantity.dispose();
  }

  Future<BusinessProductVariantInput?> _editVariant(
    BusinessProductVariantInput? current,
  ) async {
    final name = TextEditingController(text: current?.name ?? '');
    final sku = TextEditingController(text: current?.sku ?? '');
    final price = TextEditingController(
      text: current?.priceCents == null
          ? ''
          : (current!.priceCents! / 100).toStringAsFixed(2),
    );
    final quantity = TextEditingController(
      text: current?.quantityAvailable?.toString() ?? '',
    );
    final size = TextEditingController(text: current?.attributes['Size'] ?? '');
    final color = TextEditingController(
      text: current?.attributes['Color'] ?? '',
    );
    var available = current?.available ?? true;
    final result = await showBusinessDialog<BusinessProductVariantInput>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            context.tr(current == null ? 'Add product option' : 'Edit option'),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  maxLength: 120,
                  decoration: InputDecoration(
                    labelText: context.tr('Option name'),
                    hintText: context.tr('For example: Medium · Blue'),
                  ),
                ),
                TextField(
                  controller: size,
                  maxLength: 80,
                  decoration: InputDecoration(
                    labelText: context.tr('Size (optional)'),
                  ),
                ),
                TextField(
                  controller: color,
                  maxLength: 80,
                  decoration: InputDecoration(
                    labelText: context.tr('Color (optional)'),
                  ),
                ),
                TextField(
                  controller: sku,
                  maxLength: 80,
                  decoration: InputDecoration(
                    labelText: context.tr('SKU (optional)'),
                  ),
                ),
                TextField(
                  controller: price,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: context.tr('Variant price (optional)'),
                    helperText: context.tr(
                      'Leave empty to use the product price.',
                    ),
                    helperMaxLines: 2,
                    prefixText: r'$ ',
                  ),
                ),
                TextField(
                  controller: quantity,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: context.tr('Stock (optional)'),
                  ),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: available,
                  title: Text(context.tr('Available')),
                  onChanged: (value) => setDialogState(() => available = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.tr('Cancel')),
            ),
            FilledButton(
              onPressed: () {
                final parsedPrice = price.text.trim().isEmpty
                    ? null
                    : double.tryParse(price.text.trim().replaceAll(',', '.'));
                final parsedQuantity = quantity.text.trim().isEmpty
                    ? null
                    : int.tryParse(quantity.text.trim());
                if (name.text.trim().isEmpty ||
                    (price.text.trim().isNotEmpty && parsedPrice == null) ||
                    (quantity.text.trim().isNotEmpty &&
                        parsedQuantity == null)) {
                  return;
                }
                Navigator.pop(
                  dialogContext,
                  BusinessProductVariantInput(
                    id: current?.id,
                    name: name.text.trim(),
                    sku: sku.text.trim(),
                    priceCents: parsedPrice == null
                        ? null
                        : (parsedPrice * 100).round(),
                    available: available,
                    quantityAvailable: parsedQuantity,
                    attributes: {
                      for (final entry
                          in (current?.attributes ?? const <String, String>{})
                              .entries)
                        if (entry.key != 'Size' && entry.key != 'Color')
                          entry.key: entry.value,
                      if (size.text.trim().isNotEmpty) 'Size': size.text.trim(),
                      if (color.text.trim().isNotEmpty)
                        'Color': color.text.trim(),
                    },
                  ),
                );
              },
              child: Text(context.tr('Save')),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    sku.dispose();
    price.dispose();
    quantity.dispose();
    size.dispose();
    color.dispose();
    return result;
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.trError(error))));
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});
  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(WicchuIcons.warning, size: 40),
          const SizedBox(height: 12),
          Text(context.trError(error ?? 'Unable to load.')),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: Text(context.tr('Retry'))),
        ],
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });
  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 46),
          const SizedBox(height: 14),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(body, textAlign: TextAlign.center),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(WicchuIcons.gearSix, size: 18),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    ),
  );
}

Future<String?> _textDialog(
  BuildContext context, {
  required String title,
  required String label,
}) async {
  final controller = TextEditingController();
  final value = await showBusinessDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 300,
        decoration: InputDecoration(labelText: label),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.tr('Cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: Text(context.tr('Save')),
        ),
      ],
    ),
  );
  controller.dispose();
  return value;
}

String _statusLabel(BusinessOrderStatus status) => switch (status) {
  BusinessOrderStatus.pending => 'Pending',
  BusinessOrderStatus.accepted => 'Accepted',
  BusinessOrderStatus.preparing => 'Preparing',
  BusinessOrderStatus.ready => 'Ready',
  BusinessOrderStatus.completed => 'Completed',
  BusinessOrderStatus.rejected => 'Rejected',
  BusinessOrderStatus.cancelled => 'Cancelled',
};

String _statusAction(BusinessOrderStatus status) => switch (status) {
  BusinessOrderStatus.accepted => 'Accept order',
  BusinessOrderStatus.preparing => 'Start preparing',
  BusinessOrderStatus.ready => 'Mark as ready',
  BusinessOrderStatus.completed => 'Mark as completed',
  _ => 'Update order',
};
