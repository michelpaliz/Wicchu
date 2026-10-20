import 'package:flutter/material.dart';
import 'package:wicchu/theme/wicchu_icons.dart';

import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';

class CommunityRewardsPage extends StatefulWidget {
  const CommunityRewardsPage({
    super.key,
    required this.community,
    required this.repository,
  });

  final Community community;
  final CommunityRepository repository;

  @override
  State<CommunityRewardsPage> createState() => _CommunityRewardsPageState();
}

class _CommunityRewardsPageState extends State<CommunityRewardsPage> {
  late Future<CommunityInsights> _future = _load();

  Future<CommunityInsights> _load() =>
      widget.repository.getCommunityInsights(widget.community.id);

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        context.tr('Rewards'),
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      ),
    ),
    body: FutureBuilder<CommunityInsights>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: FilledButton(
              onPressed: _refresh,
              child: Text(context.tr('Retry')),
            ),
          );
        }
        final insights = snapshot.data!;
        final monetization = insights.monetization;
        final enrollment = monetization.enrollment;
        if (!enrollment.requested && !monetization.eligible) {
          return _RewardRoadmap(
            communityName: widget.community.name,
            insights: insights,
            onRefresh: _refresh,
          );
        }
        if (!enrollment.requested || enrollment.status == 'rejected') {
          return _RewardRequestForm(
            canRequest: widget.community.myRole == CommunityRole.owner,
            reviewNote: enrollment.reviewNote,
            initialCountryCode: enrollment.countryCode,
            initialCountryName: enrollment.countryName,
            initialContactEmail: enrollment.contactEmail,
            onSubmit:
                ({
                  required countryCode,
                  countryName,
                  required contactEmail,
                  note,
                }) async {
                  await widget.repository.requestCommunityRewards(
                    widget.community.id,
                    countryCode: countryCode,
                    countryName: countryName,
                    contactEmail: contactEmail,
                    note: note,
                  );
                  await _refresh();
                },
          );
        }
        if (enrollment.status == 'pending') {
          return _RewardRequestPending(enrollment: enrollment);
        }
        if (!insights.monetization.enrollment.accepted) {
          return _RewardEnrollment(
            canAccept: widget.community.myRole == CommunityRole.owner,
            countryCode: enrollment.countryCode ?? 'ES',
            onAccept: (countryCode) async {
              await widget.repository.acceptCommunityRewardTerms(
                widget.community.id,
                countryCode: countryCode,
              );
              await _refresh();
            },
          );
        }
        return _RewardDetails(insights: insights, onRefresh: _refresh);
      },
    ),
  );
}

typedef _RewardRequirement = ({String label, num value, num target});

class _RewardRoadmap extends StatefulWidget {
  const _RewardRoadmap({
    required this.communityName,
    required this.insights,
    required this.onRefresh,
  });

  final String communityName;
  final CommunityInsights insights;
  final Future<void> Function() onRefresh;

  @override
  State<_RewardRoadmap> createState() => _RewardRoadmapState();
}

