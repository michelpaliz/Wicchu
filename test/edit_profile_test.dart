import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/profile/edit_profile_links.dart';

class FailingProfileRepository extends DemoCommunityRepository {
  int saves = 0;
  @override
  Future<SocialLinks> updateMySocialLinks(SocialLinks links) async {
    saves++;
    throw Exception('Save failed');
  }
}

void main() {
  testWidgets('invalid email prevents save and failed save retains input', (
    tester,
  ) async {
    final repository = FailingProfileRepository();
    await tester.pumpWidget(
      MaterialApp(home: EditProfilePage(repository: repository)),
    );
    await tester.pumpAndSettle();
    final email = find.byType(TextFormField).at(3);
    await tester.ensureVisible(email);
    await tester.enterText(email, 'invalid');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(repository.saves, 0);
    await tester.enterText(email, 'neighbor@example.com');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(repository.saves, 1);
    expect(find.text('neighbor@example.com'), findsOneWidget);
    expect(find.byType(EditProfilePage), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
  });
}
