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
    this.height = 48,
    this.compact = false,
  });

  final bool compact;
  final FeedNavigationStyle style;
  final double height;
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
  Widget build(BuildContext context) {
    if (widget.compact && widget.style == FeedNavigationStyle.underline) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final textStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          );
          var itemWidth = 0.0;
          for (final label in widget.labels) {
            final painter = TextPainter(
              text: TextSpan(text: label, style: textStyle),
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
            )..layout();
            if (painter.width + 16 > itemWidth) itemWidth = painter.width + 16;
            painter.dispose();
          }
          final columns = widget.labels.isEmpty
              ? 1
              : (constraints.maxWidth / itemWidth).floor().clamp(
                  1,
                  widget.labels.length,
                );
          final count = columns >= widget.labels.length
              ? widget.labels.length
              : columns >= 2
              ? 2
              : 1;
          return Wrap(
            children: [
              for (var index = 0; index < widget.labels.length; index++)
                SizedBox(
                  width: constraints.maxWidth / (count == 0 ? 1 : count),
                  child: _SectionTab(
                    height: widget.height,
                    compact: true,
                    label: widget.labels[index],
                    selected: widget.selectedIndex == index,
                    onSelected: () => widget.onSelected(index),
                  ),
                ),
            ],
          );
        },
      );
    }
    return SizedBox(
      height: widget.height,
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
                        height: widget.height,
                        label: widget.labels[index],
                        selected: widget.selectedIndex == index,
                        onSelected: () => widget.onSelected(index),
                      )
                    : FeedCategoryChip(
                        height: widget.height,
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
}

class _SectionTab extends StatelessWidget {
  const _SectionTab({
    required this.height,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.compact = false,
  });

  final bool compact;
  final double height;
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
          constraints: BoxConstraints(minHeight: height),
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 12,
            vertical: compact ? 12 : 0,
          ),
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
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontSize: compact ? 12 : null,
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
