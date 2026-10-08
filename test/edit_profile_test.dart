import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/profile/edit_profile_links.dart';

class FailingProfileRepository extends DemoCommunityRepository {
  int saves = 0;

  @override
  Future<EditableMemberProfile> updateEditableProfile(
    EditableMemberProfile profile,
  ) async {
    saves++;
    throw Exception('Save failed');
  }
}

void main() {
  testWidgets(
    'back protects edits and explicit discard leaves without saving',
    (tester) async {
      final repository = DemoCommunityRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => editProfileLinks(context, repository),
                child: const Text('Open editor'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('profile-detail-0')),
        'Unsaved name',
      );
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
      await tester.pumpAndSettle();
      expect(find.text('Unsaved changes'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('Unsaved name'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Unsaved changes'), findsOneWidget);
      await tester.tap(find.text('Leave without saving'));
      await tester.pumpAndSettle();
      expect(find.byType(EditProfilePage), findsNothing);
      expect((await repository.getEditableProfile()).name, 'Michael P.');
      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(EditProfilePage), findsNothing);
    },
  );

  testWidgets('profile details load, validate and persist', (tester) async {
    final repository = DemoCommunityRepository();
    await tester.pumpWidget(
      MaterialApp(home: EditProfilePage(repository: repository)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Michael P.'), findsOneWidget);
    final name = find.byKey(const ValueKey('profile-detail-0'));
    await tester.enterText(name, '');
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text('This field is required.'), findsOneWidget);
    await tester.enterText(name, 'Updated name');
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect((await repository.getEditableProfile()).name, 'Updated name');
  });

  testWidgets('invalid contact prevents save and failed save retains input', (
    tester,
  ) async {
    final repository = FailingProfileRepository();
    await tester.pumpWidget(
      MaterialApp(home: EditProfilePage(repository: repository)),
    );
    await tester.pumpAndSettle();
    final whatsapp = find.byKey(const ValueKey('profile-link-0'));
    await tester.ensureVisible(whatsapp);
    await tester.enterText(whatsapp, 'invalid');
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(repository.saves, 0);
    await tester.enterText(whatsapp, '+34600123456');
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(repository.saves, 1);
    expect(find.text('+34600123456'), findsOneWidget);
    expect(find.byType(EditProfilePage), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('unavailable username is rejected before save', (tester) async {
    final repository = DemoCommunityRepository();
    await tester.pumpWidget(
      MaterialApp(home: EditProfilePage(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('profile-detail-1')),
      'taken',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('This username is already taken.'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });

  testWidgets('profile accent color can be selected and saved', (tester) async {
    final repository = DemoCommunityRepository();
    await tester.pumpWidget(
      MaterialApp(home: EditProfilePage(repository: repository)),
    );
    await tester.pumpAndSettle();

    final purple = find.byKey(const ValueKey('profile-accent-purple'));
    await tester.ensureVisible(purple);
    await tester.tap(purple);
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect((await repository.getEditableProfile()).accentColor, 'purple');
  });
}
