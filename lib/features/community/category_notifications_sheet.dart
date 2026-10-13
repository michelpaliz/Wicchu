import 'package:flutter/material.dart';

import '../../domain/community_models.dart';
import '../../localization/app_language.dart';
import '../../theme/wicchu_icons.dart';
import '../../widgets/category_symbol.dart';

/// Edits the existing scoped preferences; closing discards unsaved changes.
class CategoryNotificationsSheet extends StatefulWidget {
  const CategoryNotificationsSheet({
    super.key,
    required this.categories,
    required this.initialOrder,
    required this.defaultOrder,
    required this.initialPreferences,
    this.business = false,
  });

  final List<CommunityCategory> categories;
  final List<String> initialOrder;
  final List<String> defaultOrder;
  final ScopedNotificationPreferences initialPreferences;
  final bool business;

  @override
  State<CategoryNotificationsSheet> createState() =>
      _CategoryNotificationsSheetState();
}

class _CategoryNotificationsSheetState
    extends State<CategoryNotificationsSheet> {
  late ScopedNotificationPreferences _preferences = widget.initialPreferences;
  late List<String> _order = [...widget.initialOrder];
  bool _resetOrder = false;

  bool _enabled(String id) =>
      _preferences.mode == ContentNotificationMode.all ||
      (_preferences.mode == ContentNotificationMode.selected &&
          _preferences.selectedCategoryIds.contains(id));

  void _toggleCategory(String id, bool enabled) {
    final selected = _preferences.mode == ContentNotificationMode.all
        ? widget.categories.map((c) => c.id).toSet()
        : _preferences.mode == ContentNotificationMode.selected
        ? _preferences.selectedCategoryIds.toSet()
        : <String>{};
    enabled ? selected.add(id) : selected.remove(id);
    setState(
      () => _preferences = _preferences.copyWith(
        mode: selected.isEmpty
            ? ContentNotificationMode.muted
            : selected.length == widget.categories.length
            ? ContentNotificationMode.all
            : ContentNotificationMode.selected,
        selectedCategoryIds: selected.toList(),
      ),
    );
  }

  Widget _panel(Widget child) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      clipBehavior: Clip.antiAlias,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .85,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.tr('Category notifications'),
                      style: text.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(WicchuIcons.x),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Text(
                      context.tr('Choose the content you want to hear about.'),
                      style: text.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  _panel(
                    SwitchListTile.adaptive(
                      key: const ValueKey('all-category-notifications'),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      secondary: CircleAvatar(
                        backgroundColor: scheme.primaryContainer,
                        foregroundColor: scheme.onPrimaryContainer,
                        child: const Icon(WicchuIcons.bellFill),
                      ),
                      title: Text(
                        context.tr('All new posts'),
                        style: text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        context.tr('Receive posts from every category.'),
                      ),
                      value: _preferences.mode == ContentNotificationMode.all,
                      onChanged: (value) => setState(
                        () => _preferences = _preferences.copyWith(
                          mode: value
                              ? ContentNotificationMode.all
                              : ContentNotificationMode.muted,
                          selectedCategoryIds: const [],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 20, 4, 6),
                    child: Text(
                      context.tr('Or choose specific categories'),
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
                    child: Text(
                      context.tr('Turn on the categories that interest you.'),
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (_preferences.mode == ContentNotificationMode.important)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        context.tr('Important announcements only'),
                        style: text.bodyMedium?.copyWith(color: scheme.primary),
                      ),
                    ),
                  if (widget.categories.isNotEmpty)
                    _panel(
                      Column(
                        children: [
                          for (final (index, category)
                              in widget.categories.indexed) ...[
                            if (index > 0)
                              Divider(
                                height: 1,
                                indent: 64,
                                endIndent: 16,
                                color: scheme.outlineVariant,
                              ),
                            SwitchListTile.adaptive(
                              key: ValueKey(
                                'category-notification-${category.id}',
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              secondary: CircleAvatar(
                                backgroundColor: scheme.primaryContainer,
                                child: CategorySymbol(
                                  category.icon,
                                  color: scheme.onPrimaryContainer,
                                ),
                              ),
                              title: Text(
                                context.tr(category.name),
                                style: text.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: category.description.trim().isEmpty
                                  ? null
                                  : Text(
                                      category.description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                              value: _enabled(category.id),
                              onChanged: (value) =>
                                  _toggleCategory(category.id, value),
                            ),
                          ],
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  ExpansionTile(
                    title: Text(context.tr('More notification options')),
                    children: [
                      SwitchListTile.adaptive(
                        title: Text(context.tr('Push notifications')),
                        subtitle: Text(
                          context.tr('Receive alerts on your device'),
                        ),
                        value: _preferences.pushEnabled,
                        onChanged: (value) => setState(
                          () => _preferences = _preferences.copyWith(
                            pushEnabled: value,
                          ),
                        ),
                      ),
                      SwitchListTile.adaptive(
                        title: Text(context.tr('Important announcements only')),
                        value:
                            _preferences.mode ==
                            ContentNotificationMode.important,
                        onChanged: (value) => setState(
                          () => _preferences = _preferences.copyWith(
                            mode: value
                                ? ContentNotificationMode.important
                                : ContentNotificationMode.muted,
                            selectedCategoryIds: const [],
                          ),
                        ),
                      ),
                      if (widget.business)
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final type in ['posts', 'offers', 'events'])
                              FilterChip(
                                label: Text(
                                  context.tr(switch (type) {
                                    'offers' => 'Offers',
                                    'events' => 'Events',
                                    _ => 'Posts',
                                  }),
                                ),
                                selected: _preferences.contentTypes.contains(
                                  type,
                                ),
                                onSelected: (selected) => setState(() {
                                  final types = _preferences.contentTypes
                                      .toSet();
                                  selected
                                      ? types.add(type)
                                      : types.remove(type);
                                  _preferences = _preferences.copyWith(
                                    contentTypes: types.toList(),
                                  );
                                }),
                              ),
                          ],
                        ),
                    ],
                  ),
                  ExpansionTile(
                    title: Text(context.tr('Your category order')),
                    children: [
                      Text(
                        context.tr(
                          'Drag categories to arrange them. Changes only affect your view.',
                        ),
                      ),
                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        buildDefaultDragHandles: false,
                        itemCount: _order.length,
                        onReorderItem: (from, to) => setState(() {
                          _resetOrder = false;
                          _order.insert(to, _order.removeAt(from));
                        }),
                        itemBuilder: (context, index) {
                          final category = widget.categories
                              .where((c) => c.id == _order[index])
                              .firstOrNull;
                          return ListTile(
                            key: ValueKey('category-order-${_order[index]}'),
                            title: Text(context.tr(category?.name ?? 'All')),
                            trailing: ReorderableDragStartListener(
                              index: index,
                              child: const Padding(
                                padding: EdgeInsets.all(12),
                                child: Icon(WicchuIcons.arrowsDownUp),
                              ),
                            ),
                          );
                        },
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          _order = [...widget.defaultOrder];
                          _resetOrder = true;
                        }),
                        child: Text(context.tr('Restore default order')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => setState(
                        () => _preferences = _preferences.copyWith(
                          mode: ContentNotificationMode.all,
                          selectedCategoryIds: const [],
                        ),
                      ),
                      icon: const Icon(WicchuIcons.arrowArcLeft),
                      label: Text(context.tr('Reset selection')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, (
                        order: _resetOrder ? <String>[] : _order,
                        preferences: _preferences,
                      )),
                      child: Text(context.tr('Save changes')),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
