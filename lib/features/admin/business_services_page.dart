import 'package:flutter/material.dart';

import '../../domain/community_models.dart';
import '../../localization/app_language.dart';
import '../community/business_service_icon.dart';

class BusinessServicesPage extends StatefulWidget {
  const BusinessServicesPage({
    super.key,
    required this.services,
    required this.onChanged,
  });

  final Set<BusinessService> services;
  final ValueChanged<Set<BusinessService>> onChanged;

  @override
  State<BusinessServicesPage> createState() => _BusinessServicesPageState();
}

class _BusinessServicesPageState extends State<BusinessServicesPage> {
  late final _businessServices = {...widget.services};

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('Main services'))),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('Main services'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${_businessServices.length}/3',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            context.tr('Choose up to 3 services that describe your business.'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final service in BusinessService.values)
                FilterChip(
                  showCheckmark: false,
                  avatar: Icon(
                    businessServiceIcon(service),
                    size: 20,
                    color: _businessServices.contains(service)
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(context.tr(service.label)),
                      if (_businessServices.contains(service)) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.check_circle,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ],
                  ),
                  labelStyle: TextStyle(
                    color: _businessServices.contains(service)
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                  selectedColor: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: .12),
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  side: BorderSide(
                    color: _businessServices.contains(service)
                        ? Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: .25)
                        : Theme.of(context).colorScheme.outline,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  selected: _businessServices.contains(service),
                  onSelected: (selected) {
                    if (selected && _businessServices.length >= 3) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            context.tr(
                              'Choose no more than 3 business services.',
                            ),
                          ),
                        ),
                      );
                      return;
                    }
                    setState(() {
                      if (selected) {
                        _businessServices.add(service);
                      } else {
                        _businessServices.remove(service);
                      }
                    });
                    widget.onChanged(Set.unmodifiable(_businessServices));
                  },
                ),
            ],
          ),

          const SizedBox(height: 16),
          Text(
            context.tr('Finish by saving changes in settings.'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}
