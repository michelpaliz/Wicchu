import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/domain/community_repository.dart';
import 'package:wicchu/features/admin/admin_dashboard_page.dart';
import 'package:wicchu/features/admin/admin_overview_page.dart';
import 'package:wicchu/features/admin/financial_support_page.dart';
import 'package:wicchu/features/admin/platform_moderation_page.dart';
import 'package:wicchu/theme/wicchu_theme.dart';

class _DelayedSupportRepository extends DemoCommunityRepository {
  final complete = Completer<void>();
  int submissions = 0;
  @override
  Future<FinancialSupportApplication> submitFinancialSupportApplication(
    String pageId, {
    required String countryCode,
    String? countryName,
    required String recipientType,
    required String purpose,
    required String contactEmail,
  }) async {
    submissions++;
    await complete.future;
    return super.submitFinancialSupportApplication(
      pageId,
      countryCode: countryCode,
      countryName: countryName,
      recipientType: recipientType,
      purpose: purpose,
      contactEmail: contactEmail,
    );
  }
}

class _SupportReviewRepository extends DemoCommunityRepository {
  int reviews = 0;
  String? lastNote;
  @override
  Future<List<FinancialSupportApplication>>
  listFinancialSupportApplications() async => [
    FinancialSupportApplication(
      id: 'application',
      pageId: 'page',
      pageName: 'Community education and local activities',
      countryCode: 'ES',
      recipientType: 'community_project',
      purpose: 'Provide free activities for local families.',
      contactEmail: 'community@example.com',
      status: 'pending',
      requestedAt: DateTime(2026),
    ),
  ];
  @override
  Future<void> reviewFinancialSupportApplication(
    String id, {
    required bool approve,
    String? note,
  }) async {
    reviews++;
    lastNote = note;
  }
}

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'page owner can apply for support from compact dashboard dark=$dark',
      (tester) async {
        tester.view.physicalSize = const Size(320, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repository = _DelayedSupportRepository();
        final page = await repository.createCommunity(
          const CreateCommunityInput(
            name: 'Support page',
            description: '',
            town: Town(id: 'town-1', name: 'Town X', countryCode: 'ES'),
            visibility: CommunityVisibility.public,
            categoryNames: ['General'],
            type: CommunityType.publicProfile,
            profileCategory: ProfileCategory.creator,
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? WicchuTheme.dark : WicchuTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: AdminDashboardPage(community: page, repository: repository),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Financial support'));
        await tester.tap(find.text('Financial support'));
        await tester.pumpAndSettle();
        expect(find.byType(FinancialSupportPage), findsOneWidget);
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Contact email'),
          'owner@example.com',
        );
        await tester.enterText(
          find.widgetWithText(
            TextFormField,
            'How will financial support be used?',
          ),
          'Support new local community activities and educational events.',
        );
        await tester.ensureVisible(find.text('Submit application'));
        final submit = tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Submit application'),
            )
            .onPressed!;
        submit();
        submit();
        await tester.pump();
        expect(repository.submissions, 1);
        repository.complete.complete();
        await tester.pumpAndSettle();
        expect(
          (await repository.getFinancialSupportApplication(page.id))?.status,
          'pending',
        );
        expect(find.text('Submit application'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'restricted page admin keeps categories but cannot open analytics or support',
    (tester) async {
      final repository = DemoCommunityRepository();
      final page = Community(
        id: 'page',
        name: 'Page',
        description: '',
        town: const Town(id: 'town-1', name: 'Town', countryCode: 'ES'),
        visibility: CommunityVisibility.public,
        createdBy: 'owner',
        createdAt: DateTime(2026),
        type: CommunityType.publicProfile,
        profileCategory: ProfileCategory.creator,
        myRole: CommunityRole.admin,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: AdminDashboardPage(community: page, repository: repository),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Financial support'), findsNothing);
      expect(find.text('Categories'), findsOneWidget);
      await tester.tap(find.text('Statistics and activity'));
      await tester.pumpAndSettle();
      expect(find.byType(AdminOverviewPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final dark in [false, true]) {
    testWidgets(
      'support review requires a rejection reason on narrow screens dark=$dark',
      (tester) async {
        tester.view.physicalSize = const Size(320, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repository = _SupportReviewRepository();
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? WicchuTheme.dark : WicchuTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: PlatformModerationPage(repository: repository, initialTab: 5),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Reject'));
        await tester.tap(find.text('Reject'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.widgetWithText(FilledButton, 'Reject application'),
        );
        await tester.tap(
          find.widgetWithText(FilledButton, 'Reject application'),
        );
        await tester.pumpAndSettle();
        expect(repository.reviews, 0);
        expect(
          find.text('Explain why the application was rejected.'),
          findsNWidgets(2),
        );
        await tester.enterText(
          find.byType(TextFormField),
          'Please clarify the intended beneficiaries.',
        );
        await tester.ensureVisible(
          find.widgetWithText(FilledButton, 'Reject application'),
        );
        await tester.tap(
          find.widgetWithText(FilledButton, 'Reject application'),
        );
        await tester.pumpAndSettle();
        expect(repository.reviews, 1);
        expect(
          repository.lastNote,
          'Please clarify the intended beneficiaries.',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('platform support queue opens as sixth tab', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PlatformModerationPage(
          repository: DemoCommunityRepository(),
          initialTab: 5,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Financial support'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
