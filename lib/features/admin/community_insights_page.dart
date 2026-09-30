import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/community_models.dart';
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
    await _insights;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('Community Insights'))),
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
                  Text(
                    context.trError(snapshot.error!),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => setState(_reload),
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

class _InsightsContent extends StatelessWidget {
  const _InsightsContent({required this.insights, required this.onRefresh});

  final CommunityInsights insights;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: EdgeInsets.zero,
            color: colors.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _number(insights.totalMembers),
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: colors.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    context.tr('Members'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.tr('+{count} in the last 30 days', {
                      'count': _number(insights.newMembers30d),
                    }),
                  ),
                  if (insights.newMembersChangePercent case final change?) ...[
                    const SizedBox(height: 3),
                    Text(
                      context.tr(
                        '{change}% compared with the previous period',
                        {
                          'change':
                              '${change >= 0 ? '+' : ''}${_decimal(change)}',
                        },
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  value: _number(insights.monthlyActiveUsers),
                  label: 'Monthly active',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  value: _number(insights.weeklyActiveUsers),
                  label: 'Weekly active',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _MetricCard(
            value: '${_decimal(insights.monthlyActivityRate)}%',
            label: 'Monthly activity rate',
          ),
          if (insights.memberGrowth.length > 1) ...[
            const SizedBox(height: 24),
            Text(
              context.tr('Member growth'),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                child: Semantics(
                  label: context.tr('Member growth over the last 30 days'),
                  child: SizedBox(
                    height: 150,
                    child: CustomPaint(
                      painter: _GrowthChartPainter(
                        points: insights.memberGrowth,
                        color: colors.primary,
                        gridColor: colors.outlineVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            context.tr('Last 30 days'),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                _ActivityRow(
                  icon: Icons.article_outlined,
                  label: 'Posts',
                  value: insights.posts30d,
                ),
                const Divider(height: 1, indent: 56),
                _ActivityRow(
                  icon: Icons.chat_bubble_outline,
                  label: 'Comments',
                  value: insights.comments30d,
                ),
                const Divider(height: 1, indent: 56),
                _ActivityRow(
                  icon: Icons.favorite_border,
                  label: 'Reactions',
                  value: insights.reactions30d,
                ),
              ],
            ),
          ),
          SizedBox(height: 16 + MediaQuery.paddingOf(context).bottom),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 3),
          Text(
            context.tr(label),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    ),
  );
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
    title: Text(context.tr(label)),
    trailing: Text(
      _number(value),
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    ),
  );
}

class _GrowthChartPainter extends CustomPainter {
  const _GrowthChartPainter({
    required this.points,
    required this.color,
    required this.gridColor,
  });
  final List<MemberGrowthPoint> points;
  final Color color;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final values = points.map((point) => point.members.toDouble()).toList();
    final minimum = values.reduce(math.min);
    final maximum = values.reduce(math.max);
    final range = math.max(1, maximum - minimum);
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (final fraction in const [0.0, .5, 1.0]) {
      final y = size.height * fraction;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final path = Path();
    for (var index = 0; index < values.length; index++) {
      final x = values.length == 1
          ? 0.0
          : size.width * index / (values.length - 1);
      final y = size.height - ((values[index] - minimum) / range * size.height);
      index == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_GrowthChartPainter oldDelegate) =>
      oldDelegate.points != points ||
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
