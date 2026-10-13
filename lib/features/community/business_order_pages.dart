import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
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
  final Map<String, _CartLine> _cart = {};

  Future<BusinessCatalog> _load() =>
      widget.repository.getBusinessCatalog(widget.businessId);

  void _reload() => setState(() => _catalog = _load());

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
          title: Text(catalog?.businessName ?? context.tr('Menu and orders')),
          actions: [
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
        bottomNavigationBar: catalog != null && _cart.isNotEmpty
            ? SafeArea(
                minimum: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: catalog.acceptingOrders
                      ? () => _checkout(catalog)
                      : null,
                  icon: const Icon(WicchuIcons.receipt),
                  label: Text(
                    '${context.tr('Review order')} · ${_money(_total(catalog))}',
                  ),
                ),
              )
            : null,
      );
    },
  );

  Widget _catalogBody(BusinessCatalog catalog) {
    if (catalog.categories.isEmpty || catalog.products.isEmpty) {
      return _EmptyState(
        icon: WicchuIcons.forkKnife,
        title: context.tr('The menu is being prepared'),
        body: context.tr('This business has not published products yet.'),
      );
    }
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          Card(
            child: ListTile(
              leading: Icon(
                catalog.acceptingOrders
                    ? WicchuIcons.checkCircle
                    : WicchuIcons.clock,
              ),
              title: Text(
                context.tr(
                  catalog.acceptingOrders
                      ? 'Accepting orders'
                      : 'Orders are currently closed',
                ),
              ),
              subtitle: catalog.fulfillmentOptions.isEmpty
                  ? null
                  : Text(
                      catalog.fulfillmentOptions
                          .map((option) => context.tr(option.label))
                          .join(' · '),
                    ),
            ),
          ),
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
                enabled: catalog.acceptingOrders,
                onChanged: (variant, delta) =>
                    _changeQuantity(product, variant, delta),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _checkout(BusinessCatalog catalog) async {
    if (catalog.fulfillmentOptions.isEmpty) return;
    final address = TextEditingController();
    final phone = TextEditingController();
    final notes = TextEditingController();
    var method = catalog.fulfillmentOptions.first;
    var saving = false;
    await showModalBottomSheet<void>(
      context: context,
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
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
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
                        onSelected: (_) => setSheetState(() => method = option),
                      ),
                  ],
                ),
                if (method == BusinessFulfillmentOption.delivery) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: address,
                    maxLength: 500,
                    decoration: InputDecoration(
                      labelText: context.tr('Delivery address'),
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
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  context.tr('Enter a delivery address.'),
                                ),
                              ),
                            );
                            return;
                          }
                          setSheetState(() => saving = true);
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
                            if (!mounted || !sheetContext.mounted) return;
                            Navigator.pop(sheetContext);
                            setState(_cart.clear);
                            _reload();
                            await showDialog<void>(
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
                            setSheetState(() => saving = false);
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
                    onPressed: () => _orderOnWhatsApp(catalog),
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

  void _reload() =>
      setState(() => _orders = widget.repository.listMyBusinessOrders());

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
                      await widget.repository.cancelBusinessOrder(
                        orders[index].id,
                      );
                      _reload();
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
  });

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
  void _reload() => setState(() => _orders = _load());

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('Orders'))),
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
                  if (next != null)
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
  Future<BusinessCatalog> _load() =>
      widget.repository.getBusinessCatalog(widget.businessId, manage: true);
  void _reload() => setState(() => _catalog = _load());

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.tr('Products and orders')),
      actions: [
        IconButton(
          tooltip: context.tr('Orders'),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BusinessOrderManagementPage(
                businessId: widget.businessId,
                businessName: widget.businessName,
                repository: widget.repository,
              ),
            ),
          ),
          icon: const Icon(WicchuIcons.receipt),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _editProduct(null),
      icon: const Icon(WicchuIcons.plus),
      label: Text(context.tr('Add product')),
    ),
    body: FutureBuilder<BusinessCatalog>(
      future: _catalog,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ErrorState(error: snapshot.error, onRetry: _reload);
        }
        final catalog = snapshot.data!;
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            children: [
              SwitchListTile.adaptive(
                value: catalog.acceptingOrders,
                title: Text(context.tr('Sell products and accept orders')),
                subtitle: Text(
                  context.tr(
                    catalog.acceptingOrders
                        ? 'Customers can submit new orders.'
                        : 'Customers can view the catalog but cannot order.',
                  ),
                ),
                onChanged: (value) async {
                  await widget.repository.setBusinessAcceptingOrders(
                    widget.businessId,
                    accepting: value,
                  );
                  _reload();
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  context.tr('Catalog categories'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                trailing: TextButton.icon(
                  onPressed: _addCategory,
                  icon: const Icon(WicchuIcons.plus),
                  label: Text(context.tr('Add category')),
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final category in catalog.categories)
                    InputChip(
                      label: Text(category.name),
                      onDeleted: () => _deleteCategory(category),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                context.tr('Products'),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              if (catalog.products.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 36),
                  child: Text(
                    context.tr('Add your first product or daily menu.'),
                    textAlign: TextAlign.center,
                  ),
                ),
              for (final product in catalog.products)
                Card(
                  child: ListTile(
                    leading: product.imageUrl == null
                        ? const CircleAvatar(child: Icon(WicchuIcons.forkKnife))
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(8),
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
                      onPressed: () => _deleteProduct(product),
                      icon: const Icon(WicchuIcons.trash),
                    ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Add a category first.'))),
      );
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
    PostMedia? image;
    var saving = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            context.tr(product == null ? 'Add product' : 'Edit product'),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                  onChanged: (value) =>
                      setDialogState(() => categoryId = value!),
                ),
                const SizedBox(height: 10),
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
                  onSelectionChanged: (values) =>
                      setDialogState(() => kind = values.first),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: name,
                  decoration: InputDecoration(labelText: context.tr('Name')),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: description,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: context.tr('Description'),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: price,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: context.tr('Price (USD)'),
                    prefixText: r'$ ',
                  ),
                ),
                const SizedBox(height: 10),
                if (kind == BusinessProductKind.product) ...[
                  if (variants.isEmpty)
                    TextField(
                      controller: quantity,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: context.tr('Quantity available (optional)'),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      context.tr('Product variants (optional)'),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (variants.isNotEmpty)
                    for (var index = 0; index < variants.length; index++)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(variants[index].name),
                        subtitle: Text(
                          [
                            if (variants[index].sku.isNotEmpty)
                              variants[index].sku,
                            if (variants[index].priceCents case final cents?)
                              _money(cents)
                            else
                              context.tr('Uses product price'),
                            if (variants[index].quantityAvailable != null)
                              '${variants[index].quantityAvailable} ${context.tr('available')}',
                          ].join(' · '),
                        ),
                        onTap: () async {
                          final updated = await _editVariant(variants[index]);
                          if (updated != null) {
                            setDialogState(() => variants[index] = updated);
                          }
                        },
                        trailing: IconButton(
                          tooltip: context.tr('Delete'),
                          onPressed: () =>
                              setDialogState(() => variants.removeAt(index)),
                          icon: const Icon(WicchuIcons.trash),
                        ),
                      ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: variants.length >= 50
                          ? null
                          : () async {
                              final variant = await _editVariant(null);
                              if (variant != null) {
                                setDialogState(() => variants.add(variant));
                              }
                            },
                      icon: const Icon(WicchuIcons.plus),
                      label: Text(context.tr('Add size or color option')),
                    ),
                  ),
                ],
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: available,
                  title: Text(context.tr('Available')),
                  onChanged: (value) => setDialogState(() => available = value),
                ),
                OutlinedButton.icon(
                  onPressed: saving
                      ? null
                      : () async {
                          final file = await ImagePicker().pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 1800,
                            imageQuality: 88,
                          );
                          if (file == null) return;
                          final extension = file.name
                              .split('.')
                              .last
                              .toLowerCase();
                          final mime = extension == 'png'
                              ? 'image/png'
                              : extension == 'webp'
                              ? 'image/webp'
                              : 'image/jpeg';
                          setDialogState(() => saving = true);
                          try {
                            final uploaded = await widget.repository
                                .uploadPostMedia(
                                  bytes: await file.readAsBytes(),
                                  filename: file.name,
                                  mimeType: mime,
                                );
                            setDialogState(() {
                              image = uploaded;
                              saving = false;
                            });
                          } catch (error) {
                            setDialogState(() => saving = false);
                            _showError(error);
                          }
                        },
                  icon: const Icon(WicchuIcons.imageSquare),
                  label: Text(
                    context.tr(
                      image == null ? 'Choose product photo' : 'Photo selected',
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: Text(context.tr('Cancel')),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final parsedPrice = double.tryParse(
                        price.text.trim().replaceAll(',', '.'),
                      );
                      if (name.text.trim().isEmpty || parsedPrice == null) {
                        return;
                      }
                      setDialogState(() => saving = true);
                      final input = BusinessProductInput(
                        categoryId: categoryId,
                        name: name.text.trim(),
                        description: description.text.trim(),
                        priceCents: (parsedPrice * 100).round(),
                        kind: kind,
                        image: image,
                        available: available,
                        quantityAvailable: quantity.text.trim().isEmpty
                            ? null
                            : int.tryParse(quantity.text.trim()),
                        variants: kind == BusinessProductKind.product
                            ? variants
                            : const [],
                        expiresAt: kind == BusinessProductKind.dailyMenu
                            ? DateTime.now().copyWith(
                                hour: 23,
                                minute: 59,
                                second: 59,
                              )
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
                        if (!mounted || !dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        _reload();
                      } catch (error) {
                        setDialogState(() => saving = false);
                        _showError(error);
                      }
                    },
              child: Text(context.tr('Save')),
            ),
          ],
        ),
      ),
    );
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
    final result = await showDialog<BusinessProductVariantInput>(
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
                    prefixText: r'$ ',
                  ),
                ),
                TextField(
                  controller: quantity,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: context.tr('Quantity available (optional)'),
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
  });
  final IconData icon;
  final String title;
  final String body;

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
  final value = await showDialog<String>(
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
