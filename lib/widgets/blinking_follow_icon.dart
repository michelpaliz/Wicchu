import 'package:flutter/material.dart';

/// Briefly draws attention to the header action without hiding its hit target.
class BlinkingFollowIcon extends StatefulWidget {
  const BlinkingFollowIcon({
    super.key,
    required this.child,
    this.enabled = true,
  });
  final Widget child;
  final bool enabled;

  @override
  State<BlinkingFollowIcon> createState() => _BlinkingFollowIconState();
}

class _BlinkingFollowIconState extends State<BlinkingFollowIcon>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  );
  late final _opacity = Tween<double>(
    begin: 1,
    end: .35,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  bool? _animate;

  void _syncAnimation() {
    final animate = widget.enabled && !MediaQuery.disableAnimationsOf(context);
    if (animate == _animate) return;
    _animate = animate;
    _controller.stop();
    _controller.value = 0;
    if (animate) {
      _controller.repeat(reverse: true, count: 6).whenCompleteOrCancel(() {
        if (mounted && !_controller.isAnimating) _controller.value = 0;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant BlinkingFollowIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _opacity,
    alwaysIncludeSemantics: true,
    child: widget.child,
  );
}
