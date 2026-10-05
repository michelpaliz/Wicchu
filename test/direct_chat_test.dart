import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wicchu/data/demo_community_repository.dart';
import 'package:wicchu/domain/community_models.dart';
import 'package:wicchu/features/chat/direct_chat_pages.dart';

class _ChatRepository extends DemoCommunityRepository {
  String? sentBody;
  String? reportedMessageId;
  String? reportedCategory;
  String? deletedMessageId;
  bool? deletedForEveryone;

  @override
  Future<DirectMessagePage> listDirectMessages(
    String conversationId, {
    String? before,
  }) async => before == null
      ? DirectMessagePage(
          nextCursor: 'older-cursor',
          messages: [
            DirectMessage(
              id: 'message-incoming',
              conversationId: conversationId,
              senderId: 'user-2',
              recipientId: 'current-user',
              body: 'Hello from Ana',
              createdAt: DateTime.utc(2026, 10, 5, 10),
            ),
          ],
        )
      : DirectMessagePage(
          messages: [
            DirectMessage(
              id: 'message-older',
              conversationId: conversationId,
              senderId: 'user-2',
              recipientId: 'current-user',
              body: 'Older hello',
              createdAt: DateTime.utc(2026, 10, 4, 10),
            ),
          ],
        );

  @override
  Future<DirectMessage> sendDirectMessage(
    String conversationId,
    String body,
  ) async {
    sentBody = body;
    return DirectMessage(
      id: 'message-sent',
      conversationId: conversationId,
      senderId: 'current-user',
      recipientId: 'user-2',
      body: body,
      createdAt: DateTime.utc(2026, 10, 5, 10, 1),
    );
  }

  @override
  Future<void> reportDirectMessage(
    String messageId,
    String reason, {
    required String category,
  }) async {
    reportedMessageId = messageId;
    reportedCategory = category;
  }

  @override
  Future<void> deleteDirectMessage(
    String messageId, {
    required bool everyone,
  }) async {
    deletedMessageId = messageId;
    deletedForEveryone = everyone;
  }
}

void main() {
  testWidgets('direct chat sends and reports a received message', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _ChatRepository();
    const conversation = DirectConversation(
      id: 'conversation-1',
      otherUser: WicchuUser(id: 'user-2', name: 'Ana'),
      unreadCount: 1,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: DirectChatPage(
          repository: repository,
          conversation: conversation,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hello from Ana'), findsOneWidget);
    await tester.tap(find.text('Load older messages'));
    await tester.pumpAndSettle();
    expect(find.text('Older hello'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Hi Ana');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(repository.sentBody, 'Hi Ana');
    expect(find.text('Hi Ana'), findsOneWidget);

    await tester.longPress(find.text('Hello from Ana'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Report message'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Harassment'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Submit report'));
    await tester.tap(find.text('Submit report'));
    await tester.pumpAndSettle();

    expect(repository.reportedMessageId, 'message-incoming');
    expect(repository.reportedCategory, 'harassment');
    expect(find.text('Report submitted'), findsOneWidget);

    await tester.longPress(find.text('Hi Ana'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete for everyone'));
    await tester.pumpAndSettle();
    expect(repository.deletedMessageId, 'message-sent');
    expect(repository.deletedForEveryone, isTrue);
    expect(find.text('Message removed'), findsOneWidget);
  });
}
