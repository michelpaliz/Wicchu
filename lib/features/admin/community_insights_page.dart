import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/community_models.dart';
import '../../data/authenticated_api_client.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';

class CommunityInsightsPage extends StatefulWidget {
  const CommunityInsightsPage({
    super.key,
    required this.community,
    required this.repository,
  });

  final Community community;
  final CommunityRepository repository;

  @override
  State<CommunityInsightsPage> createState() => _CommunityInsightsPageState();
}

class _CommunityInsightsPageState extends State<CommunityInsightsPage> {
  late Future<CommunityInsights> _insights;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _insights = widget.repository.getCommunityInsights(widget.community.id);
  }

  Future<void> _refresh() async {
    setState(_reload);
    try {
      await _insights;
    } catch (_) {
      // FutureBuilder presents the failure and retry action.
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        context.tr('Community Insights'),
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
    ),
    body: FutureBuilder<CommunityInsights>(
      future: _insights,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.insights_outlined,
                    size: 44,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    snapshot.error is ApiException &&
                            (snapshot.error as ApiException).statusCode == 404
                        ? context.tr(
                            'Community statistics are not available yet.',
                          )
                        : context.trError(snapshot.error!),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _refresh,
                    child: Text(context.tr('Retry')),
                  ),
                ],
              ),
            ),
          );
        }
        return _InsightsContent(insights: snapshot.data!, onRefresh: _refresh);
      },
    ),
  );
}

class _InsightsContent extends StatefulWidget {
  const _InsightsContent({required this.insights, required this.onRefresh});
  final CommunityInsights insights;
  final Future<void> Function() onRefresh;

  @override
  State<_InsightsContent> createState() => _InsightsContentState();
}

class _InsightsContentState extends State<_InsightsContent> {
  bool _showTip = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final insights = widget.insights;
    final points = [...insights.memberGrowth]
      ..sort((a, b) => a.date.compareTo(b.date));
    Widget heading(String label) => Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10),
      child: Text(
        context.tr(label),
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    final border = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(color: colors.onSurface.withValues(alpha: .08)),
    );
    Widget card(Widget child) => Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: colors.surface,
      shape: border,
      child: child,
    );
    Widget badge(IconData icon) => CircleAvatar(
      radius: 20,
      backgroundColor: colors.primary.withValues(alpha: .08),
      child: Icon(icon, size: 22, color: colors.primary),
    );
    Widget metric(String value, String label, IconData icon) => card(
      Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            badge(icon),
            const SizedBox(height: 10),
            Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              context.tr(label),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
    Widget activity(IconData icon, String label, int value) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          badge(icon),
          const SizedBox(width: 12),
          Expanded(
            child: Text(context.tr(label), style: theme.textTheme.bodyMedium),
          ),
          const SizedBox(width: 8),
          Text(
            _number(value),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Text(
            context.tr('A summary of your community’s activity and growth.'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: .07),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                context.tr('Last 30 days'),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.primary,
                ),
              ),
            ),
          ),
          heading('Overview'),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns =
                  constraints.maxWidth < 300 ||
                      MediaQuery.textScalerOf(context).scale(1) > 1.4
                  ? 1
                  : 2;
              final width =
                  (constraints.maxWidth - (columns - 1) * 10) / columns;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: width,
                    child: metric(
                      _number(insights.monthlyActiveUsers),
                      'Monthly active',
                      Icons.groups_outlined,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: metric(
                      _number(insights.weeklyActiveUsers),
                      'Weekly active',
                      Icons.person_outline,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: metric(
                      '${_decimal(insights.monthlyActivityRate)}%',
                      'Monthly activity rate',
                      Icons.bar_chart_rounded,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: metric(
                      _number(insights.posts30d),
                      'Posts in the last 30 days',
                      Icons.article_outlined,
                    ),
                  ),
                ],
              );
            },
          ),
          heading('Member growth'),
          card(
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        _number(insights.totalMembers),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        context.tr('Members'),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.tr('+{count} in the last 30 days', {
                      'count': _number(insights.newMembers30d),
                    }),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  if (insights.newMembersChangePercent case final change?) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          change >= 0 ? Icons.trending_up : Icons.trending_down,
                          size: 18,
                          color: change >= 0 ? colors.primary : colors.error,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            context.tr(
                              '{change}% compared with the previous period',
                              {
                                'change':
                                    '${change >= 0 ? '+' : ''}${_decimal(change)}',
                              },
                            ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: change >= 0
                                  ? colors.primary
                                  : colors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  if (points.length > 1)
                    _GrowthChart(points: points)
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        context.tr(
                          'More history is needed to show member growth.',
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          heading('Activity in the last 30 days'),
          card(
            Column(
              children: [
                activity(Icons.article_outlined, 'Posts', insights.posts30d),
                Divider(
                  height: 1,
                  indent: 66,
                  endIndent: 14,
                  color: colors.onSurface.withValues(alpha: .06),
                ),
                activity(
                  Icons.chat_bubble_outline,
                  'Comments',
                  insights.comments30d,
                ),
                Divider(
                  height: 1,
                  indent: 66,
                  endIndent: 14,
                  color: colors.onSurface.withValues(alpha: .06),
                ),
                activity(
                  Icons.favorite_border,
                  'Reactions',
                  insights.reactions30d,
                ),
                Divider(
                  height: 1,
                  indent: 66,
                  endIndent: 14,
                  color: colors.onSurface.withValues(alpha: .06),
                ),
                activity(
                  Icons.group_add_outlined,
                  'New members',
                  insights.newMembers30d,
                ),
              ],
            ),
          ),
          if (_showTip) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: .06),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  badge(Icons.lightbulb_outline),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('Tip'),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.tr(
                            'Keep sharing useful local content and invite members to take part.',
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: context.tr('Close'),
                    onPressed: () => setState(() => _showTip = false),
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: MediaQuery.paddingOf(context).bottom),
        ],
      ),
    );
  }
}

