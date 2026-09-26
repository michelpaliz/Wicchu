import 'package:flutter/material.dart';

import 'feed_category_chip.dart';

enum FeedNavigationStyle { pills, underline }

/// Shared horizontal navigation for feeds and community profile sections.
class FeedFilterBar extends StatefulWidget {
  const FeedFilterBar({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.style = FeedNavigationStyle.pills,
  });

  final FeedNavigationStyle style;
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  State<FeedFilterBar> createState() => _FeedFilterBarState();
}

class _FeedFilterBarState extends State<FeedFilterBar> {
  final _controller = ScrollController(keepScrollOffset: false);
  final _keys = <int, GlobalKey>{};

  @override
  void didUpdateWidget(covariant FeedFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_controller.hasClients) return;
        final target = _keys[widget.selectedIndex]?.currentContext
            ?.findRenderObject();
        if (target != null) {
          _controller.position.ensureVisible(
            target,
            alignment: .5,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: SingleChildScrollView(
      controller: _controller,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(left: 16, right: 24),
      child: Row(
        children: [
          for (var index = 0; index < widget.labels.length; index++)
            Padding(
              key: _keys.putIfAbsent(index, GlobalKey.new),
              padding: const EdgeInsets.only(right: 4),
              child: widget.style == FeedNavigationStyle.underline
                  ? _SectionTab(
                      label: widget.labels[index],
                      selected: widget.selectedIndex == index,
                      onSelected: () => widget.onSelected(index),
                    )
                  : FeedCategoryChip(
                      label: widget.labels[index],
                      selected: widget.selectedIndex == index,
                      onSelected: () => widget.onSelected(index),
                    ),
            ),
        ],
      ),
    ),
  );
}

class _SectionTab extends StatelessWidget {
  const _SectionTab({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onSelected,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? scheme.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
