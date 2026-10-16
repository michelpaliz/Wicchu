import 'package:flutter/material.dart';

import '../../domain/community_models.dart';
import '../../domain/community_repository.dart';
import '../../localization/app_language.dart';
import '../../theme/wicchu_icons.dart';

class FinancialSupportPage extends StatefulWidget {
  const FinancialSupportPage({
    super.key,
    required this.page,
    required this.repository,
  });

  final Community page;
  final CommunityRepository repository;

  @override
  State<FinancialSupportPage> createState() => _FinancialSupportPageState();
}

class _FinancialSupportPageState extends State<FinancialSupportPage> {
  late Future<FinancialSupportApplication?> _application = _load();
  final _formKey = GlobalKey<FormState>();
  final _countryName = TextEditingController();
  final _purpose = TextEditingController();
  final _email = TextEditingController();
  String _countryCode = 'ES';
  String _recipientType = 'individual';
  bool _saving = false;

  Future<FinancialSupportApplication?> _load() =>
      widget.repository.getFinancialSupportApplication(widget.page.id);

  @override
  void dispose() {
    _countryName.dispose();
    _purpose.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('Financial support'))),
    body: FutureBuilder<FinancialSupportApplication?>(
      future: _application,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: FilledButton.icon(
              onPressed: () => setState(() => _application = _load()),
              icon: const Icon(WicchuIcons.arrowsClockwise),
              label: Text(context.trError(snapshot.error!)),
            ),
          );
        }
        final application = snapshot.data;
        if (application != null && application.status != 'rejected') {
          return _StatusView(application: application);
        }
        return _applicationForm(application);
      },
    ),
  );

  Widget _applicationForm(FinancialSupportApplication? previous) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text(
        context.tr('Apply for financial support'),
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      Text(
        context.tr(
          'Tell Wicchu who will receive support and how the money would be used. Approval does not enable payments yet.',
        ),
      ),
      if (previous?.reviewNote.isNotEmpty ?? false) ...[
        const SizedBox(height: 16),
        Card(
          color: Theme.of(context).colorScheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('${context.tr('Reason')}: ${previous!.reviewNote}'),
          ),
        ),
      ],
      const SizedBox(height: 20),
      Form(
        key: _formKey,
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue: _countryCode,
              decoration: InputDecoration(labelText: context.tr('Country')),
              items: [
                DropdownMenuItem(value: 'ES', child: Text(context.tr('Spain'))),
                DropdownMenuItem(
                  value: 'EC',
                  child: Text(context.tr('Ecuador')),
                ),
                DropdownMenuItem(
                  value: 'OT',
                  child: Text(context.tr('Other country')),
                ),
              ],
              onChanged: (value) =>
                  setState(() => _countryCode = value ?? 'ES'),
            ),
            if (_countryCode == 'OT') ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _countryName,
                decoration: InputDecoration(
                  labelText: context.tr('Country name'),
                ),
                validator: (value) => value?.trim().isEmpty ?? true
                    ? context.tr('Enter your country')
                    : null,
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _recipientType,
              decoration: InputDecoration(
                labelText: context.tr('Recipient type'),
              ),
              items: [
                DropdownMenuItem(
                  value: 'individual',
                  child: Text(context.tr('Individual')),
                ),
                DropdownMenuItem(
                  value: 'organization',
                  child: Text(context.tr('Organization')),
                ),
                DropdownMenuItem(
                  value: 'business',
                  child: Text(context.tr('Business')),
                ),
                DropdownMenuItem(
                  value: 'community_project',
                  child: Text(context.tr('Community project')),
                ),
              ],
              onChanged: (value) =>
                  setState(() => _recipientType = value ?? 'individual'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: context.tr('Contact email'),
              ),
              validator: (value) =>
                  RegExp(
                    r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                  ).hasMatch(value?.trim() ?? '')
                  ? null
                  : context.tr('Enter a valid contact email'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _purpose,
              minLines: 4,
              maxLines: 7,
              maxLength: 1000,
              decoration: InputDecoration(
                labelText: context.tr('How will financial support be used?'),
              ),
              validator: (value) => (value?.trim().length ?? 0) < 20
                  ? context.tr('Please provide at least 20 characters.')
                  : null,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _submit,
                child: Text(
                  context.tr(
                    previous == null
                        ? 'Submit application'
                        : 'Resubmit application',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final application = await widget.repository
          .submitFinancialSupportApplication(
            widget.page.id,
            countryCode: _countryCode,
            countryName: _countryCode == 'OT' ? _countryName.text : null,
            recipientType: _recipientType,
            purpose: _purpose.text,
            contactEmail: _email.text,
          );
      if (mounted) setState(() => _application = Future.value(application));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.trError(error))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _StatusView extends StatelessWidget {
  const _StatusView({required this.application});

  final FinancialSupportApplication application;

  @override
  Widget build(BuildContext context) {
    final approved = application.status == 'approved';
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Icon(approved ? WicchuIcons.checkCircle : WicchuIcons.clock, size: 64),
        const SizedBox(height: 16),
        Text(
          context.tr(
            approved ? 'Application approved' : 'Application under review',
          ),
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Text(
          context.tr(
            approved
                ? 'Wicchu approved the application. Payments remain unavailable until recipient verification and a payment provider are configured.'
                : 'Wicchu Safety will review the page, recipient and intended use of funds.',
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Card(
          child: ListTile(
            title: Text(context.tr('Payments')),
            subtitle: Text(context.tr('Not enabled yet')),
            trailing: const Icon(WicchuIcons.lockKey),
          ),
        ),
      ],
    );
  }
}