class _GrowthChart extends StatelessWidget {
  const _GrowthChart({required this.points});
  final List<MemberGrowthPoint> points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maximum = math.max(1, points.map((p) => p.members).reduce(math.max));
    final labels = {maximum, (maximum / 2).round(), 0}.toList();
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final dates = MaterialLocalizations.of(context);
    return Semantics(
      label:
          '${context.tr('Member growth over the last 30 days')}: ${points.map((p) => '${dates.formatShortMonthDay(p.date.toLocal())}: ${p.members}').join(', ')}',
      child: Column(
        children: [
          SizedBox(
            height: 150,
            child: Row(
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final value in labels)
                      Text(_number(value), style: labelStyle),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: SizedBox.expand(
                      child: CustomPaint(
                        painter: _GrowthChartPainter(
                          points: points,
                          maximum: maximum.toDouble(),
                          color: theme.colorScheme.primary,
                          gridColor: theme.colorScheme.onSurface.withValues(
                            alpha: .08,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  dates.formatShortMonthDay(points.first.date.toLocal()),
                  style: labelStyle,
                ),
              ),
              Flexible(
                child: Text(
                  dates.formatShortMonthDay(points.last.date.toLocal()),
                  style: labelStyle,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GrowthChartPainter extends CustomPainter {
  const _GrowthChartPainter({
    required this.points,
    required this.maximum,
    required this.color,
    required this.gridColor,
  });
  final List<MemberGrowthPoint> points;
  final double maximum;
  final Color color;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (final fraction in [0.0, .5, 1.0]) {
      final y = size.height * fraction;
      for (double x = 0; x < size.width; x += 7) {
        canvas.drawLine(
          Offset(x, y),
          Offset(math.min(x + 3, size.width), y),
          grid,
        );
      }
    }
    final start = points.first.date.millisecondsSinceEpoch;
    final duration = math.max(
      1,
      points.last.date.millisecondsSinceEpoch - start,
    );
    final positions = points
        .map(
          (p) => Offset(
            (p.date.millisecondsSinceEpoch - start) / duration * size.width,
            size.height * (1 - p.members.clamp(0, maximum) / maximum),
          ),
        )
        .toList();
    final path = Path()..moveTo(positions.first.dx, positions.first.dy);
    for (final point in positions.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    final area = Path.from(path)
      ..lineTo(positions.last.dx, size.height)
      ..lineTo(positions.first.dx, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: .18), color.withValues(alpha: .02)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
    for (final point in positions) {
      canvas.drawCircle(point, 3, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_GrowthChartPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.maximum != maximum ||
      oldDelegate.color != color ||
      oldDelegate.gridColor != gridColor;
}

String _number(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer(value < 0 ? '-' : '');
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
    buffer.write(digits[index]);
  }
  return buffer.toString();
}

String _decimal(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1);
