import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Reports a post once it occupies a meaningful part of the visible viewport,
/// rather than when a sliver creates its off-screen cached widget.
class VisiblePostObserver extends StatefulWidget {
  const VisiblePostObserver({
    super.key,
    required this.onSeen,
    required this.child,
  });
  final VoidCallback onSeen;
  final Widget child;

  @override
  State<VisiblePostObserver> createState() => _VisiblePostObserverState();
}

class _VisiblePostObserverState extends State<VisiblePostObserver>
    with WidgetsBindingObserver {
  ScrollPosition? _position;
  bool _scheduled = false;
  bool _reported = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (position != _position) {
      _position?.removeListener(_schedule);
      _position = position;
      _position?.addListener(_schedule);
    }
    _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _schedule();
  }

  void _schedule() {
    if (_scheduled || _reported) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted ||
          _reported ||
          !TickerMode.valuesOf(context).enabled ||
          ModalRoute.of(context)?.isCurrent == false) {
        return;
      }
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
      final box = context.findRenderObject();
      if (box is! RenderBox || !box.hasSize || !box.attached) return;
      final Object? viewport = RenderAbstractViewport.maybeOf(box);
      if (viewport is! RenderBox || !viewport.hasSize) return;
      final bounds = box.localToGlobal(Offset.zero) & box.size;
      final viewportBounds =
          viewport.localToGlobal(Offset.zero) & viewport.size;
      final visible = bounds.intersect(viewportBounds);
      if (visible.isEmpty || bounds.isEmpty) return;
      if (visible.height >=
              math.min(bounds.height, viewportBounds.height) * .5 &&
          visible.width >= math.min(bounds.width, viewportBounds.width) * .5) {
        _reported = true;
        widget.onSeen();
      }
    });
  }

  @override
  void dispose() {
    _position?.removeListener(_schedule);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
