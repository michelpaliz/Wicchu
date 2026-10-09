import 'package:wicchu/theme/wicchu_icons.dart';
import 'package:flutter/material.dart';

import '../../domain/community_models.dart';
import '../../localization/app_language.dart';

class RestaurantSettingsDraft {
  const RestaurantSettingsDraft({
    required this.hours,
    required this.fulfillmentOptions,
    required this.contact,
  });

  final List<BusinessHour> hours;
  final List<BusinessFulfillmentOption> fulfillmentOptions;
  final BusinessContact contact;
}

class RestaurantSettingsPage extends StatefulWidget {
  const RestaurantSettingsPage({
    super.key,
    required this.hours,
    required this.fulfillmentOptions,
    required this.contact,
  });

  final List<BusinessHour> hours;
  final List<BusinessFulfillmentOption> fulfillmentOptions;
  final BusinessContact contact;

  @override
  State<RestaurantSettingsPage> createState() => _RestaurantSettingsPageState();
}

class _RestaurantSettingsPageState extends State<RestaurantSettingsPage> {
  static const _days = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  late final Map<String, BusinessHour> _hours = {
    for (final day in _days)
      day:
          widget.hours.where((hours) => hours.day == day).firstOrNull ??
          BusinessHour(day: day, open: '09:00', close: '18:00'),
  };
  late final Set<BusinessFulfillmentOption> _fulfillment = {
    ...widget.fulfillmentOptions,
  };
  late final _phone = TextEditingController(text: widget.contact.phone);
  late final _whatsapp = TextEditingController(text: widget.contact.whatsapp);

  @override
  void dispose() {
    _phone.dispose();
    _whatsapp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('Restaurant settings'))),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            context.tr('Opening hours'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          for (final day in _days) _hoursRow(day),
          const SizedBox(height: 20),
          Text(
            context.tr('Service options'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final option in BusinessFulfillmentOption.values)
                FilterChip(
                  label: Text(context.tr(option.label)),
                  selected: _fulfillment.contains(option),
                  onSelected: (selected) => setState(() {
                    selected
                        ? _fulfillment.add(option)
                        : _fulfillment.remove(option);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _phone,
            maxLength: 30,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: context.tr('Phone number'),
              prefixIcon: const Icon(WicchuIcons.phone),
            ),
          ),
          TextField(
            controller: _whatsapp,
            maxLength: 30,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: context.tr('WhatsApp number'),
              prefixIcon: const Icon(WicchuIcons.chatCircle),
              helperText: context.tr('Include the international country code.'),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _apply,
            icon: const Icon(WicchuIcons.check),
            label: Text(context.tr('Apply settings')),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('Finish by saving changes in settings.'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );

  Widget _hoursRow(String day) {
    final hours = _hours[day]!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                context.tr(_dayLabel(day)),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (!hours.closed) ...[
              TextButton(
                onPressed: () => _pickTime(day, opening: true),
                child: Text(hours.open),
              ),
              const Text('–'),
              TextButton(
                onPressed: () => _pickTime(day, opening: false),
                child: Text(hours.close),
              ),
            ],
            Switch.adaptive(
              value: !hours.closed,
              onChanged: (open) => setState(() {
                _hours[day] = BusinessHour(
                  day: day,
                  open: hours.open,
                  close: hours.close,
                  closed: !open,
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTime(String day, {required bool opening}) async {
    final current = _hours[day]!;
    final source = opening ? current.open : current.close;
    final parts = source.split(':');
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts.first) ?? 9,
        minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
      ),
    );
    if (selected == null || !mounted) return;
    final value =
        '${selected.hour.toString().padLeft(2, '0')}:${selected.minute.toString().padLeft(2, '0')}';
    setState(() {
      _hours[day] = BusinessHour(
        day: day,
        open: opening ? value : current.open,
        close: opening ? current.close : value,
        closed: false,
      );
    });
  }

  void _apply() => Navigator.pop(
    context,
    RestaurantSettingsDraft(
      hours: [for (final day in _days) _hours[day]!],
      fulfillmentOptions: _fulfillment.toList(growable: false),
      contact: BusinessContact(
        phone: _phone.text.trim(),
        whatsapp: _whatsapp.text.trim(),
      ),
    ),
  );

  String _dayLabel(String day) => '${day[0].toUpperCase()}${day.substring(1)}';
}