class _RewardRoadmapState extends State<_RewardRoadmap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  );
  bool _started = false;

  CommunityRewardTier? get _tier {
    final reward = widget.insights.monetization;
    return reward.nextTier ??
        (reward.tiers.isEmpty ? null : reward.tiers.first);
  }

  List<_RewardRequirement> get _requirements {
    final tier = _tier;
    if (tier == null) return const [];
    return [
      (
        label: 'Members',
        value: widget.insights.totalMembers,
        target: tier.memberTarget,
      ),
      (
        label: 'Monthly active members',
        value: widget.insights.monthlyActiveUsers,
        target: tier.monthlyActiveTarget,
      ),
      (
        label: 'Useful posts in 30 days',
        value: widget.insights.posts30d,
        target: tier.postsTarget,
      ),
      (
        label: 'Meaningful interactions in 30 days',
        value: widget.insights.interactions30d,
        target: tier.interactionsTarget,
      ),
      (
        label: 'Unique contributors in 30 days',
        value: widget.insights.uniqueContributors30d,
        target: tier.contributorsTarget,
      ),
    ];
  }

  int get _completed => _requirements
      .where((item) => item.target > 0 && item.value >= item.target)
      .length;

  double get _requirementProgress {
    final requirements = _requirements
        .where((item) => item.target > 0)
        .toList(growable: false);
    if (requirements.isEmpty) return 0;
    return requirements.fold<double>(0, (total, item) {
          return total + (item.value / item.target).clamp(0, 1).toDouble();
        }) /
        requirements.length;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant _RewardRoadmap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.insights.totalMembers == widget.insights.totalMembers &&
        oldWidget.insights.monthlyActiveUsers ==
            widget.insights.monthlyActiveUsers &&
        oldWidget.insights.posts30d == widget.insights.posts30d &&
        oldWidget.insights.interactions30d == widget.insights.interactions30d &&
        oldWidget.insights.uniqueContributors30d ==
            widget.insights.uniqueContributors30d) {
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final requirements = _requirements;
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: widget.onRefresh,
            child: ListView(
              key: const ValueKey('community-rewards-roadmap'),
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              children: [
                Text(
                  widget.communityName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr('Stage 1 of 4 · Active community'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${(_requirementProgress * 100).round()}%',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  context.tr('Progress'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Semantics(
                  label:
                      '${context.tr('Progress')}: ${(_requirementProgress * 100).round()}%',
                  child: LinearProgressIndicator(
                    value: _requirementProgress,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(999),
                    backgroundColor: colors.surfaceContainerHighest,
                  ),
                ),
                const SizedBox(height: 30),
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => _RewardJourneyMap(
                    animationValue: Curves.easeOutCubic.transform(
                      _controller.value,
                    ),
                    requirementProgress: _requirementProgress,
                    onMilestoneTap: (index) =>
                        _showMilestone(context, index, requirements),
                  ),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 330) {
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => _showRewardExplanation(context),
                          icon: const Icon(WicchuIcons.info, size: 17),
                          label: Text(context.tr('How rewards work')),
                        ),
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          WicchuIcons.info,
                          size: 17,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.tr(
                              'Complete stage 1 to unlock the application. Eligibility and monthly rewards still require Wicchu review and are not guaranteed.',
                            ),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(top: BorderSide(color: colors.outlineVariant)),
            ),
            child: FilledButton.icon(
              key: const ValueKey('reward-objectives-action'),
              onPressed: () => _showMilestone(context, 0, requirements),
              icon: const Icon(WicchuIcons.listChecks, size: 19),
              label: Text(context.tr('View my objectives')),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showMilestone(
    BuildContext context,
    int index,
    List<_RewardRequirement> requirements,
  ) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (sheetContext) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: index == 0 ? .52 : .36,
      minChildSize: .30,
      maxChildSize: .86,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text(
            sheetContext.tr(_milestoneTitles[index]),
            style: Theme.of(
              sheetContext,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          Text(
            sheetContext.tr(_milestoneDescriptions[index]),
            style: Theme.of(sheetContext).textTheme.bodySmall,
          ),
          if (index == 0) ...[
            const SizedBox(height: 10),
            Text(
              sheetContext.trCount(
                _completed,
                singular: '{count} of 5 requirement completed',
                plural: '{count} of 5 requirements completed',
              ),
              style: Theme.of(sheetContext).textTheme.labelLarge?.copyWith(
                color: Theme.of(sheetContext).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (index == 0 && requirements.isNotEmpty)
            for (final requirement in requirements)
              _RequirementProgressRow(requirement: requirement)
          else ...[
            Icon(
              WicchuIcons.lockKey,
              size: 34,
              color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              sheetContext.tr(
                index == 3
                    ? 'Rewards are evaluated monthly and remain subject to approval.'
                    : 'Complete the previous stage to continue.',
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (index == 0 && requirements.isEmpty)
            Text(sheetContext.tr('Objectives are not available yet.')),
        ],
      ),
    ),
  );

  Future<void> _showRewardExplanation(
    BuildContext context,
  ) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sheetContext.tr('How rewards work'),
            style: Theme.of(
              sheetContext,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            sheetContext.tr(
              'Complete stage 1 to unlock the application. Eligibility and monthly rewards still require Wicchu review and are not guaranteed.',
            ),
            style: Theme.of(sheetContext).textTheme.bodyMedium,
          ),
        ],
      ),
    ),
  );
}

const _milestoneTitles = [
  'Build an active community',
  'Request access',
  'Review and accept terms',
  'Monthly evaluation and rewards',
];

const _milestoneMapTitles = [
  'Active community',
  'Request access',
  'Wicchu review',
  'Monthly rewards',
];

const _milestoneDescriptions = [
  'Complete these objectives to request access.',
  'The owner can apply after the first milestone is complete.',
  'Wicchu confirms availability before the owner accepts the pilot terms.',
  'Eligible activity is reviewed each month before rewards are approved.',
];

class _RewardJourneyMap extends StatelessWidget {
  const _RewardJourneyMap({
    required this.animationValue,
    required this.requirementProgress,
    required this.onMilestoneTap,
  });

  final double animationValue;
  final double requirementProgress;
  final ValueChanged<int> onMilestoneTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final compact = width < 330;
        final mapHeight = compact ? 340.0 : 400.0;
        final milestoneY = compact
            ? const [32.0, 106.0, 184.0, 264.0]
            : const [36.0, 122.0, 216.0, 310.0];
        final points = [
          Offset(width * .20, milestoneY[0]),
          Offset(width * .76, milestoneY[1]),
          Offset(width * .27, milestoneY[2]),
          Offset(width * .75, milestoneY[3]),
        ];
        return SizedBox(
          height: mapHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _RewardPathPainter(
                    colors: Theme.of(context).colorScheme,
                    points: points,
                    animationValue: animationValue,
                    requirementProgress: requirementProgress,
                  ),
                ),
              ),
              for (var index = 0; index < points.length; index++)
                Positioned(
                  left: (points[index].dx - 70).clamp(0, width - 140),
                  top: points[index].dy - 28,
                  width: 140,
                  child: _JourneyMilestone(
                    number: index + 1,
                    title: _milestoneMapTitles[index],
                    active: index == 0,
                    animationValue: animationValue,
                    onTap: () => onMilestoneTap(index),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _JourneyMilestone extends StatelessWidget {
  const _JourneyMilestone({
    required this.number,
    required this.title,
    required this.active,
    required this.animationValue,
    required this.onTap,
  });

  final int number;
  final String title;
  final bool active;
  final double animationValue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label:
          '${context.tr(title)}. ${context.tr(active ? 'In progress' : 'Locked')}',
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Column(
            children: [
              Transform.scale(
                scale: .88 + (.12 * animationValue),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: active
                        ? colors.primary
                        : colors.surfaceContainerHighest,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: active
                          ? colors.primary
                          : colors.onSurfaceVariant.withValues(alpha: .5),
                      width: active ? 2 : 1.5,
                    ),
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: colors.primary.withValues(alpha: .2),
                              blurRadius: 14,
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    active ? WicchuIcons.flag : WicchuIcons.lockKey,
                    size: 23,
                    color: active ? colors.onPrimary : colors.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${context.tr('Stage')} $number',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: active ? colors.primary : colors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                context.tr(title),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  height: 1.15,
                  color: active ? colors.onSurface : colors.onSurfaceVariant,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RewardPathPainter extends CustomPainter {
  const _RewardPathPainter({
    required this.colors,
    required this.points,
    required this.animationValue,
    required this.requirementProgress,
  });

  final ColorScheme colors;
  final List<Offset> points;
  final double animationValue;
  final double requirementProgress;

  Path get _path {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var index = 1; index < points.length; index++) {
      final previous = points[index - 1];
      final current = points[index];
      final middleY = (previous.dy + current.dy) / 2;
      path.cubicTo(
        previous.dx,
        middleY,
        current.dx,
        middleY,
        current.dx,
        current.dy,
      );
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _path;
    canvas.drawPath(
      path,
      Paint()
        ..color = colors.onSurface.withValues(alpha: .12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    final metric = path.computeMetrics().first;
    final target = (.02 + requirementProgress * .30).clamp(0, .32);
    final visibleProgress = target * animationValue;
    final distance = metric.length * visibleProgress;
    canvas.drawPath(
      metric.extractPath(0, distance),
      Paint()
        ..color = colors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    final tangent = metric.getTangentForOffset(distance);
    if (tangent == null) return;
    final pulse = animationValue < 1
        ? (1 - (animationValue * 2 - 1).abs()).clamp(0, 1)
        : 0.0;
    canvas.drawCircle(
      tangent.position,
      10 + pulse * 5,
      Paint()..color = colors.primary.withValues(alpha: .12),
    );
    canvas.drawCircle(
      tangent.position,
      6,
      Paint()
        ..color = colors.primary
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _RewardPathPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue ||
      oldDelegate.requirementProgress != requirementProgress ||
      oldDelegate.colors != colors;
}

class _RequirementProgressRow extends StatelessWidget {
  const _RequirementProgressRow({required this.requirement});

  final _RewardRequirement requirement;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final complete =
        requirement.target > 0 && requirement.value >= requirement.target;
    final progress = requirement.target <= 0
        ? 0.0
        : (requirement.value / requirement.target).clamp(0, 1).toDouble();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                complete ? WicchuIcons.checkCircleFill : WicchuIcons.circle,
                size: 18,
                color: complete ? colors.primary : colors.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.tr(requirement.label),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                requirement.target > 0
                    ? '${_number(requirement.value)}/${_number(requirement.target)}'
                    : context.tr('Pending setup'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: requirement.target > 0
                      ? null
                      : colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 5,
              value: progress,
              backgroundColor: colors.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardRequestForm extends StatefulWidget {
  const _RewardRequestForm({
    required this.canRequest,
    required this.onSubmit,
    this.reviewNote,
    this.initialCountryCode,
    this.initialCountryName,
    this.initialContactEmail,
  });

  final bool canRequest;
  final String? reviewNote;
  final String? initialCountryCode;
  final String? initialCountryName;
  final String? initialContactEmail;
  final Future<void> Function({
    required String countryCode,
    String? countryName,
    required String contactEmail,
    String? note,
  })
  onSubmit;

  @override
  State<_RewardRequestForm> createState() => _RewardRequestFormState();
}

class _RewardRequestFormState extends State<_RewardRequestForm> {
  final _formKey = GlobalKey<FormState>();
  final _country = TextEditingController();
  final _email = TextEditingController();
  final _note = TextEditingController();
  String _countryCode = 'ES';
  bool _saving = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    final countryCode = widget.initialCountryCode;
    if (countryCode == 'ES' || countryCode == 'EC' || countryCode == 'OT') {
      _countryCode = countryCode!;
    } else if (countryCode?.isNotEmpty == true) {
      _countryCode = 'OT';
    }
    _country.text =
        widget.initialCountryName ??
        (_countryCode == 'OT' ? countryCode ?? '' : '');
    _email.text = widget.initialContactEmail ?? '';
  }

  @override
  void dispose() {
    _country.dispose();
    _email.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text(
        context.tr('Request Community Rewards'),
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      Text(
        context.tr(
          'Tell Wicchu where you are based. We will review availability and contact you.',
        ),
      ),
      if (widget.reviewNote?.isNotEmpty ?? false) ...[
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              WicchuIcons.warningCircle,
              size: 20,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('Why it was not approved'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(widget.reviewNote!),
                ],
              ),
            ),
          ],
        ),
      ],
      const SizedBox(height: 14),
      Form(
        key: _formKey,
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue: _countryCode,
              decoration: InputDecoration(
                labelText: context.tr('Country'),
                isDense: true,
              ),
              items: [
                DropdownMenuItem(value: 'ES', child: Text(context.tr('Spain'))),
                DropdownMenuItem(
                  value: 'EC',
                  child: Text(context.tr('Ecuador')),
                ),
                DropdownMenuItem(
                  value: 'OT',
                  child: Text(context.tr('Another country')),
                ),
              ],
              onChanged: widget.canRequest && !_saving
                  ? (value) => setState(() => _countryCode = value ?? 'ES')
                  : null,
            ),
            if (_countryCode == 'OT') ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _country,
                decoration: InputDecoration(
                  labelText: context.tr('Country name'),
                  isDense: true,
                ),
                validator: (value) => value?.trim().isEmpty ?? true
                    ? context.tr('Required')
                    : null,
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: context.tr('Contact email'),
                isDense: true,
              ),
              validator: (value) {
                final email = value?.trim() ?? '';
                return email.contains('@')
                    ? null
                    : context.tr('Enter a valid email');
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _note,
              maxLength: 500,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: context.tr('Message (optional)'),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
      if (!widget.canRequest)
        Text(context.tr('Only the community owner can send this request.')),
      if (_error != null)
        Text(
          context.trError(_error!),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      const SizedBox(height: 12),
      if (widget.canRequest)
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: Text(
            context.tr(
              _saving
                  ? 'Sending…'
                  : widget.reviewNote?.isNotEmpty == true
                  ? 'Resubmit request'
                  : 'Send request',
            ),
          ),
        ),
    ],
  );

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSubmit(
        countryCode: _countryCode,
        countryName: _countryCode == 'OT' ? _country.text.trim() : null,
        contactEmail: _email.text.trim(),
        note: _note.text.trim(),
      );
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _RewardRequestPending extends StatelessWidget {
  const _RewardRequestPending({required this.enrollment});
  final CommunityRewardEnrollment enrollment;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            WicchuIcons.clock,
            size: 42,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            context.tr('Request under review'),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            enrollment.contactEmail?.isNotEmpty == true
                ? context.tr(
                    'Wicchu will contact you at {email} after reviewing availability in your country.',
                    {'email': enrollment.contactEmail!},
                  )
                : context.tr(
                    'Wicchu will contact the community owner after reviewing availability.',
                  ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class _RewardEnrollment extends StatefulWidget {
  const _RewardEnrollment({
    required this.canAccept,
    required this.countryCode,
    required this.onAccept,
  });

  final bool canAccept;
  final String countryCode;
  final Future<void> Function(String countryCode) onAccept;

  @override
  State<_RewardEnrollment> createState() => _RewardEnrollmentState();
}

class _RewardEnrollmentState extends State<_RewardEnrollment> {
  bool _accepted = false;
  bool _saving = false;
  Object? _error;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text(
        context.tr('Join the Community Rewards pilot'),
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      Text(
        context.tr(
          'Your request was approved. Review and accept the terms to join.',
        ),
      ),
      const SizedBox(height: 18),
      Text(
        context.tr('Before you join'),
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      for (final item in [
        'Rewards are reviewed and are not guaranteed.',
        'Spam, duplicate accounts and artificial activity do not count.',
        'Approved rewards are paid after the monthly review.',
        'Rewards may be taxable income in your country.',
        'Wicchu may change future reward amounts with advance notice.',
        'You can appeal a rejected monthly reward.',
      ])
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 3),
                child: Icon(WicchuIcons.check, size: 17),
              ),
              const SizedBox(width: 9),
              Expanded(child: Text(context.tr(item))),
            ],
          ),
        ),
      const SizedBox(height: 8),
      if (widget.canAccept)
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          visualDensity: VisualDensity.compact,
          value: _accepted,
          onChanged: _saving
              ? null
              : (value) => setState(() => _accepted = value ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(
            context.tr(
              'I understand and accept the Community Rewards pilot terms.',
            ),
          ),
        )
      else
        Text(
          context.tr('Only the community owner can accept these terms.'),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      if (_error != null) ...[
        const SizedBox(height: 8),
        Text(
          context.trError(_error!),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ],
      const SizedBox(height: 12),
      if (widget.canAccept)
        FilledButton(
          onPressed: !_accepted || _saving ? null : _submit,
          child: Text(
            context.tr(_saving ? 'Saving…' : 'Accept and join pilot'),
          ),
        ),
    ],
  );

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onAccept(widget.countryCode);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _RewardDetails extends StatelessWidget {
  const _RewardDetails({required this.insights, required this.onRefresh});

  final CommunityInsights insights;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final reward = insights.monetization;
    final tier = reward.nextTier ?? reward.currentTier;
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
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('Current evaluation period'),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.tr('{days} days remaining', {
                      'days': '${reward.daysRemaining}',
                    }),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    reward.currentTier == null
                        ? context.tr(
                            'No reward unlocked for this evaluation period yet',
                          )
                        : context.tr('Estimated reward: {amount} per month', {
                            'amount': _money(
                              reward.currentTier!.monthlyRewardCents,
                              reward.currency,
                            ),
                          }),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(WicchuIcons.currencyDollar),
              title: Text(context.tr('Approved balance')),
              subtitle: Text(
                reward.availableBalanceCents >= reward.minimumPayoutCents
                    ? context.tr('Ready for manual payment')
                    : context.tr('{amount} remaining until payout', {
                        'amount': _money(
                          reward.minimumPayoutCents -
                              reward.availableBalanceCents,
                          reward.currency,
                        ),
                      }),
              ),
              trailing: Text(
                _money(reward.availableBalanceCents, reward.currency),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          if (tier != null) ...[
            _heading(context, 'Progress toward {level}', {
              'level': _tierName(context, tier.id),
            }),
            _Metric(
              label: 'Members',
              explanation:
                  'Active accounts that currently belong to this community.',
              value: insights.totalMembers,
              target: tier.memberTarget,
            ),
            _Metric(
              label: 'Monthly active members',
              explanation:
                  'Unique members who visited or participated during the previous 30 days.',
              value: insights.monthlyActiveUsers,
              target: tier.monthlyActiveTarget,
            ),
            _Metric(
              label: 'Useful posts in 30 days',
              explanation:
                  'Published community posts; removed or rejected content is excluded.',
              value: insights.posts30d,
              target: tier.postsTarget,
            ),
            _Metric(
              label: 'Meaningful interactions in 30 days',
              explanation:
                  'Published comments and reactions from community activity.',
              value: insights.interactions30d,
              target: tier.interactionsTarget,
            ),
            _Metric(
              label: 'Unique contributors in 30 days',
              explanation:
                  'Different non-admin members who published, commented or voted in a poll.',
              value: insights.uniqueContributors30d,
              target: tier.contributorsTarget,
            ),
            if (tier.retentionTargetPercent > 0)
              insights.retentionDataAvailable
                  ? _Metric(
                      label: 'Monthly member retention',
                      explanation:
                          'Members present before the UTC calendar month who were active during that month.',
                      value: insights.monthlyRetentionRate,
                      target: tier.retentionTargetPercent,
                      suffix: '%',
                    )
                  : Card(
                      child: ListTile(
                        title: Text(context.tr('Monthly member retention')),
                        subtitle: Text(context.tr('Not enough retention data')),
                      ),
                    ),
          ],
          _heading(context, 'Eligibility and payment'),
          _StatusRow(
            icon: reward.goodStanding
                ? WicchuIcons.shieldCheck
                : WicchuIcons.shieldWarning,
            label: 'Community status',
            value: reward.goodStanding ? 'Good standing' : 'Restricted',
            success: reward.goodStanding,
          ),
          const SizedBox(height: 10),
          _StatusRow(
            icon: WicchuIcons.currencyDollar,
            label: 'Payment setup',
            value: reward.payoutSetupComplete ? 'Complete' : 'Required',
            success: reward.payoutSetupComplete,
          ),
          const SizedBox(height: 8),
          Text(
            context.tr(
              'Results are reviewed after the month ends. Spam, duplicate accounts and artificial engagement are excluded.',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          _heading(context, 'Previous monthly results'),
          if (reward.history.isEmpty)
            Text(context.tr('No completed evaluation periods yet.'))
          else
            for (final item in reward.history) _HistoryTile(item: item),
        ],
      ),
    );
  }

  static Widget _heading(
    BuildContext context,
    String label, [
    Map<String, String> values = const {},
  ]) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 10),
    child: Text(
      context.tr(label, values),
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.explanation,
    required this.value,
    required this.target,
    this.suffix = '',
  });

  final String label;
  final String explanation;
  final num value;
  final num target;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final progress = target <= 0 ? 1.0 : (value / target).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: .10),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr(label),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text('${_number(value)}$suffix / ${_number(target)}$suffix'),
              ],
            ),
            const SizedBox(height: 7),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 7),
            Text(
              context.tr(explanation),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.success,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool success;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: success ? Colors.green : Colors.orange),
      const SizedBox(width: 10),
      Expanded(child: Text(context.tr(label))),
      Text(
        context.tr(value),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ],
  );
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.item});
  final CommunityRewardEvaluation item;

  @override
  Widget build(BuildContext context) {
    final dates = MaterialLocalizations.of(context);
    final title = dates.formatMonthYear(item.periodStart.toLocal());
    final status = switch (item.status) {
      'pending_review' => 'Pending review',
      'approved' => 'Approved',
      'rejected' => 'Rejected',
      'paid' => 'Paid',
      _ => 'Not qualified',
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: .10),
          ),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr(status)),
            if (item.paidAt != null)
              Text(
                '${context.tr('Paid on')} ${dates.formatMediumDate(item.paidAt!.toLocal())}',
              ),
            if (item.reviewNote?.isNotEmpty ?? false) Text(item.reviewNote!),
          ],
        ),
        trailing: Text(
          item.rewardCents > 0 ? _money(item.rewardCents, item.currency) : '—',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

String _tierName(BuildContext context, String id) => context.tr(switch (id) {
  'active' => 'Active',
  'growing' => 'Growing',
  'high_impact' => 'High Impact',
  _ => id,
});

String _money(int cents, String currency) {
  final euros = cents / 100;
  final amount = euros == euros.roundToDouble()
      ? euros.toInt().toString()
      : euros.toStringAsFixed(2);
  return currency == 'USD' ? '\$$amount' : '$amount €';
}

String _number(num value) => value is double && value % 1 != 0
    ? value.toStringAsFixed(1)
    : value.toInt().toString();
