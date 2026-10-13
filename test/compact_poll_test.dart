import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/community/post_card.dart';

const options = [
  PollOption(id: 'a', text: 'Candidate 1', voteCount: 0),
  PollOption(id: 'b', text: 'Candidate 2', voteCount: 0),
];

Future<void> showPoll(
  WidgetTester tester, {
  PostPoll poll = const PostPoll(options: options),
  Future<PostPoll> Function(String)? vote,
  double scale = 1,
}) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: PostCard(
            category: 'News',
            icon: '',
            community: 'Community',
            author: 'Author',
            time: 'Now',
            text: 'Who will win?',
            poll: poll,
            onPollVote: vote,
            showActions: false,
            showMenu: false,
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('selection does not vote; submit waits then displays results', (
    tester,
  ) async {
    final result = Completer<PostPoll>();
    final calls = <String>[];
    await showPoll(
      tester,
      vote: (id) {
        calls.add(id);
        return result.future;
      },
    );
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('0%'), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.tap(find.text('Candidate 1'));
    await tester.pump();
    expect(calls, isEmpty);
    await tester.tap(find.text('Vote'));
    await tester.pump();
    expect(calls, ['a']);
    expect(find.text('Voting…'), findsOneWidget);
    result.complete(
      const PostPoll(
        selectedOptionId: 'a',
        options: [
          PollOption(id: 'a', text: 'Candidate 1', voteCount: 1),
          PollOption(id: 'b', text: 'Candidate 2', voteCount: 0),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('1 vote'), findsOneWidget);
    expect(find.text('1 votes'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNWidgets(2));
    expect(find.text('Vote'), findsNothing);
  });

  testWidgets('results opt-in does not vote; zero votes have no bars', (
    tester,
  ) async {
    await showPoll(tester);
    await tester.tap(find.text('View results'));
    await tester.pump();
    expect(find.text('0%'), findsNWidgets(2));
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.tap(find.text('Back'));
    await tester.pump();
    expect(find.text('0%'), findsNothing);
  });

  testWidgets('failed vote retains selection for retry', (tester) async {
    await showPoll(tester, vote: (_) async => throw Exception('Try again'));
    await tester.tap(find.text('Candidate 2'));
    await tester.pump();
    await tester.tap(find.text('Vote'));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('0%'), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('existing vote shows results at large text scale', (
    tester,
  ) async {
    await showPoll(
      tester,
      poll: const PostPoll(options: options, selectedOptionId: 'a'),
      scale: 2,
    );
    expect(find.text('0%'), findsNWidgets(2));
    expect(find.text('Vote'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
