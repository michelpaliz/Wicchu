import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../domain/community_models.dart';

class AnimatedNeonBorder extends StatefulWidget {
  const AnimatedNeonBorder({
    super.key,
    required this.child,
    required this.color,
    required this.enabled,
    required this.animation,
    required this.durationSeconds,
    this.borderRadius = const BorderRadius.all(Radius.circular(999)),
    this.padding = const EdgeInsets.all(3),
    this.strokeWidth = 2,
    this.bottomEdgeOnly = false,
  });

  final Widget child;
  final Color color;
  final bool enabled;
  final NeonBorderAnimation animation;
  final double durationSeconds;
  final BorderRadius borderRadius;
  final EdgeInsets padding;
  final double strokeWidth;
  final bool bottomEdgeOnly;

  @override
  State<AnimatedNeonBorder> createState() => _AnimatedNeonBorderState();
}

class _AnimatedNeonBorderState extends State<AnimatedNeonBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  bool _reducedMotion = false;

  Duration get _duration => Duration(
    milliseconds: (widget.durationSeconds.clamp(2, 12) * 1000).round(),
  );

  bool get _shouldAnimate =>
      widget.enabled &&
      widget.animation != NeonBorderAnimation.staticGlow &&
      !_reducedMotion;

  @override
  void initState() {
    super.initState();
    _controller.duration = _duration;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (_reducedMotion != reduced) _reducedMotion = reduced;
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant AnimatedNeonBorder oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  void _syncAnimation() {
    final durationChanged = _controller.duration != _duration;
    _controller.duration = _duration;
    if (_shouldAnimate) {
      if (!_controller.isAnimating || durationChanged) _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _NeonBorderPainter(
      progress: _controller,
      color: widget.color,
      enabled: widget.enabled,
      animation: _reducedMotion
          ? NeonBorderAnimation.staticGlow
          : widget.animation,
      borderRadius: widget.borderRadius,
      strokeWidth: widget.strokeWidth,
      bottomEdgeOnly: widget.bottomEdgeOnly,
    ),
    child: Padding(padding: widget.padding, child: widget.child),
  );
}

class _NeonBorderPainter extends CustomPainter {
  _NeonBorderPainter({
    required Animation<double> progress,
    required this.color,
    required this.enabled,
    required this.animation,
    required this.borderRadius,
    required this.strokeWidth,
    required this.bottomEdgeOnly,
  }) : progress = progress,
       super(repaint: progress);

  final Animation<double> progress;
  final Color color;
  final bool enabled;
  final NeonBorderAnimation animation;
  final BorderRadius borderRadius;
  final double strokeWidth;
  final bool bottomEdgeOnly;

  Paint _stroke(Color paintColor, double width, {double blur = 0}) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = paintColor
    ..maskFilter = blur > 0 ? MaskFilter.blur(BlurStyle.normal, blur) : null;

  void _paintGlow(Canvas canvas, Path path, double intensity) {
    canvas.drawPath(
      path,
      _stroke(
        color.withValues(alpha: .24 * intensity),
        strokeWidth + 5,
        blur: 9,
      ),
    );
    canvas.drawPath(
      path,
      _stroke(
        color.withValues(alpha: .68 * intensity),
        strokeWidth + 1.5,
        blur: 4,
      ),
    );
    canvas.drawPath(
      path,
      _stroke(color.withValues(alpha: .95 * intensity), strokeWidth),
    );
  }

  void _paintSnake(Canvas canvas, Path path) {
    canvas.drawPath(path, _stroke(color.withValues(alpha: .18), strokeWidth));
    final metric = path.computeMetrics().firstOrNull;
    if (metric == null || metric.length == 0) return;
    final head = progress.value * metric.length;
    final segmentLength = metric.length * .24;
    for (var layer = 0; layer < 4; layer++) {
      final length = segmentLength * (1 - layer * .17);
      final end = head - (segmentLength * layer * .12);
      final segment = _wrappedSegment(metric, end - length, end);
      final alpha = .22 + layer * .16;
      canvas.drawPath(
        segment,
        _stroke(
          color.withValues(alpha: alpha),
          strokeWidth + (4 - layer),
          blur: layer < 2 ? 7 : 2,
        ),
      );
    }
    final spark = _wrappedSegment(
      metric,
      head - metric.length * .018,
      head + metric.length * .018,
    );
    canvas.drawPath(spark, _stroke(Colors.white, strokeWidth + 1));
  }

  Path _wrappedSegment(PathMetric metric, double start, double end) {
    final length = metric.length;
    var normalizedStart = start % length;
    var normalizedEnd = end % length;
    if (normalizedStart < 0) normalizedStart += length;
    if (normalizedEnd < 0) normalizedEnd += length;
    if (normalizedStart <= normalizedEnd) {
      return metric.extractPath(normalizedStart, normalizedEnd);
    }
    return Path()
      ..addPath(metric.extractPath(normalizedStart, length), Offset.zero)
      ..addPath(metric.extractPath(0, normalizedEnd), Offset.zero);
  }

  void _paintAurora(Canvas canvas, Path path, Rect rect) {
    final secondary = Color.lerp(color, const Color(0xff00e5ff), .65)!;
    final tertiary = Color.lerp(color, const Color(0xffff2bd6), .65)!;
    final paint = _stroke(Colors.white, strokeWidth + 1.5)
      ..shader = SweepGradient(
        colors: [color, secondary, tertiary, color],
        transform: GradientRotation(progress.value * math.pi * 2),
      ).createShader(rect);
    canvas.drawPath(
      path,
      _stroke(color.withValues(alpha: .42), strokeWidth + 5, blur: 8),
    );
    canvas.drawPath(path, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final inset = strokeWidth / 2 + 1;
    final rect = Offset.zero & size;
    final path = bottomEdgeOnly
        ? (Path()
            ..moveTo(0, size.height - inset)
            ..lineTo(size.width, size.height - inset))
        : (Path()..addRRect(borderRadius.toRRect(rect.deflate(inset))));
    if (!enabled) {
      canvas.drawPath(path, _stroke(color, strokeWidth));
      return;
    }
    switch (animation) {
      case NeonBorderAnimation.staticGlow:
        _paintGlow(canvas, path, 1);
      case NeonBorderAnimation.snake:
        _paintSnake(canvas, path);
      case NeonBorderAnimation.breathing:
        final wave = (math.sin(progress.value * math.pi * 2) + 1) / 2;
        _paintGlow(canvas, path, .38 + wave * .62);
      case NeonBorderAnimation.aurora:
        _paintAurora(canvas, path, rect);
    }
  }

  @override
  bool shouldRepaint(covariant _NeonBorderPainter oldDelegate) =>
      color != oldDelegate.color ||
      enabled != oldDelegate.enabled ||
      animation != oldDelegate.animation ||
      borderRadius != oldDelegate.borderRadius ||
      strokeWidth != oldDelegate.strokeWidth ||
      bottomEdgeOnly != oldDelegate.bottomEdgeOnly;
}
